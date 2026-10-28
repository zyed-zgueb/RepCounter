#!/usr/bin/env python3
"""Verdict de progression : miroir Python de RepCounter/Progress.swift, et sa validation.

Usage : python3 Simulation/progress.py      (code de sortie 1 si un critère échoue)

Méthode :
- Pente de Theil-Sen (Sen 1968, J Am Stat Assoc 63:1379–1389) : la médiane des pentes entre
  toutes les paires de séances, robuste aux séances aberrantes ; intervalle de confiance à 95 %
  sans hypothèse de loi (équation 2.6 de Sen, comme scipy.stats.theilslopes), ici à 99 % :
  Var(S) = n(n−1)(2n+5)/18 (moins la correction des ex-æquo), C = 2,576·√Var(S),
  bornes = pentes de rangs (N−C)/2 et (N+C)/2 + 1 parmi les N pentes triées.
- Plus petit changement significatif (Hopkins 2004, Sportscience 8:1–7 ; Hopkins, Hawley et
  Burke 1999) : 0,3 fois la variation habituelle d'une séance à l'autre, estimée par l'erreur
  typique (Hopkins 2000, Sports Med 30(1):1–15) : écart-type des différences entre séances
  consécutives ÷ √2.
- Verdict, sur les 8 dernières semaines (au moins 8 séances notées) :
  En progrès : intervalle de la pente entièrement au-dessus de zéro, et gain sur la période
  au moins égal au plus petit changement significatif ; En recul : l'inverse ; sinon Stable.
"""

import math
import random
import sys

# Intervalle à 99 % : sur des historiques plats, « En progrès » à tort dans 0,2 % des cas
# (2 % avec 95 %), et une séance aberrante ne fait presque jamais un recul.
Z = 2.5758293035489
MIN_POINTS = 8
WINDOW_DAYS = 56


def ties_term(values):
    counts = {}
    for v in values:
        counts[v] = counts.get(v, 0) + 1
    return sum(t * (t - 1) * (2 * t + 5) for t in counts.values() if t > 1)


def theil_sen(xs, ys):
    """(pente, borne basse, borne haute) à 99 %, ou None."""
    n = len(xs)
    slopes = sorted((ys[j] - ys[i]) / (xs[j] - xs[i])
                    for i in range(n) for j in range(i + 1, n) if xs[j] != xs[i])
    N = len(slopes)
    if N == 0:
        return None
    m = N // 2
    slope = slopes[m] if N % 2 else (slopes[m - 1] + slopes[m]) / 2
    var = (n * (n - 1) * (2 * n + 5) - ties_term(xs) - ties_term(ys)) / 18
    c = Z * math.sqrt(max(var, 0))
    lo_rank = int(round((N - c) / 2))          # rang 1 = première pente
    hi_rank = int(round((N + c) / 2)) + 1
    lo = slopes[min(max(lo_rank, 1), N) - 1]
    hi = slopes[min(max(hi_rank, 1), N) - 1]
    return slope, lo, hi


def typical_error(ys):
    diffs = [b - a for a, b in zip(ys, ys[1:])]
    if len(diffs) < 2:
        return None
    mean = sum(diffs) / len(diffs)
    sd = math.sqrt(sum((d - mean) ** 2 for d in diffs) / (len(diffs) - 1))
    return sd / math.sqrt(2)


def verdict(points):
    """points = [(jour, score)], les plus anciens d'abord, sur la fenêtre. 'pending', 'up',
    'stable' ou 'down'."""
    if len(points) < MIN_POINTS:
        return "pending"
    xs = [p[0] for p in points]
    ys = [p[1] for p in points]
    fit = theil_sen(xs, ys)
    te = typical_error(ys)
    if fit is None or te is None:
        return "pending"
    slope, lo, hi = fit
    gain = slope * (xs[-1] - xs[0])
    swc = 0.3 * te
    if lo > 0 and gain >= swc:
        return "up"
    if hi < 0 and -gain >= swc:
        return "down"
    return "stable"


# --- Validation ------------------------------------------------------------------------------

def series(rng, weekly_gain, noise, base=40.0, weeks=8, per_week=3):
    """Score d'endurance de séances lundi, mercredi, vendredi."""
    out = []
    for w in range(weeks):
        for d in (0, 2, 4)[:per_week]:
            day = w * 7 + d
            out.append((day, base * (1 + weekly_gain * day / 7) * (1 + rng.gauss(0, noise))))
    return out


def rate(kind, weekly_gain, noise, runs=2000, seed=1):
    rng = random.Random(seed)
    hits = sum(verdict(series(rng, weekly_gain, noise)) == kind for _ in range(runs))
    return hits / runs


def main():
    ok = True
    print("Faux « En progrès » sur des historiques plats (2000 tirages chacun) :")
    for noise in (0.03, 0.05, 0.08, 0.12):
        r = rate("up", 0.0, noise)
        print(f"  bruit {noise * 100:.0f} % : {r * 100:.1f} %")
        ok &= r <= 0.005
    print("Progrès réels détectés (« En progrès ») :")
    for gain in (0.01, 0.02, 0.04):
        for noise in (0.03, 0.08):
            r = rate("up", gain, noise)
            print(f"  +{gain * 100:.0f} %/semaine, bruit {noise * 100:.0f} % : {r * 100:.0f} %")
    r = rate("up", 0.02, 0.03)
    ok &= r >= 0.9
    r = rate("down", 0.0, 0.05)
    print(f"Faux « En recul » sur plat (bruit 5 %) : {r * 100:.1f} %")
    ok &= r <= 0.005
    # Une séance aberrante (moitié du score : série arrêtée tôt) fait rarement un recul
    rng = random.Random(7)
    downs = 0
    for _ in range(2000):
        s = series(rng, 0.0, 0.03)
        s[-1] = (s[-1][0], s[-1][1] * 0.5)
        downs += verdict(s) == "down"
    print(f"Plat, dernière séance aberrante : « En recul » {downs / 20:.1f} %")
    ok &= downs / 2000 <= 0.03
    print("\nOK" if ok else "\nÉCHEC")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())

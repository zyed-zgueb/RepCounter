#!/usr/bin/env python3
"""Vitesse de montée de chaque répétition, tirée de l'accélération verticale (iPhone en poche) :
prototype pour la priorité 2 (répétitions en réserve), à valider contre une mesure de référence
(capteur de déplacement linéaire, ou vidéo à haute fréquence) avant tout affichage.

Usage : python3 Simulation/velocity.py Recordings/pullups_2026-10-28_15-29-24.jsonl

Méthode :
- accélération vers le haut = (accélération du téléphone, sans la gravité) · (direction de la
  gravité) × 9,81 (signe vérifié sur les tractions : positive à la montée depuis la suspension) ;
- intégrée entre deux sommets consécutifs (les instants de comptage, au sommet du geste), où la
  vitesse est nulle ; la dérive est retirée linéairement pour que la vitesse soit nulle aux deux
  bouts : adaptation de la mise à zéro de la vitesse aux instants immobiles (« zero velocity
  update », Foxlin 2005 ; Wahlström et Skog 2020) ;
- vitesse moyenne de montée : moyenne de la vitesse sur la partie montante ; perte de vitesse
  de la série : (meilleure − dernière) ÷ meilleure (Sánchez-Medina et González-Badillo 2011).
Limites : la vitesse moyenne de montée n'est pas la vitesse moyenne propulsive des études ; la
précision d'un iPhone en poche n'est pas publiée.

Résultat du 29/10 (contrôle de vraisemblance : la hauteur montée, intégrale de la vitesse) :
tractions 14 à 20 cm au lieu d'environ 50 ; squats 7 à 16 cm au lieu d'environ 20 à 25 pour une
poche à mi-cuisse. La mesure sous-estime le déplacement d'un facteur 2 à 3 : la cuisse bascule
pendant le geste, et l'accélération sans la gravité que calcule l'iPhone en rotation n'est pas
assez juste à 30 Hz. En l'état, cette vitesse n'est PAS utilisable : ni affichage, ni
répétitions en réserve. Pistes : iPhone au brassard ou à la ceinture (moins de rotation),
validation contre une vidéo à 240 images/s.

Pompes : la profondeur TrueDepth donne la distance du visage, sans intégration. Sur
pushups_2026-10-26_14-14-11 (10 pompes) : 0,86 à 0,96 m/s, puis 0,73 à la dernière (perte 24 %),
cohérent. Le bas de la pompe (moins de ~18 cm) n'est pas mesurable : la vitesse porte sur la
partie haute de la montée. À valider sur des séries à l'échec avant toute estimation.
"""

import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import replay as rp  # noqa: E402

G = 9.81


def rep_velocities(times, up, tops):
    """Pour chaque intervalle entre deux sommets : (vitesse moyenne de montée, vitesse de pointe,
    hauteur montée, durée de la montée)."""
    out = []
    for a, b in zip(tops, tops[1:]):
        m = (times >= a) & (times <= b)
        if m.sum() < 5:
            out.append(None)
            continue
        t, acc = times[m], up[m]
        dt = np.diff(t, prepend=t[0])
        v = np.cumsum(acc * dt)
        v -= v[0] + (v[-1] - v[0]) * (t - t[0]) / (t[-1] - t[0])   # nulle aux deux sommets
        # La montée : la dernière portion où la vitesse est positive, jusqu'au sommet
        k = len(v) - 1
        while k > 0 and v[k] <= 0:
            k -= 1
        j = k
        while j > 0 and v[j - 1] > 0:
            j -= 1
        if k - j < 3:
            out.append(None)
            continue
        seg = slice(j, k + 1)
        height = float(np.sum(v[seg] * dt[seg]))
        out.append((float(v[seg].mean()), float(v[seg].max()), height, float(t[k] - t[j])))
    return out


# Pompes : distance du visage par la caméra TrueDepth (10e centile de la profondeur, moitié
# centrale de l'image), mesurable au-delà d'environ 18 cm. Vitesse moyenne de montée entre 25 et
# 50 cm : la partie visible de la montée, sans intégration.
FACE_LOW, FACE_HIGH = 0.25, 0.50


def pushup_velocities(frames, t0):
    """(instant, vitesse moyenne de 25 à 50 cm) pour chaque montée."""
    rows = [(f["t"] - t0, f["x"]["depthStats"]) for f in frames if "depthStats" in f.get("x", {})]
    out, below, previous = [], None, None
    for t, stats in rows:
        d = stats[0] if stats[3] > 0.5 else None
        if d is None:
            continue
        if d < FACE_LOW:
            below = (t, d)
        elif below is not None and previous is not None and previous[1] < FACE_HIGH <= d:
            # Instants de passage à 25 et 50 cm, interpolés
            t_low = below[0]
            t_high = previous[0] + (t - previous[0]) * (FACE_HIGH - previous[1]) / (d - previous[1])
            if t_high > t_low:
                out.append((t_high, (FACE_HIGH - FACE_LOW) / (t_high - t_low)))
            below = None
        elif below is not None and below[1] < FACE_LOW <= d and previous is not None and previous[1] < FACE_LOW:
            # Passage à 25 cm : instant interpolé
            below = (previous[0] + (t - previous[0]) * (FACE_LOW - previous[1]) / (d - previous[1]), FACE_LOW)
        previous = (t, d)
    return out


def main(path):
    meta, end, frames = rp.load(path)
    exercise = meta.get("exercise", "pullups")
    if exercise == "pushups":
        reps = pushup_velocities(frames, frames[0]["t"])
        print(f"{os.path.basename(path)} : {len(reps)} montées mesurées (caméra TrueDepth, 25 → 50 cm)")
        for i, (t, v) in enumerate(reps, 1):
            print(f"  rép. {i} : {v:.2f} m/s")
        if reps:
            best = max(v for _, v in reps)
            print(f"  perte de vitesse de la série : {100 * (best - reps[-1][1]) / best:.0f} %")
        return
    counter, counts, _ = rp.replay(frames, exercise, meta.get("sources"))
    t0 = frames[0]["t"]
    times = np.array([f["t"] for f in frames]) - t0
    up = np.array([f["v"]["vertical"][0] if "vertical" in f["v"] else 0.0 for f in frames]) * G
    leader = counter.locks[0][1] if counter.locks else None
    cycles = [c - t0 for c in counter.trackers[leader].cycles] if leader else []
    print(f"{os.path.basename(path)} : {counter.count} répétitions, sommets {[round(c, 2) for c in cycles]}")
    # Premier intervalle : depuis la suspension, une période avant le premier sommet
    if len(cycles) >= 2:
        period = float(np.median(np.diff(cycles)))
        tops = [cycles[0] - period] + cycles
        result = rep_velocities(times, up, tops)
        best = max((r[0] for r in result if r), default=None)
        for i, r in enumerate(result, 1):
            if r:
                print(f"  rép. {i} : montée {r[0]:.2f} m/s en moyenne, pointe {r[1]:.2f} m/s, "
                      f"{100 * r[2]:.0f} cm en {r[3]:.2f} s")
        last = next((r[0] for r in reversed(result) if r), None)
        if best and last:
            print(f"  perte de vitesse de la série : {100 * (best - last) / best:.0f} %")


if __name__ == "__main__":
    try:
        main(sys.argv[1])
    except BrokenPipeError:
        pass

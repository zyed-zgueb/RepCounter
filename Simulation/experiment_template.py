#!/usr/bin/env python3
"""Expérience : un gabarit personnel du geste, appris sur des séances passées, peut-il
1. reconnaître les premières répétitions d'une série tout de suite (au lieu d'attendre la 3e) ;
2. écarter les gestes qui n'en sont pas (installation, iPhone repris, repos) ?

Abdos seulement (gyroscope, iPhone sur la poitrine). Vérité terrain : les répétitions des séries,
découpées en deux bosses (aller, retour) sur le gyroscope, dans les séries trouvées par le
compteur actuel (exact sur ces séances). Validation croisée : le gabarit est appris sur une
séance, testé sur les autres (d'autres jours).

Usage : python3 Simulation/experiment_template.py               (validation croisée)
        python3 Simulation/experiment_template.py --irregular   (séries irrégulières)

Résultats du 28/10 (3 séances d'abdos, 255 répétitions étiquetées, une seule personne) :
- seuil 0,8 : 98 % des abdos reconnus un par un d'un jour à l'autre (501/510), 3 fausses
  détections en ~7 min (une pendant l'installation, avant le départ ; deux un peu en avance
  sur un vrai abdo) ; l'iPhone repris n'est jamais pris pour un abdo ;
- 34/36 des deux premières répétitions de chaque série reconnues dès qu'elles finissent ;
- séries irrégulières (vrais abdos séparés par des pauses aléatoires) : le compteur actuel,
  qui attend un rythme régulier, ne compte presque rien (0 sur 14 essais sur 15) ; le
  gabarit compte 15/15 à chaque fois.
"""

import glob
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import replay as rp  # noqa: E402

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "Recordings")
SAMPLES = 32          # points d'un geste rééchantillonné
TOLERANCE = 0.35      # s : une détection à moins de ce délai de la fin d'un vrai geste le reconnaît


def load(path):
    meta, end, frames = rp.load(path)
    t = np.array([f["t"] for f in frames])
    t = t - t[0]
    for f, x in zip(frames, t):
        f["t"] = float(x)
    rotation = np.array([f["v"]["rotation"] for f in frames], dtype=float)
    counter, counts, _ = rp.replay(frames, "crunches", meta.get("sources"))
    return t, rotation, np.array(counts), end.get("actualReps")


def segments(t, rotation):
    """Gestes candidats : une bosse puis l'autre sur l'axe principal du gyroscope (début, fin)."""
    s = np.convolve(rotation[:, 1], np.ones(5) / 5, mode="same")
    out, state, start = [], 0, None
    for x, v in zip(t, s):
        if state == 0 and v < -0.4:
            state, start = 1, x
        elif state == 1 and v > 0.4:
            state = 2
        elif state == 2 and v < 0.1:
            out.append((start, x))
            state = 0
    return out


def labelled_reps(t, rotation, counts):
    """Les vraies répétitions : dans chaque série du compteur, les N derniers gestes avant la fin
    de la série (N = répétitions comptées dans la série)."""
    candidates = segments(t, rotation)
    increments = np.flatnonzero(np.diff(counts) > 0) + 1
    # Séries : une pause de plus de 4 s entre deux incréments sépare deux séries
    sets, current = [], [increments[0]]
    for i in increments[1:]:
        if t[i] - t[current[-1]] > 4:
            sets.append(current)
            current = [i]
        else:
            current.append(i)
    sets.append(current)
    reps, previous_end = [], -np.inf
    for indices in sets:
        n = counts[indices[-1]] - counts[indices[0] - 1]
        end_time = t[indices[-1]] + 0.6
        inside = [c for c in candidates if previous_end < c[1] <= end_time]
        reps.extend(inside[-n:])
        previous_end = end_time
    return reps


def window(t, rotation, start, end):
    """Le geste rééchantillonné sur SAMPLES points, 3 axes, centré, de norme 1."""
    grid = np.linspace(start, end, SAMPLES)
    shape = np.stack([np.interp(grid, t, rotation[:, k]) for k in range(3)], axis=1)
    shape -= shape.mean(axis=0)
    norm = np.linalg.norm(shape)
    return shape / norm if norm > 0 else shape, norm


def template(t, rotation, reps):
    shapes, norms, durations = [], [], []
    for start, end in reps:
        shape, norm = window(t, rotation, start - 0.1, end + 0.1)
        shapes.append(shape)
        norms.append(norm)
        durations.append(end - start + 0.2)
    mean = np.mean(shapes, axis=0)
    return mean / np.linalg.norm(mean), float(np.median(norms)), float(np.median(durations))


def detect(t, rotation, model, threshold):
    """Fenêtre glissante : à chaque instant, le geste qui vient de finir ressemble-t-il au gabarit ?"""
    shape, norm, duration = model
    detections, last = [], -np.inf
    for i in range(0, len(t), 2):
        now = t[i]
        if now - last < 0.6 * duration:
            continue
        best = 0.0
        for scale in (0.75, 1.0, 1.3):
            d = duration * scale
            if now - d < t[0]:
                continue
            candidate, amplitude = window(t, rotation, now - d, now)
            if not 0.5 * norm <= amplitude <= 2.0 * norm:
                continue
            best = max(best, float(np.sum(candidate * shape)))
        if best >= threshold:
            detections.append(now)
            last = now
    return detections


def evaluate(detections, reps):
    ends = np.array([end for _, end in reps])
    matched, false = set(), 0
    for d in detections:
        k = int(np.argmin(np.abs(ends - d))) if len(ends) else -1
        if k >= 0 and abs(ends[k] - d) <= TOLERANCE and k not in matched:
            matched.add(k)
        else:
            false += 1
    # Les deux premières répétitions de chaque série (celles qu'on attend aujourd'hui)
    firsts, previous = [], -np.inf
    for k, (start, end) in enumerate(reps):
        if start - previous > 4:
            firsts.extend([k, k + 1])
        previous = end
    firsts = [k for k in firsts if k < len(reps)]
    early = sum(k in matched for k in firsts)
    return len(matched), false, early, len(firsts)


def main():
    paths = sorted(glob.glob(os.path.join(ROOT, "crunches_*.jsonl")))
    sessions = {}
    for path in paths:
        t, rotation, counts, actual = load(path)
        reps = labelled_reps(t, rotation, counts)
        sessions[os.path.basename(path)[9:28]] = (t, rotation, reps)
        print(f"{os.path.basename(path)} : {len(reps)} répétitions étiquetées (réel {actual})")

    for threshold in (0.7, 0.8, 0.85, 0.9):
        print(f"\nSeuil de ressemblance {threshold}")
        totals = np.zeros(5, dtype=int)
        for train, (t0, r0, reps0) in sessions.items():
            model = template(t0, r0, reps0)
            for test, (t1, r1, reps1) in sessions.items():
                if test == train:
                    continue
                found, false, early, firsts = evaluate(detect(t1, r1, model, threshold), reps1)
                totals += [found, len(reps1), false, early, firsts]
                print(f"  appris {train} → testé {test} : reconnues {found}/{len(reps1)}, "
                      f"fausses {false}, 2 premières de chaque série {early}/{firsts}")
        print(f"  TOTAL : reconnues {totals[0]}/{totals[1]} ({100 * totals[0] / totals[1]:.0f} %), "
              f"fausses {totals[2]}, premières {totals[3]}/{totals[4]}")


if __name__ == "__main__" and "--irregular" not in sys.argv:
    main()


# --- Séries irrégulières : de vrais abdos, séparés par des pauses de durée variable ----------

def irregular_session(frames, t, reps, rest, rng, count, pause_range):
    """Une séance reconstituée : repos réel, puis `count` vrais abdos tirés au hasard, chacun
    suivi d'une pause réelle (repos allongé) de durée aléatoire. Renvoie les mesures re-datées
    et les instants de fin des abdos."""
    out, ends, clock = [], [], 0.0

    def append(segment):
        nonlocal clock
        base = segment[0]["t"]
        for f in segment:
            g = dict(f)
            g["t"] = clock + (f["t"] - base)
            g.pop("pre", None)
            g.pop("reset", None)
            out.append(g)
        clock = out[-1]["t"] + 1 / 33

    def take(start, end):
        return [f for f in frames if start <= f["t"] <= end]

    rest_frames = take(*rest)
    append(rest_frames[: len(rest_frames) // 2])
    for k in rng.choice(len(reps), size=count, replace=False):
        start, end = reps[k]
        append(take(start - 0.15, end + 0.15))
        ends.append(clock)
        pause = rng.uniform(*pause_range)
        n = int(pause * 33)
        offset = rng.integers(0, max(1, len(rest_frames) - n))
        append(rest_frames[offset: offset + n] or rest_frames[:1])
    append(rest_frames[: len(rest_frames) // 2])
    return out, ends


def irregular_experiment():
    path = sorted(glob.glob(os.path.join(ROOT, "crunches_2026-10-28*.jsonl")))[0]
    meta, _, frames = rp.load(path)
    t0 = frames[0]["t"]
    for f in frames:
        f["t"] -= t0
    t = np.array([f["t"] for f in frames])
    rotation = np.array([f["v"]["rotation"] for f in frames], dtype=float)
    counter, counts, _ = rp.replay(frames, "crunches", meta.get("sources"))
    reps = labelled_reps(t, rotation, np.array(counts))
    # Gabarit appris sur les autres jours (26/10)
    models = []
    for other in sorted(glob.glob(os.path.join(ROOT, "crunches_2026-10-26*.jsonl"))):
        t1, r1, c1, _ = load(other)
        models.append(template(t1, r1, labelled_reps(t1, r1, c1)))
    model = models[0]
    rest = (280.0, 300.0)   # 20 s allongé immobile entre deux séries
    rng = np.random.default_rng(1)
    print("\nSéries irrégulières (15 vrais abdos, pauses aléatoires) : compteur actuel / gabarit")
    for label, pauses in (("pauses 0,2-1 s", (0.2, 1.0)), ("pauses 1-2,5 s", (1.0, 2.5)),
                          ("pauses 2-4 s (repos entre chaque)", (2.0, 4.0))):
        current, learned = [], []
        for _ in range(5):
            session, ends = irregular_session(frames, t, reps, rest, rng, 15, pauses)
            c, _, _ = rp.replay(session, "crunches", meta.get("sources"))
            current.append(c.count)
            ts = np.array([f["t"] for f in session])
            rs = np.array([f["v"]["rotation"] for f in session], dtype=float)
            found, false, _, _ = evaluate(detect(ts, rs, model, 0.8), [(e - 1, e) for e in ends])
            learned.append(found + false)
        print(f"  {label} : compteur actuel {current} ; gabarit {learned} (attendu 15)")


if __name__ == "__main__" and "--irregular" in sys.argv:
    irregular_experiment()

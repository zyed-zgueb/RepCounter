#!/usr/bin/env python3
"""Répétitions en réserve des pompes, tirées de la perte de vitesse : ajustement et validation sur
les séries menées à l'échec (Recordings/echec.json).

Usage : python3 Simulation/failure.py

Aucune étude ne relie la perte de vitesse aux répétitions restantes pour les pompes. On reprend la
forme du modèle publié pour le développé couché, le squat et les tractions (González-Badillo et
Sánchez-Medina ; Sánchez-Moreno et al. 2017, IJSPP 12(10):1378–1384) : part des répétitions
possibles déjà faites = a·PV² + b·PV + c, PV = perte de vitesse de la série en % (depuis la
répétition la plus rapide), ajustée ici sur les séries de la personne.
Vitesse : montée de 25 à 50 cm mesurée par la caméra TrueDepth (Simulation/velocity.py), lissée
sur les 2 dernières répétitions.
Validation (feuille de route) : validation croisée en laissant une série de côté ; erreur sur les
répétitions restantes, 3 répétitions avant l'échec ; seuil d'acceptation : erreur médiane ≤ 2.
Il faut au moins 10 séries à l'échec avant de conclure.
"""

import json
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import replay as rp  # noqa: E402
import velocity as vel  # noqa: E402

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "Recordings")
MIN_SETS = 10


def series(path):
    """[(répétitions faites, perte de vitesse en %)] pour chaque répétition de la série."""
    meta, end, frames = rp.load(path)
    speeds = [v for _, v in vel.pushup_velocities(frames, frames[0]["t"])]
    out, best = [], 0.0
    for i in range(len(speeds)):
        recent = speeds[max(0, i - 1): i + 1]
        best = max(best, speeds[i])
        out.append((i + 1, 100 * (best - sum(recent) / len(recent)) / best))
    return out


def fit(sets):
    """Coefficients (a, b, c) de part faite (%) = a·PV² + b·PV + c, sur toutes les répétitions."""
    x, y = [], []
    for points, total in sets:
        for done, loss in points:
            x.append(loss)
            y.append(100 * done / total)
    return np.polyfit(x, y, 2)


def reserve(coefficients, done, loss):
    share = min(max(np.polyval(coefficients, loss), 1), 100)
    return done * 100 / share - done


def main():
    manifest = json.load(open(os.path.join(ROOT, "echec.json")))
    sets = []
    for name, info in sorted(manifest.items()):
        if info["exercise"] != "pushups":
            continue
        points = series(os.path.join(ROOT, name))
        if len(points) != info["reps"]:
            print(f"{name} : {len(points)} montées mesurées pour {info['reps']} pompes, série écartée")
            continue
        sets.append((points, info["reps"]))
        print(f"{name} : {info['reps']} pompes, perte de vitesse finale {points[-1][1]:.0f} %")

    coefficients = fit(sets)
    print(f"\nAjustement sur {len(sets)} série(s) : part faite = {coefficients[0]:.4f}·PV² + "
          f"{coefficients[1]:.3f}·PV + {coefficients[2]:.2f}")
    if len(sets) < 2:
        print(f"Validation croisée impossible : il faut au moins 2 séries ({MIN_SETS} pour conclure).")
        return 0
    errors = []
    for k, (points, total) in enumerate(sets):
        model = fit(sets[:k] + sets[k + 1:])
        done, loss = points[total - 4]            # 3 répétitions avant l'échec
        errors.append(reserve(model, done, loss) - 3)
    median = float(np.median(np.abs(errors)))
    print(f"Validation croisée ({len(sets)} séries) : erreur 3 avant l'échec, médiane {median:.1f} "
          f"répétition(s) ; détail {[round(e, 1) for e in errors]}")
    verdict = "ACCEPTÉ" if len(sets) >= MIN_SETS and median <= 2 else "pas encore validé"
    print(f"Critère (≥ {MIN_SETS} séries, erreur médiane ≤ 2) : {verdict}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

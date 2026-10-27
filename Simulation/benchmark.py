#!/usr/bin/env python3
"""Banc d'essai de la précision : rejoue tous les enregistrements réels dans le compteur Python.

Chaque enregistrement de Recordings/ porte le nombre de répétitions réellement faites (indiqué
dans l'app à la fin de l'enregistrement). Le banc rejoue chacun et compare :
  - réel / rejoué : la précision du compteur actuel ;
  - app / rejoué : la cohérence du portage Swift ↔ Python (un écart vient d'une version de
    l'app plus ancienne que le compteur, ou d'un portage à vérifier).

Il résume la précision par exercice et par mode (caméra / mouvement), puis compare à la
référence Recordings/benchmark.json : un enregistrement exact dans la référence qui ne l'est
plus est une régression (code de sortie 1). Après une amélioration vérifiée :
    python3 Simulation/benchmark.py --update

Usage :
    python3 Simulation/benchmark.py [--recordings Recordings] [--update]
Dépendances : numpy.
"""

import argparse
import glob
import json
import os
import sys
from collections import defaultdict

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import replay as rp  # noqa: E402

CAMERA_SOURCES = {"depth", "pixels", "face", "pose"}


def mode(sources):
    """Caméra si l'app écoutait au moins un capteur de la caméra, sinon mouvement."""
    return "caméra" if CAMERA_SOURCES & set(sources or []) else "mouvement"


def run(path):
    meta, end, frames = rp.load(path)
    if not frames or end.get("actualReps") is None:
        return None
    t0 = frames[0]["t"]
    for frame in frames:
        frame["t"] -= t0
    exercise = meta.get("exercise", "auto")
    sources = meta.get("sources")
    counter, _, _ = rp.replay(frames, exercise, sources)
    return dict(file=os.path.basename(path), exercise=exercise, mode=mode(sources),
                actual=end["actualReps"], app=frames[-1].get("count", 0), replayed=counter.count)


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    root = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "Recordings")
    parser.add_argument("--recordings", default=root)
    parser.add_argument("--update", action="store_true", help="enregistre les résultats comme nouvelle référence")
    args = parser.parse_args()

    results = [r for r in map(run, sorted(glob.glob(os.path.join(args.recordings, "*.jsonl")))) if r]
    if not results:
        sys.exit("Aucun enregistrement avec le nombre réel de répétitions.")

    print(f"{'enregistrement':44s} {'mode':9s} {'réel':>4s} {'app':>4s} {'rejoué':>6s}")
    for r in results:
        flag = "" if r["replayed"] == r["actual"] else f"  ✗ {r['replayed'] - r['actual']:+d}"
        port = "" if r["app"] == r["replayed"] else "  (app ≠ rejoué)"
        print(f"{r['file']:44s} {r['mode']:9s} {r['actual']:4d} {r['app']:4d} {r['replayed']:6d}{flag}{port}")

    print("\nPrécision par exercice (compteur actuel)")
    groups = defaultdict(list)
    for r in results:
        groups[(r["exercise"], r["mode"])].append(r)
    for (exercise, sensor), items in sorted(groups.items()):
        exact = sum(r["replayed"] == r["actual"] for r in items)
        reps = sum(r["actual"] for r in items)
        error = sum(abs(r["replayed"] - r["actual"]) for r in items)
        print(f"  {exercise:10s} {sensor:9s} {exact}/{len(items)} séances exactes · "
              f"{error} erreur{'s' if error > 1 else ''} sur {reps} répétitions "
              f"({100 * (1 - error / max(reps, 1)):.1f} %)")

    reference_path = os.path.join(args.recordings, "benchmark.json")
    current = {r["file"]: r["replayed"] for r in results}
    if args.update:
        with open(reference_path, "w", encoding="utf-8") as file:
            json.dump(current, file, indent=1, sort_keys=True, ensure_ascii=False)
        print(f"\nRéférence mise à jour : {reference_path}")
        return
    if not os.path.exists(reference_path):
        print("\nPas encore de référence (--update pour la créer).")
        return
    with open(reference_path, encoding="utf-8") as file:
        reference = json.load(file)
    actual = {r["file"]: r["actual"] for r in results}
    regressions = [f for f, count in reference.items()
                   if f in current and count == actual[f] and current[f] != actual[f]]
    fixed = [f for f, count in reference.items()
             if f in current and count != actual[f] and current[f] == actual[f]]
    for f in fixed:
        print(f"  ✓ corrigé : {f}")
    for f in regressions:
        print(f"  ✗ RÉGRESSION : {f} (réel {actual[f]}, rejoué {current[f]})")
    if regressions:
        sys.exit(1)
    print("\nAucune régression.")


if __name__ == "__main__":
    main()

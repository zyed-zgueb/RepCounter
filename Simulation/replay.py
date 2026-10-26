#!/usr/bin/env python3
"""Rejoue un enregistrement de l'app dans le compteur Python et trace les signaux.

L'app enregistre (bouton ● pendant une séance) un fichier JSON Lines : une ligne `meta`,
une ligne par mesure ({"t", "v": {source: [valeurs]}, "count", "state", "leader"}), et une
ligne `end` avec le nombre de répétitions réellement faites.

Usage :
    python3 Simulation/replay.py Recordings/pushups_2026-10-26_18-30-00.jsonl
    python3 Simulation/replay.py fichier.jsonl --png courbes.png --profile auto

Affiche le compte de l'app, celui du compteur Python rejoué (les deux doivent être égaux :
sinon, le portage Swift ↔ Python diverge) et le nombre réel. L'image montre, pour chaque
capteur écouté, le signal suivi et les cycles détectés ; en haut, le compteur au fil du temps.
Dépendances : numpy, matplotlib.
"""

import argparse
import json
import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import simulate_counter as sc  # noqa: E402


def load(path):
    meta, end, frames = {}, {}, []
    with open(path, encoding="utf-8") as file:
        for line in file:
            line = line.strip()
            if not line:
                continue
            try:
                record = json.loads(line)
            except json.JSONDecodeError:
                continue   # dernière ligne tronquée (app fermée pendant l'écriture)
            if record.get("type") == "meta":
                meta = record
            elif record.get("type") == "end":
                end = record
            else:
                frames.append(record)
    return meta, end, frames


def replay(frames, profile):
    """Rejoue les mesures ; renvoie le compteur et, par source, le signal suivi à chaque instant."""
    counter = sc.AutoCounter(profile)
    traces = {source: [] for source in sc.PROFILES[profile]["sources"]}
    counts = []
    for frame in frames:
        values = {source: np.array(v, dtype=float) for source, v in frame["v"].items()}
        counter.process(frame["t"], values)
        counts.append(counter.count)
        for source, trace in traces.items():
            tracker = counter.trackers.get(source)
            value = tracker.signal[-1] if tracker is not None and len(tracker.signal) else math.nan
            trace.append(value)
    return counter, counts, traces


def plot(path, times, app_counts, replay_counts, traces, counter, title):
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt

    sources = [s for s, trace in traces.items() if not all(math.isnan(v) for v in trace)]
    figure, axes = plt.subplots(len(sources) + 1, 1, figsize=(14, 2.2 * (len(sources) + 1)), sharex=True)
    axes = np.atleast_1d(axes)
    axes[0].step(times, app_counts, where="post", label="app", color="#3DC1FE", linewidth=2)
    axes[0].step(times, replay_counts, where="post", label="rejoué (Python)", color="#AB64FA", linestyle="--")
    axes[0].set_ylabel("répétitions")
    axes[0].legend(loc="upper left")
    axes[0].set_title(title)
    for axis, source in zip(axes[1:], sources):
        axis.plot(times, traces[source], color="#555", linewidth=1)
        tracker = counter.trackers.get(source)
        if tracker is not None:
            for cycle in tracker.cycles:
                axis.axvline(cycle, color="#3DC1FE", alpha=0.5, linewidth=1)
        leader_mark = " (référence)" if any(lock[1] == source for lock in counter.locks) else ""
        axis.set_ylabel(source + leader_mark)
    axes[-1].set_xlabel("temps (s)")
    figure.tight_layout()
    figure.savefig(path, dpi=110)
    print(f"Courbes : {path}")


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("recording")
    parser.add_argument("--png", help="image des courbes (par défaut : à côté de l'enregistrement)")
    parser.add_argument("--profile", help="profil à rejouer (par défaut : celui de l'enregistrement)")
    args = parser.parse_args()

    meta, end, frames = load(args.recording)
    if not frames:
        sys.exit("Aucune mesure dans l'enregistrement.")
    profile = args.profile or meta.get("exercise", "auto")
    times = np.array([frame["t"] for frame in frames])
    times = times - times[0]
    rate = (len(times) - 1) / times[-1] if times[-1] > 0 else 0
    print(f"{meta.get('exercise', '?')} · {meta.get('device', '?')} iOS {meta.get('system', '?')} · "
          f"{times[-1]:.1f} s · {len(frames)} mesures ({rate:.0f}/s)")

    # Les instants de l'enregistrement sont décalés pour partir de 0
    for frame, t in zip(frames, times):
        frame["t"] = float(t)
    counter, replay_counts, traces = replay(frames, profile)
    app_counts = [frame.get("count", 0) for frame in frames]

    actual = end.get("actualReps")
    print(f"Réel : {actual if actual is not None else 'non indiqué'} · "
          f"app : {app_counts[-1]} · rejoué (profil {profile}) : {counter.count}")
    if counter.count != app_counts[-1]:
        print("  ⚠ L'app et le compteur Python divergent : version de l'app différente, ou portage Swift ↔ Python à vérifier.")
    for time, source, regularity in counter.locks:
        print(f"  Démarrage du comptage à {time:.1f} s sur « {source} » (régularité {regularity:.2f})")
    for source, tracker in counter.trackers.items():
        print(f"  {source:9s} cycles à : {', '.join(f'{c:.1f}' for c in tracker.cycles)}")

    png = args.png or os.path.splitext(args.recording)[0] + ".png"
    title = f"{os.path.basename(args.recording)} — réel {actual}, app {app_counts[-1]}, rejoué {counter.count}"
    plot(png, times, app_counts, replay_counts, traces, counter, title)


if __name__ == "__main__":
    main()

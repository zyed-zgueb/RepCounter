#!/usr/bin/env python3
"""Mesures de la mise en place dans un enregistrement, seconde par seconde, pour régler les
seuils de PlacementMonitor (RepCounter/Placement.swift).

Affiche, pour chaque seconde : la gravité (orientation de l'iPhone), la vitesse de rotation
lissée (immobile, respiration, manipulation), la profondeur au centre et le visage (pompes),
la luminosité, et pour le squelette la taille du torse et le centrage (exercices à la caméra).

Usage :
    python3 Simulation/placement.py Recordings/<fichier>.jsonl
"""

import json
import math
import sys

JOINTS = ["nose", "neck", "lShoulder", "rShoulder", "lElbow", "rElbow", "lWrist", "rWrist",
          "root", "lHip", "rHip", "lKnee", "rKnee", "lAnkle", "rAnkle"]   # Skeleton.joints
IMAGE_ASPECT = 0.75
ROTATION_SMOOTHING = 0.6


def body_metrics(flat):
    if not flat:
        return ""
    pts = {name: (flat[2 * i], flat[2 * i + 1]) for i, name in enumerate(JOINTS) if flat[2 * i] >= 0}
    if not pts:
        return "squelette : aucun"
    neck = pts.get("neck")
    if neck is None and "lShoulder" in pts and "rShoulder" in pts:
        neck = tuple((a + b) / 2 for a, b in zip(pts["lShoulder"], pts["rShoulder"]))
    hip = pts.get("root")
    if hip is None and "lHip" in pts and "rHip" in pts:
        hip = tuple((a + b) / 2 for a, b in zip(pts["lHip"], pts["rHip"]))
    hip = hip or pts.get("lHip") or pts.get("rHip")
    text = f"squelette : {len(pts):2d} art."
    if neck and hip:
        torso = math.hypot((neck[0] - hip[0]) * IMAGE_ASPECT, neck[1] - hip[1])
        text += f" · torse {torso:.2f} · centre x {neck[0]:.2f}"
    wrists = [w for w in ("lWrist", "rWrist") if w in pts]
    text += f" · poignets {len(wrists)}"
    return text


def main():
    path = sys.argv[1]
    rotation, last_t, last_second = 0.0, None, None
    with open(path, encoding="utf-8") as file:
        for line in file:
            try:
                frame = json.loads(line)
            except json.JSONDecodeError:
                continue
            if "t" not in frame:
                continue
            t, v, x = frame["t"], frame.get("v", {}), frame.get("x", {})
            if "rotation" in v:
                magnitude = math.sqrt(sum(c * c for c in v["rotation"]))
                dt = min(max(t - last_t, 0), 0.2) if last_t is not None else 0
                rotation = magnitude if last_t is None else rotation + min(dt / ROTATION_SMOOTHING, 1) * (magnitude - rotation)
            last_t = t
            second = int(t)
            if second == last_second:
                continue
            last_second = second
            parts = [f"{t:9.1f}s"]
            if "motion" in v:
                g = v["motion"]
                parts.append(f"g ({g[0]:+.2f} {g[1]:+.2f} {g[2]:+.2f})")
            parts.append(f"rot {rotation:.3f}")
            if "depthStats" in x:
                d = x["depthStats"]
                parts.append(f"prof. méd. {d[1]:.2f} m · couv. {d[3]:.2f}")
            if "face" in v:
                parts.append(f"visage {v['face'][2]:.2f}")
            if "pixels" in v:
                parts.append(f"lum. {sum(v['pixels']) / len(v['pixels']):.2f}")
            if "joints" in x:
                parts.append(body_metrics(x["joints"]))
            print(" · ".join(parts))


if __name__ == "__main__":
    main()

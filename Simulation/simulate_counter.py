#!/usr/bin/env python3
"""Simulation du compteur automatique de RepCounter.

Reproduit en Python la logique de `RepCounter/AutoCounter.swift` (mêmes réglages, mêmes
étapes) et la fait tourner sur des capteurs synthétiques : pompes au-dessus du téléphone,
abdos téléphone sur la poitrine, pauses, et situations pièges sans répétition.

Usage :
    python3 simulate_counter.py            # 5 tirages par scénario
    python3 simulate_counter.py --seeds 20

Critères : aucun faux départ (exactement 0 dans les scénarios sans répétition) et au plus
une répétition d'écart sur les séries. L'écart d'une répétition apparaît quand la première
répétition suit immédiatement une manipulation du téléphone. Code de sortie 1 sinon.
Dépendance : numpy.
"""

import argparse
import math
import sys

import numpy as np

# --- Réglages : identiques à `Tuning` et `SignalSource` dans AutoCounter.swift ---------------

HISTORY = 16.0          # s d'historique
STATS_WINDOW = 10.0     # s pour les seuils adaptatifs
PCA_FRAMES = 120        # ~4 s pour l'ACP
AXIS_REFRESH = 10       # recalcul de l'axe toutes les 10 images
MIN_PERIOD = 0.4
MAX_PERIOD = 6.0
HIGH, LOW = 0.75, 0.25
MIN_REGULARITY = 0.6
MAX_ROUGHNESS = 0.12   # au-delà, signal trop saccadé : du bruit, pas un geste

MIN_AMPLITUDE = {"depth": 0.04, "pixels": 0.05, "face": 0.03, "pose": 0.2, "motion": 0.1, "vertical": 0.08}
PREFERENCE = ["depth", "motion", "vertical", "pose", "face", "pixels"]


# --- Outils de signal : équivalents de SignalMath.swift --------------------------------------

def moving_average(values, width):
    """Moyenne glissante causale."""
    out = np.zeros(len(values))
    total = 0.0
    for i, v in enumerate(values):
        total += v
        if i >= width:
            total -= values[i - width]
        out[i] = total / min(i + 1, width)
    return out


def percentile(values, p):
    s = np.sort(values)
    return s[min(len(s) - 1, int((len(s) - 1) * p))]


def lag_correlation(values, lag):
    a, b = values[:-lag], values[lag:]
    a, b = a - a.mean(), b - b.mean()
    den = math.sqrt((a * a).sum() * (b * b).sum())
    return (a * b).sum() / den if den > 0 else 0.0


def top_eigenvector(matrix, seed):
    v = seed.copy() if seed is not None and len(seed) == len(matrix) else 1 + 0.37 * ((np.arange(len(matrix)) * 7) % 11)
    v = v / np.linalg.norm(v)
    for _ in range(30):
        w = matrix @ v
        norm = np.linalg.norm(w)
        if norm < 1e-12:
            return None
        v = w / norm
    return v


def principal_axis(samples, seed):
    """Axe principal (ACP) ; matrice de Gram quand il y a plus de dimensions que d'images."""
    x = np.array(samples)
    n, d = x.shape
    if n < 10:
        return None
    centered = x - x.mean(0)
    if d <= n:
        axis = top_eigenvector(centered.T @ centered, seed)
    else:
        u = top_eigenvector(centered @ centered.T, None if seed is None else centered @ seed)
        if u is None:
            return None
        axis = centered.T @ u
        norm = np.linalg.norm(axis)
        if norm < 1e-9:
            return None
        axis = axis / norm
    if axis is not None and seed is not None and axis @ seed < 0:
        axis = -axis
    return axis


# --- Compteur : équivalent de SignalTracker et AutoCounter ------------------------------------

class SignalTracker:
    """Une source : ACP glissante → signal 1D → cycles par hystérésis adaptative."""

    def __init__(self, source):
        self.source = source
        self.times, self.rows, self.cycles = [], [], []
        self.cycle_amplitudes = []   # amplitude du signal au moment de chaque cycle
        self.signal = np.zeros(0)
        self.axis = None
        self.frame_index = 0
        self.is_high = False
        self.amplitude = 0.0
        self.phase = 0.0

    def process(self, value, t):
        """Ajoute une mesure ; renvoie True quand un cycle complet vient de se terminer."""
        self.times.append(t)
        self.rows.append(value)
        while self.times[0] < t - HISTORY:
            self.times.pop(0)
            self.rows.pop(0)

        self.frame_index += 1
        if len(value) == 1:
            self.axis = np.array([1.0])
        elif self.axis is None or self.frame_index % AXIS_REFRESH == 0:
            axis = principal_axis(self.rows[-PCA_FRAMES:], self.axis)
            if axis is not None:
                self.axis = axis
        if self.axis is None or len(self.rows) < 10:
            return False

        self.signal = moving_average(np.array(self.rows) @ self.axis, 5)
        recent = self.signal[np.array(self.times) >= t - STATS_WINDOW]
        low = percentile(recent, 0.05)
        self.amplitude = percentile(recent, 0.95) - low
        if self.amplitude < MIN_AMPLITUDE[self.source]:
            self.phase = 0.0
            return False

        n = (self.signal[-1] - low) / self.amplitude
        self.phase = min(max(n, 0.0), 1.0)
        if not self.is_high and n > HIGH:
            self.is_high = True
        elif self.is_high and n < LOW:
            self.is_high = False
            if self.cycles and t - self.cycles[-1] < MIN_PERIOD:
                return False
            self.cycles = (self.cycles + [t])[-30:]
            self.cycle_amplitudes = (self.cycle_amplitudes + [self.amplitude])[-30:]
            return True
        return False

    def period(self):
        if len(self.cycles) < 3:
            return None
        return (self.cycles[-1] - self.cycles[-3]) / 2

    def regularity(self, t):
        """0 si ce n'est pas un rythme net, sinon la corrélation à une période d'écart."""
        if len(self.cycles) < 3 or self.amplitude <= 0:
            return 0.0
        p1, p2 = self.cycles[-2] - self.cycles[-3], self.cycles[-1] - self.cycles[-2]
        if min(p1, p2) < MIN_PERIOD or max(p1, p2) > MAX_PERIOD or max(p1, p2) / min(p1, p2) > 1.5:
            return 0.0
        period = (p1 + p2) / 2
        times = np.array(self.times)
        if times[-1] - times[0] < 1.8 * period:
            return 0.0
        lag = int(round(period / ((times[-1] - times[0]) / (len(times) - 1))))
        segment = self.signal[times >= t - 2.5 * period]
        if lag < 2 or len(segment) <= lag + 5:
            return 0.0
        full = lag_correlation(segment, lag)
        half = lag_correlation(segment, max(1, lag // 2))
        roughness = np.std(np.diff(segment)) / self.amplitude
        if full < MIN_REGULARITY or half > -0.2 or roughness > MAX_ROUGHNESS:
            return 0.0
        return full

    def missed_cycles_before_regular_run(self):
        """Cycles faits avant que la série soit jugée régulière : ceux déjà détectés qui
        s'enchaînent à un rythme plausible, puis ceux manqués pendant la mise en place."""
        period = self.period()
        chain = len(self.cycles) - 3
        while (chain > 0 and 0.7 * period <= self.cycles[chain] - self.cycles[chain - 1] <= 1.4 * period
               and self.cycle_amplitudes[chain - 1] >= 0.5 * self.amplitude):
            chain -= 1
        detected = len(self.cycles) - 3 - chain
        run_start = self.cycles[chain]
        times = np.array(self.times)
        mask = times >= run_start - 1.3 * period
        segment, segment_times = self.signal[mask], times[mask]
        low = percentile(segment, 0.05)
        amplitude = percentile(segment, 0.95) - low
        if amplitude <= 0:
            return detected
        high, missed = False, 0
        for value, time in zip(segment, segment_times):
            n = (value - low) / amplitude
            if not high and n > HIGH:
                high = True
            elif high and n < LOW:
                high = False
                if time < run_start - 0.5 * period:
                    missed += 1
        return detected + missed


class AutoCounter:
    """Toutes les sources suivies en parallèle ; la première avec 3 cycles réguliers mène."""

    def __init__(self):
        self.trackers = {}
        self.leader = None
        self.count = 0
        self.last_count_time = -math.inf
        self.locks = []   # (instant, source, régularité) : pour comprendre les résultats

    def process(self, time, values):
        completed = set()
        for source, value in values.items():
            tracker = self.trackers.setdefault(source, SignalTracker(source))
            if tracker.process(value, time):
                completed.add(source)

        if self.leader:
            tracker = self.trackers[self.leader]
            if self.leader in completed:
                self.count += 1
                self.last_count_time = time
            if time - self.last_count_time > max(4, 3 * (tracker.period() or 2)):
                self.leader = None
            return

        best = None
        for source in PREFERENCE:
            if source not in completed:
                continue
            score = self.trackers[source].regularity(time)
            if score >= MIN_REGULARITY and (best is None or round(score * 10) > round(best[1] * 10)):
                best = (source, score)
        if best:
            self.leader = best[0]
            self.count += 3 + self.trackers[best[0]].missed_cycles_before_regular_run()
            self.last_count_time = time
            self.locks.append((round(time, 1), best[0], round(best[1], 2)))


# --- Capteurs synthétiques ---------------------------------------------------------------------

def synthetic_session(kind, segments, seed, pixel_count=192, fps=30):
    """Images (instant, {source: mesure}) pour une suite de segments :
    ("rep", durée, période), ("rest", durée) ou ("walk", durée) = téléphone manipulé.
    kind : "pushup" (téléphone au sol), "abs" (sur la poitrine), "squat" (à la main)."""
    rng = np.random.default_rng(seed)
    pixel_base = rng.uniform(0.2, 0.8, pixel_count)
    frames, t = [], 0.0
    for segment in segments:
        kind_of_segment, duration = segment[0], segment[1]
        period = segment[2] if len(segment) > 2 else 1.0
        walking = kind_of_segment == "walk"
        for i in range(int(duration * fps)):
            t += 1 / fps
            # m : 0 en position de départ, 1 au point le plus éloigné du mouvement
            m = 0.5 * (1 - math.cos(2 * math.pi * (i / fps) / period)) if kind_of_segment == "rep" else 0.0
            values = {}
            if kind == "pushup":
                # Téléphone au sol sous la tête : distance, assombrissement, visage, téléphone immobile
                depth = rng.uniform(0.3, 1.5) if walking else 0.45 - 0.3 * m
                valid = 1.0 if depth > 0.2 else 0.2
                values["depth"] = np.array([depth + rng.normal(0, 0.01), valid + rng.normal(0, 0.02)])
                light = rng.uniform(0.5, 1.2) if walking else 1.0
                values["pixels"] = pixel_base * (1 - 0.6 * m) * light + rng.normal(0, 0.02, pixel_count)
                if m < 0.6 and not walking:
                    values["face"] = np.array([0.5, 0.5, 0.3 + 0.4 * m]) + rng.normal(0, 0.01, 3)
                gravity = rng.normal(0, 0.5, 3) if walking else np.array([0, 0, -1.0])
                values["motion"] = gravity + rng.normal(0, 0.003, 3)
                values["vertical"] = np.array([rng.normal(0, 0.5 if walking else 0.003)])
            elif kind == "squat":
                # Téléphone tenu à la main devant soi : il monte et descend de 40 cm sans
                # presque s'incliner ; seule l'accélération verticale voit bien le mouvement
                w = 2 * math.pi / period
                tt = i / fps
                tilt = rng.uniform(0, 3) if walking else math.radians(5 * m)
                values["motion"] = np.array([0, -math.cos(tilt), -math.sin(tilt)]) + rng.normal(0, 0.01, 3)
                vertical = -0.2 * w * w * math.cos(w * tt) / 9.81 if kind_of_segment == "rep" else 0.0
                values["vertical"] = np.array([vertical + rng.normal(0, 0.5 if walking else 0.02)])
                values["pixels"] = rng.uniform(0, 1, pixel_count) * 0.5 + 0.3
                values["depth"] = np.array([rng.uniform(0.3, 2), rng.uniform(0, 1)])
            else:
                # Téléphone contre la poitrine : inclinaison du buste + respiration ;
                # la caméra et la profondeur ne voient que du bruit
                angle = rng.uniform(0, 3) if walking else math.radians(20 + 60 * (1 - m))
                angle += 0.03 * math.sin(2 * math.pi * t / 4)
                values["motion"] = np.array([0, -math.sin(angle), -math.cos(angle)]) + rng.normal(0, 0.01, 3)
                values["vertical"] = np.array([rng.normal(0, 0.5 if walking else 0.02)])
                values["pixels"] = rng.uniform(0, 1, pixel_count) * 0.5 + 0.3
                values["depth"] = np.array([rng.uniform(0.3, 2), rng.uniform(0, 1)])
            frames.append((t, values))
    return frames


SCENARIOS = [
    ("Pompes 15, après 3 s de mise en place", "pushup",
     [("walk", 3), ("rest", 2), ("rep", 15 * 1.6, 1.6), ("rest", 2)], 15),
    ("Pompes rapides 20 (1 s)", "pushup",
     [("rest", 2), ("rep", 20 * 1.0, 1.0), ("rest", 2)], 20),
    ("Abdos 12, téléphone sur la poitrine, après manipulation", "abs",
     [("walk", 3), ("rest", 3), ("rep", 12 * 2.5, 2.5), ("rest", 2)], 12),
    ("Abdos lents 8 (4 s par rep)", "abs",
     [("rest", 3), ("rep", 8 * 4, 4.0), ("rest", 2)], 8),
    ("Squats 10, téléphone tenu à la main", "squat",
     [("walk", 3), ("rest", 2), ("rep", 10 * 2.5, 2.5), ("rest", 3)], 10),
    ("Squats rapides 12 (1,8 s)", "squat",
     [("rest", 2), ("rep", 12 * 1.8, 1.8), ("rest", 3)], 12),
    ("2 séries de pompes : 10 + pause 15 s + 8", "pushup",
     [("rest", 2), ("rep", 10 * 1.6, 1.6), ("rest", 15), ("rep", 8 * 1.6, 1.6), ("rest", 2)], 18),
    ("Téléphone posé, personne, 60 s", "pushup", [("rest", 60)], 0),
    ("Allongé immobile en respirant, téléphone sur la poitrine, 60 s", "abs", [("rest", 60)], 0),
    ("Téléphone manipulé, 20 s", "abs", [("walk", 20)], 0),
    ("Debout immobile, téléphone à la main, 60 s", "squat", [("rest", 60)], 0),
]


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--seeds", type=int, default=5, help="nombre de tirages aléatoires par scénario")
    args = parser.parse_args()

    failures = exact_runs = 0
    for name, kind, segments, expected in SCENARIOS:
        counts, sources = [], set()
        for seed in range(1, args.seeds + 1):
            counter = AutoCounter()
            for time, values in synthetic_session(kind, segments, seed):
                counter.process(time, values)
            counts.append(counter.count)
            sources.update(source for _, source, _ in counter.locks)
        exact = all(c == expected for c in counts)
        tolerance = 0 if expected == 0 else 1
        ok = all(abs(c - expected) <= tolerance for c in counts)
        failures += not ok
        exact_runs += sum(c == expected for c in counts)
        used = f"  [{', '.join(sorted(sources))}]" if sources else ""
        label = "OK   " if exact else ("±1   " if ok else "ÉCHEC")
        print(f"{label} {name} : attendu {expected}, obtenu {counts}{used}")

    total_runs = len(SCENARIOS) * args.seeds
    print(f"\n{exact_runs}/{total_runs} séances exactes ; "
          f"{len(SCENARIOS) - failures}/{len(SCENARIOS)} scénarios dans les critères")
    sys.exit(1 if failures else 0)


if __name__ == "__main__":
    main()

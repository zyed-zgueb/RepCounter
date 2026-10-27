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
STATS_WINDOW = 6.0      # s pour les seuils adaptatifs
PCA_FRAMES = 120        # ~4 s pour l'ACP
AXIS_REFRESH = 10       # recalcul de l'axe toutes les 10 images
MIN_PERIOD = 0.4
MAX_PERIOD = 6.0
HIGH, LOW = 0.75, 0.25
MIN_REGULARITY = 0.6
MAX_ROUGHNESS = 0.12   # au-delà, signal trop saccadé : du bruit, pas un geste

MIN_AMPLITUDE = {"depth": 0.04, "pixels": 0.05, "face": 0.03, "pose": 0.2, "motion": 0.1,
                 "vertical": 0.08, "rotation": 0.25}
WEAK_CYCLE_RATIO = 0.4    # en série, un cycle plus faible que 40 % des précédents ne compte pas
# En série, un cycle 40 % plus ample que les précédents, après une pause d'au moins 1,5 fois le
# rythme de la série : le téléphone qu'on reprend en fin de série. Il ne compte pas, la série est finie.
STRONG_CYCLE_RATIO = 1.4
PAUSE_RATIO = 1.5
HANDLING_ROTATION = 0.5  # rad/s : au-delà, un téléphone censé être posé est manipulé

# Profils d'exercice : identiques à `Exercise` dans Exercise.swift.
# sources : capteurs écoutés, par ordre de préférence ; max_period : écart max entre deux reps.
PROFILES = {
    "auto": dict(sources=["depth", "motion", "vertical", "pose", "face", "pixels"]),
    "pushups": dict(sources=["depth", "face", "pixels"], phone_at_rest=True),
    # Abdos dynamiques, téléphone sur la poitrine : le gyroscope voit un petit basculement
    # rapide des épaules ~7 fois plus fort qu'une respiration de même angle
    "crunches": dict(sources=["rotation"], max_period=3.0),
    "squats": dict(sources=["vertical", "motion"]),
    "curls": dict(sources=["motion", "rotation"]),
    "press": dict(sources=["vertical", "motion"]),
    "lunges": dict(sources=["vertical", "motion"]),
    "pullups": dict(sources=["vertical", "motion"]),
    "dips": dict(sources=["vertical", "motion"]),
    "row": dict(sources=["motion", "rotation"]),
}


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

    def __init__(self, source, min_amplitude, max_period):
        self.source = source
        self.min_amplitude = min_amplitude
        self.max_period = max_period
        self.times, self.rows, self.cycles = [], [], []
        self.cycle_swings = []       # écart max − min du signal pendant chaque cycle
        self.signal = np.zeros(0)
        self.axis = None
        self.frame_index = 0
        # Un cycle se termine au retour à la position de repos, après être passé à l'autre
        # extrême. Par défaut le repos est le bas du signal ; au démarrage du comptage, on
        # regarde où était le signal juste avant la série (adopt_rest_position).
        self.rest_high = False
        # Capteur de vitesse (gyroscope, accélération) : au repos, le signal est au milieu
        self.rest_in_middle = False
        self.armed = False
        self.armed_since = -math.inf
        self.last_rep_peak = -math.inf   # extrême du geste de la dernière répétition comptée
        self.skip_next = False
        self.ignore_before = -math.inf
        self.amplitude = 0.0
        self.phase = 0.0

    def forget_cycles(self, before):
        """Remise à zéro du compteur : oublie les cycles passés."""
        self.cycles, self.cycle_swings = [], []
        self.ignore_before = before

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
        if self.amplitude < self.min_amplitude:
            self.phase = 0.0
            return False

        n = (self.signal[-1] - low) / self.amplitude
        self.phase = min(max(n, 0.0), 1.0)
        at_extreme = n < LOW if self.rest_high else n > HIGH
        at_rest = n > HIGH if self.rest_high else n < LOW
        period = self.period()
        if not self.armed and at_extreme:
            self.armed = True
            self.armed_since = t
        elif (self.armed and not self.skip_next and self.rest_in_middle and period
              and t - self.armed_since > 1.5 * period):
            # Capteur de vitesse : un retour lent au repos (ou pas de retour, en fin de série)
            # ne se voit pas. Le geste a eu lieu : on le compte ; son retour, s'il se voit
            # plus tard, ne comptera pas une seconde fois.
            self.skip_next = True
            since = np.array(self.times) > self.cycles[-1]
            swing = float(self.signal[since].max() - self.signal[since].min())
            self.last_rep_peak = self.armed_since
            self.cycles = (self.cycles + [t])[-30:]
            self.cycle_swings = (self.cycle_swings + [swing])[-30:]
            return True
        elif self.armed and at_rest:
            self.armed = False
            if self.skip_next:
                # Fin de la répétition déjà comptée au démarrage du comptage : elle se
                # termine maintenant, au retour au repos
                self.skip_next = False
                self.cycles[-1] = t
                return False
            if self.cycles and t - self.cycles[-1] < MIN_PERIOD:
                return False
            since = np.array(self.times) > (self.cycles[-1] if self.cycles else t - self.max_period)
            swing = float(self.signal[since].max() - self.signal[since].min())
            self.last_rep_peak = self.armed_since
            self.cycles = (self.cycles + [t])[-30:]
            self.cycle_swings = (self.cycle_swings + [swing])[-30:]
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
        if min(p1, p2) < MIN_PERIOD or max(p1, p2) > self.max_period or max(p1, p2) / min(p1, p2) > 1.5:
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

    def forget_history(self):
        """Repart de zéro (téléphone manipulé : ce qui précède ne décrit pas l'exercice)."""
        self.times, self.rows, self.cycles = [], [], []
        self.cycle_swings = []
        self.signal = np.zeros(0)
        self.axis = None
        self.armed = False
        self.skip_next = False
        self.amplitude = 0.0

    def adopt_rest_position(self, series_start):
        """Au démarrage du comptage : la position tenue juste avant la série est le repos.

        Les cycles détectés jusque-là se terminaient peut-être à l'autre extrême (le signe de
        l'ACP est arbitraire) : une pompe était alors comptée en bas, à mi-chemin, et la
        dernière de la série jamais terminée. On bascule pour compter au retour au repos.
        `series_start` : premier cycle de la série ; la série commence au plus une période avant."""
        period = self.period()
        times = np.array(self.times)
        before = series_start - period
        held = self.signal[(times >= before - 1.0) & (times <= before - 0.1)]
        regular = self.signal[times >= self.cycles[-3] - period]
        low = percentile(regular, 0.05)
        amplitude = percentile(regular, 0.95) - low
        if len(held) < 5 or amplitude <= 0 or np.std(held) > 0.25 * amplitude:
            return   # pas de position tenue avant la série : on garde le sens actuel
        level = (float(np.median(held)) - low) / amplitude
        if 0.3 <= level <= 0.7:
            # Repos au milieu (capteur de vitesse : gyroscope, accélération) : pas d'extrême
            self.rest_in_middle = True
            return
        rest_high = level > 0.7
        if rest_high != self.rest_high:
            self.rest_high = rest_high
            # On vient de compter la répétition en cours (à son extrême) : on y est, et son
            # retour au repos ne doit pas compter une seconde fois
            self.armed = True
            self.skip_next = True

    def cycles_before_regular_run(self):
        """Répétitions faites avant que la série soit jugée régulière.

        Pendant la mise en place, l'axe de l'ACP et les seuils n'étaient pas encore justes :
        les premières répétitions ont pu être mal découpées ou manquées. On relit tout
        l'historique avec l'axe et les seuils de la série régulière, et on remonte les cycles
        qui lui ressemblent : même rythme, ampleur comparable (ni moitié moins, ni presque le
        double), tracé fluide. On s'arrête au premier qui ne ressemble pas (pause, secousses).
        Renvoie (nombre de cycles repris, instant du premier cycle de la série)."""
        period = self.period()
        run_start = self.cycles[-3]
        times = np.array(self.times)
        regular = self.signal[times >= run_start - period]
        low = percentile(regular, 0.05)
        amplitude = percentile(regular, 0.95) - low
        if amplitude <= 0:
            return 0, run_start
        events, high, previous = [], False, self.ignore_before
        for i, (value, time) in enumerate(zip(self.signal, times)):
            if time >= run_start - 0.5 * period:
                break
            if time < self.ignore_before:
                continue
            n = (value - low) / amplitude
            if not high and n > HIGH:
                high = True
            elif high and n < LOW:
                high = False
                # Le cycle : depuis le précédent, au plus 1,5 période (pas toute l'installation)
                cycle = self.signal[(times >= max(previous, time - 1.5 * period)) & (times <= time)]
                swing = float(cycle.max() - cycle.min())
                roughness = float(np.std(np.diff(cycle))) / amplitude if len(cycle) > 2 else math.inf
                events.append((time, swing, roughness))
                previous = time
        count, next_time = 0, run_start
        for time, swing, roughness in reversed(events):
            if (not 0.6 * period <= next_time - time <= 1.6 * period
                    or not 0.5 * amplitude <= swing <= 1.8 * amplitude
                    or roughness > MAX_ROUGHNESS):
                break
            count += 1
            next_time = time
        return count, next_time


class AutoCounter:
    """Les sources du profil suivies en parallèle ; la première avec 3 cycles réguliers mène."""

    def __init__(self, profile="auto"):
        self.profile = PROFILES[profile]
        self.trackers = {}
        self.leader = None
        self.count = 0
        self.last_count_time = -math.inf
        self.set_swings = []    # ampleur des répétitions de la série en cours
        self.set_times = []     # instants où elles ont été comptées
        self.weak_cycles = 0
        self.locks = []   # (instant, source, régularité) : pour comprendre les résultats

    def reset(self, time):
        """Remise à zéro : démarrage d'une séance ou série annulée. Ce qui précède est ignoré."""
        self.count = 0
        self.leader = None
        self.last_count_time = -math.inf
        for tracker in self.trackers.values():
            tracker.forget_cycles(time)

    def process(self, time, values):
        completed = set()
        sources = self.profile["sources"]
        # Téléphone posé (pompes) : s'il est manipulé, ce qui précède ne décrit pas l'exercice
        rotation = values.get("rotation")
        if self.profile.get("phone_at_rest") and rotation is not None and np.linalg.norm(rotation) > HANDLING_ROTATION:
            for tracker in self.trackers.values():
                tracker.forget_history()
        for source, value in values.items():
            if source not in sources:
                continue
            if source not in self.trackers:
                self.trackers[source] = SignalTracker(
                    source, MIN_AMPLITUDE[source], self.profile.get("max_period", MAX_PERIOD))
            if self.trackers[source].process(value, time):
                completed.add(source)

        if self.leader:
            tracker = self.trackers[self.leader]
            if self.leader in completed:
                # Un cycle bien plus faible que les répétitions de la série (essoufflement,
                # téléphone qu'on repose…) ne compte pas ; deux de suite : fin de série
                swing = tracker.cycle_swings[-1]
                usual = float(np.median(self.set_swings[-5:]))
                rhythm = (float(np.median(np.diff(self.set_times[-6:]))) if len(self.set_times) >= 2
                          else tracker.period())
                if (swing > STRONG_CYCLE_RATIO * usual and rhythm
                        and time - self.last_count_time > PAUSE_RATIO * rhythm):
                    # Téléphone repris en fin de série : ne compte pas, la série est finie
                    self.leader = None
                    return
                if swing >= WEAK_CYCLE_RATIO * usual:
                    self.count += 1
                    self.last_count_time = time
                    self.set_swings.append(swing)
                    self.set_times.append(time)
                    self.weak_cycles = 0
                else:
                    self.weak_cycles += 1
            if self.weak_cycles >= 2 or time - self.last_count_time > max(4, 3 * (tracker.period() or 2)):
                self.leader = None
            return

        best = None
        for source in sources:
            if source not in completed:
                continue
            score = self.trackers[source].regularity(time)
            if score >= MIN_REGULARITY and (best is None or round(score * 10) > round(best[1] * 10)):
                best = (source, score)
        if best:
            self.leader = best[0]
            tracker = self.trackers[best[0]]
            earlier, series_start = tracker.cycles_before_regular_run()
            self.count += 3 + earlier
            tracker.adopt_rest_position(series_start)
            self.last_count_time = time
            self.set_swings = self.trackers[best[0]].cycle_swings[-3:]
            self.set_times = [time]
            self.weak_cycles = 0
            self.locks.append((round(time, 1), best[0], round(best[1], 2)))


# --- Capteurs synthétiques ---------------------------------------------------------------------

def depth_reading(distance, coverage):
    """Moitié centrale de l'image vue par la caméra TrueDepth, téléphone au sol, au niveau de la tête.
    Le corps, à `distance` (m), couvre `coverage` de la zone ; ses parties s'étalent sur
    25 cm de profondeur. Sous 20 cm, TrueDepth ne mesure plus rien, et le plafond est hors
    de portée. Renvoie (distance moyenne des pixels mesurables ou None, part mesurable) :
    tout en bas d'une pompe, la moyenne *remonte* car seules les parties lointaines restent."""
    parts = distance + np.linspace(0, 0.25, 40)
    measurable = parts[parts >= 0.2]
    mean = measurable.mean() if len(measurable) else None
    return mean, coverage * len(measurable) / len(parts)


def synthetic_session(kind, segments, seed, pixel_count=192, fps=30):
    """Images (instant, {source: mesure}) pour une suite de segments :
    ("rep", durée, période), ("rest", durée), ("walk", durée) = téléphone manipulé,
    ("pant", durée) = essoufflement (respiration rapide et ample),
    ("setup", durée) = installation au-dessus du téléphone posé (pompes).
    kind : "pushup" (téléphone au sol), "abs" (sur la poitrine, grands abdos),
    "crunch" (sur la poitrine, petits abdos rapides : seules les épaules décollent),
    "squat" (à la main), "curl" (brassard sur l'avant-bras qui travaille)."""
    rng = np.random.default_rng(seed)
    pixel_base = rng.uniform(0.2, 0.8, pixel_count)
    frames, t = [], 0.0
    previous_angle = None
    last_depth = 2.0
    for segment in segments:
        kind_of_segment, duration = segment[0], segment[1]
        period = segment[2] if len(segment) > 2 else 1.0
        walking = kind_of_segment == "walk"
        for i in range(int(duration * fps)):
            t += 1 / fps
            tt = i / fps
            # m : 0 en position de départ, 1 au point le plus éloigné du mouvement
            m = 0.5 * (1 - math.cos(2 * math.pi * tt / period)) if kind_of_segment == "rep" else 0.0
            values = {}
            if kind == "pushup":
                # Téléphone au sol, au niveau de la tête : distance (pompe : 50 → 12 cm), part du champ
                # couverte par le corps, assombrissement de l'image, visage, téléphone immobile
                coverage = 1.0
                if walking:
                    distance, coverage = rng.uniform(0.3, 1.5), rng.uniform(0, 1)
                elif kind_of_segment == "setup":
                    # Arrivée lente et agitée au-dessus du téléphone
                    coverage = min(1.0, tt / 2)
                    distance = (1.0 - 0.5 * min(1.0, tt / 3) + 0.1 * math.sin(2 * math.pi * tt / 1.3)
                                + rng.normal(0, 0.02))
                else:
                    distance = 0.5 - 0.38 * m
                mean, measurable = depth_reading(distance, coverage)
                if mean is not None:
                    last_depth = mean
                values["depth"] = np.array([last_depth + rng.normal(0, 0.01), measurable + rng.normal(0, 0.02)])
                closeness = coverage * (1 - min(distance, 1.5) / 1.5)
                values["pixels"] = pixel_base * (1 - 0.7 * closeness) + rng.normal(0, 0.02, pixel_count)
                if 0.25 < distance < 0.8 and coverage > 0.5:
                    values["face"] = np.array([0.5, 0.5, 0.25 + 0.5 * closeness]) + rng.normal(0, 0.01, 3)
                angle = rng.uniform(0, 3) if walking else 0.0
                values["vertical"] = np.array([rng.normal(0, 0.5 if walking else 0.003)])
            elif kind == "squat":
                # Téléphone tenu à la main devant soi : il monte et descend de 40 cm sans
                # presque s'incliner ; seule l'accélération verticale voit bien le mouvement
                w = 2 * math.pi / period
                angle = rng.uniform(0, 3) if walking else math.radians(5 * m)
                vertical = -0.2 * w * w * math.cos(w * tt) / 9.81 if kind_of_segment == "rep" else 0.0
                values["vertical"] = np.array([vertical + rng.normal(0, 0.5 if walking else 0.02)])
            elif kind == "curl":
                # Téléphone dans un brassard sur l'avant-bras qui travaille : il pivote avec lui
                angle = rng.uniform(0, 3) if walking else math.radians(10 + 120 * m)
                values["vertical"] = np.array([rng.normal(0, 0.5 if walking else 0.03)])
            elif kind == "crunch":
                # Allongé, téléphone sur la poitrine : les épaules décollent de 6° en 0,9 période,
                # puis retour au sol ; respiration permanente, essoufflement possible
                move = 0.9 * period
                p = tt % period
                lift = 0.5 * (1 - math.cos(2 * math.pi * p / move)) if kind_of_segment == "rep" and p < move else 0.0
                breath = (2.0 * math.sin(2 * math.pi * t / 2.0) if kind_of_segment == "pant"
                          else 1.5 * math.sin(2 * math.pi * t / 4.0))
                angle = rng.uniform(0, 3) if walking else math.radians(5 + 6 * lift + breath)
                values["vertical"] = np.array([rng.normal(0, 0.5 if walking else 0.01)])
            else:
                # Téléphone contre la poitrine, grands abdos : inclinaison du buste + respiration
                angle = rng.uniform(0, 3) if walking else math.radians(20 + 60 * (1 - m))
                angle += 0.03 * math.sin(2 * math.pi * t / 4)
                values["vertical"] = np.array([rng.normal(0, 0.5 if walking else 0.02)])
            if kind != "pushup":
                # La caméra et la profondeur d'un téléphone porté ne voient que du bruit
                values["pixels"] = rng.uniform(0, 1, pixel_count) * 0.5 + 0.3
                values["depth"] = np.array([rng.uniform(0.3, 2), rng.uniform(0, 1)])
            # Gravité (inclinaison) et gyroscope (vitesse de rotation, rad/s)
            values["motion"] = np.array([0, -math.sin(angle), -math.cos(angle)]) + rng.normal(0, 0.005, 3)
            rate = 0.0 if previous_angle is None else (angle - previous_angle) * fps
            previous_angle = angle
            values["rotation"] = np.array([rate, 0, 0]) + rng.normal(0, 0.01, 3)
            frames.append((t, values))
    return frames


SCENARIOS = [
    # (nom, capteurs simulés, segments, répétitions attendues, profil d'exercice)
    ("Pompes 15, après 3 s de mise en place", "pushup",
     [("walk", 3), ("rest", 2), ("rep", 15 * 1.6, 1.6), ("rest", 2)], 15, "auto"),
    ("Pompes rapides 20 (1 s)", "pushup",
     [("rest", 2), ("rep", 20 * 1.0, 1.0), ("rest", 2)], 20, "auto"),
    ("Abdos 12, téléphone sur la poitrine, après manipulation", "abs",
     [("walk", 3), ("rest", 3), ("rep", 12 * 2.5, 2.5), ("rest", 2)], 12, "auto"),
    ("Abdos lents 8 (4 s par rep)", "abs",
     [("rest", 3), ("rep", 8 * 4, 4.0), ("rest", 2)], 8, "auto"),
    ("Squats 10, téléphone tenu à la main", "squat",
     [("walk", 3), ("rest", 2), ("rep", 10 * 2.5, 2.5), ("rest", 3)], 10, "auto"),
    ("Squats rapides 12 (1,8 s)", "squat",
     [("rest", 2), ("rep", 12 * 1.8, 1.8), ("rest", 3)], 12, "auto"),
    ("2 séries de pompes : 10 + pause 15 s + 8", "pushup",
     [("rest", 2), ("rep", 10 * 1.6, 1.6), ("rest", 15), ("rep", 8 * 1.6, 1.6), ("rest", 2)], 18, "auto"),
    ("Téléphone posé, personne, 60 s", "pushup", [("rest", 60)], 0, "auto"),
    ("Allongé immobile en respirant, téléphone sur la poitrine, 60 s", "abs", [("rest", 60)], 0, "auto"),
    ("Téléphone manipulé, 20 s", "abs", [("walk", 20)], 0, "auto"),
    ("Debout immobile, téléphone à la main, 60 s", "squat", [("rest", 60)], 0, "auto"),
    # Profils choisis par l'utilisateur
    ("[Pompes] 15 pompes", "pushup",
     [("walk", 3), ("rest", 2), ("rep", 15 * 1.6, 1.6), ("rest", 2)], 15, "pushups"),
    ("[Pompes] installation lente et agitée, puis 10 pompes", "pushup",
     [("walk", 2), ("setup", 4), ("rep", 10 * 1.6, 1.6), ("rest", 3)], 10, "pushups"),
    ("[Pompes] installation, puis 12 pompes rapides (1 s)", "pushup",
     [("walk", 2), ("setup", 4), ("rep", 12 * 1.0, 1.0), ("rest", 3)], 12, "pushups"),
    ("[Abdos] 15 petits abdos rapides (6°, 1,2 s) puis essoufflement 20 s", "crunch",
     [("walk", 3), ("rest", 3), ("rep", 15 * 1.2, 1.2), ("pant", 20)], 15, "crunches"),
    ("[Abdos] 20 petits abdos très rapides (6°, 0,9 s)", "crunch",
     [("rest", 3), ("rep", 20 * 0.9, 0.9), ("rest", 4)], 20, "crunches"),
    ("[Abdos] 2 séries de 10 avec 20 s de repos allongé", "crunch",
     [("rest", 3), ("rep", 12, 1.2), ("pant", 20), ("rep", 12, 1.2), ("rest", 4)], 20, "crunches"),
    ("[Abdos] allongé, respiration puis essoufflement, 60 s", "crunch",
     [("rest", 30), ("pant", 30)], 0, "crunches"),
    ("[Squats] 10 squats, téléphone à la main", "squat",
     [("walk", 3), ("rest", 2), ("rep", 10 * 2.5, 2.5), ("rest", 3)], 10, "squats"),
    ("[Biceps] 12 flexions, téléphone en brassard sur l'avant-bras", "curl",
     [("walk", 3), ("rest", 2), ("rep", 12 * 2.0, 2.0), ("rest", 3)], 12, "curls"),
]


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--seeds", type=int, default=5, help="nombre de tirages aléatoires par scénario")
    args = parser.parse_args()

    failures = exact_runs = 0
    for name, kind, segments, expected, profile in SCENARIOS:
        counts, sources = [], set()
        for seed in range(1, args.seeds + 1):
            counter = AutoCounter(profile)
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

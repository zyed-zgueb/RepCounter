#!/usr/bin/env python3
"""Phases d'entraînement : miroir Python de RepCounter/Phase.swift, et sa validation sur des
historiques synthétiques.

Usage : python3 Simulation/phases.py        (tous les scénarios ; code de sortie 1 si un échoue)
        python3 Simulation/phases.py -v     (la phase jour par jour)

Bases (voir README, section Phases) :
- Meeusen et al. 2013, consensus ECSS / ACSM (Med Sci Sports Exerc 45(1):186–205) : une baisse
  de performance après un entraînement intensifié est une surcharge fonctionnelle si elle se
  résorbe en jours ou semaines, suivie d'un rebond (surcompensation) ; non fonctionnelle si elle
  dure des semaines à des mois. Seule la durée de la baisse les distingue, après coup.
- Bell et al. 2023, consensus Delphi (Sports Med Open 9:87) : la décharge est une période de
  stress d'entraînement réduit (volume en baisse) pour résorber la fatigue.
  Rogerson et al. 2024 (Sports Med Open, 246 athlètes de force) : décharges de 6,4 ± 1,7 jours.
- Foster et al. 2001 (J Strength Cond Res 15(1):109–115) : charge de séance = effort (CR-10)
  × durée (min).
- Hopkins 2000 (Sports Med 30(1):1–15) : une mesure isolée hors de la variation habituelle peut
  être du bruit ; d'où deux séances de suite sous la bande avant de parler de baisse.

Seuils provisoires (valeurs de l'app, à remplacer par celles des références quand le texte
intégral aura été vérifié) : `FOR_DAYS`, `REBOUND_DAYS`, `MIN_SESSIONS`, `MIN_DAYS`.
"""

import math
import random
import sys
from dataclasses import dataclass, field

# --- Forme (miroir de FormResult dans Form.swift) -------------------------------------------

BASELINE_SESSIONS = 3
REFERENCE_WINDOW = 10


def median(values):
    s = sorted(values)
    n = len(s)
    if n == 0:
        return None
    return s[n // 2] if n % 2 else (s[n // 2 - 1] + s[n // 2]) / 2


def form_result(measure, previous):
    """measure = (pace, slowdown) ; previous = mesures d'avant, avec leur zone (None tant que la
    référence n'est pas établie). Renvoie (percent, zone, band) ou None.
    La référence ne retient que les séances qui n'étaient pas fatiguées : une baisse qui dure
    reste visible au lieu de devenir la nouvelle norme."""
    reference = [m for m, zone in previous if zone != "tired"][-REFERENCE_WINDOW:]
    if len(reference) < BASELINE_SESSIONS:
        return None
    pace = median([m[0] for m in reference])
    slowdown = median([m[1] for m in reference])

    def form(m):
        return 100 * math.sqrt((pace / m[0]) * (slowdown / m[1]))

    # Variation normale : toutes les séances récentes (les fatiguées comprises)
    past = [form(m) for m, _ in previous[-REFERENCE_WINDOW:]]
    mean = sum(past) / len(past)
    deviation = math.sqrt(sum((p - mean) ** 2 for p in past) / len(past))
    band = max(3, 1.5 * deviation)
    percent = form(measure)
    zone = "tired" if percent < 100 - band else ("fresh" if percent > 100 + band else "normal")
    return percent, zone, band


# --- Phases ---------------------------------------------------------------------------------

# Durée d'une baisse au-delà de laquelle elle n'est plus de la surcharge fonctionnelle
# (Meeusen 2013 : « jours à semaines » ; provisoire : 2 semaines).
FOR_DAYS = 14
# Décharge : une semaine (Rogerson 2024 : 6,4 ± 1,7 jours).
DELOAD_DAYS = 7
# Rebond : la surcompensation suit la récupération (Meeusen 2013) ; une séance en forme ou un
# record dans les 14 jours qui suivent la fin d'une baisse ou d'une décharge (provisoire).
REBOUND_DAYS = 14
# Confiance : 8 séances mesurables sur 4 semaines au moins (provisoire, feuille de route).
MIN_SESSIONS = 8
MIN_DAYS = 28
# Pause : 7 jours sans aucune séance réduisent le stress d'entraînement : c'est une décharge
# au sens de Bell 2023.
BREAK_DAYS = 7


@dataclass
class Session:
    day: int                      # jour (0 = premier jour de l'historique)
    exercise: str = "pushups"
    minutes: float = 15
    effort: int = None            # CR-10 (0–10), facultatif
    measure: tuple = None         # (pace, slowdown) si mesurable
    record: bool = False          # meilleure série jamais faite
    fatigue: int = None           # avant la séance, 1–5 (5 = très fatigué), facultatif


@dataclass
class Phase:
    kind: str                     # building, overreaching, lowForm, comeback, deloadAdvised,
                                  # deload, rest, rebound, persistentFatigue, pending
    since: int = None             # jour de début (baisse, décharge)
    progress: int = 0             # pending : séances mesurables
    felt: bool = False            # building : fatigue ressentie, pas encore mesurée


def session_load(s, usual_effort):
    """Charge de séance (Foster 2001) ; sans réponse, l'effort habituel de la personne."""
    effort = s.effort if s.effort is not None else usual_effort
    return effort * s.minutes


def usual_effort(sessions):
    answered = [s.effort for s in sessions if s.effort is not None]
    return median(answered) if answered else 1


def weekly_load(sessions, end_day, effort):
    """Charge des 7 jours qui finissent la veille de `end_day` (toutes les séances, tous exercices)."""
    return sum(session_load(s, effort) for s in sessions if end_day - 7 <= s.day < end_day)


def intensified(sessions, day, effort):
    """Entraînement intensifié avant `day` (Meeusen 2013 : la surcharge suit un entraînement
    intensifié) : les 7 jours d'avant (ou les 7 d'avant encore) plus chargés que chacune des
    4 semaines qui les précèdent."""
    for end in (day, day - 7):
        week = weekly_load(sessions, end, effort)
        previous = [weekly_load(sessions, end - 7 * k, effort) for k in range(1, 5)]
        if week > max(previous) > 0:
            return True
    return False


def deloads(all_sessions, deload_starts, today):
    """Périodes de stress réduit (début, fin exclue, pause ?) : décharges déclarées, et pauses
    (plus de 7 jours sans aucune séance)."""
    periods = [(d, d + DELOAD_DAYS, False) for d in deload_starts if d <= today]
    days = sorted({s.day for s in all_sessions if s.day <= today})
    for a, b in zip(days, days[1:]):
        if b - a > BREAK_DAYS:
            periods.append((a + 1, b, True))
    if days and today - days[-1] > BREAK_DAYS:
        periods.append((days[-1] + 1, today + 1, True))
    return sorted(periods)


def phase(all_sessions, exercise, today, deload_starts=()):
    """La phase d'un exercice au jour `today`, de tout l'historique jusqu'à ce jour."""
    sessions = [s for s in all_sessions if s.day <= today]
    mine = [s for s in sessions if s.exercise == exercise]
    effort = usual_effort(sessions)

    measured = []          # (session, zone, percent)
    measures = []
    for s in mine:
        if s.measure is None:
            continue
        r = form_result(s.measure, measures)
        measures.append((s.measure, r[1] if r else None))
        if r is not None:
            measured.append((s, r[1], r[0]))

    measurable = [s for s in mine if s.measure is not None]
    if len(measurable) < MIN_SESSIONS or not measurable or today - measurable[0].day < MIN_DAYS or not measured:
        return Phase("pending", progress=min(len(measurable), MIN_SESSIONS))

    periods = deloads(sessions, deload_starts, today)
    current = next(((a, b, pause) for a, b, pause in periods if a <= today < b), None)

    def reduced(current):
        return Phase("rest" if current[2] else "deload", since=current[0])

    # Baisse en cours : les séances fatiguées de suite, jusqu'à la dernière
    streak = []
    for s, zone, _ in reversed(measured):
        if zone != "tired":
            break
        streak.insert(0, s)

    if len(streak) >= 2:
        start = streak[0].day
        ended = [b for a, b, pause in periods if a >= start and b <= today]
        if ended and streak[-1].day >= ended[-1]:
            return Phase("persistentFatigue", since=start)
        if current is not None:
            return reduced(current)
        # Reprise : la baisse commence peu après une pause (désentraînement, pas surcharge)
        if any(pause and 0 <= start - b <= FOR_DAYS for a, b, pause in periods):
            return Phase("comeback", since=start)
        if today - start >= FOR_DAYS:
            return Phase("deloadAdvised", since=start)
        if intensified(sessions, start, effort):
            return Phase("overreaching", since=start)
        return Phase("lowForm", since=start)

    if current is not None:
        return reduced(current)

    # Rebond (Meeusen 2013) : après une surcharge (baisse qui suit un entraînement intensifié)
    # ou une décharge déclarée, la première séance revenue au moins à la référence, ou un
    # record, dans les 14 jours : la surcompensation. Une fois par épisode.
    last, zone, percent = measured[-1]
    ends = [b for a, b, pause in periods if not pause and b <= today]
    for i in range(1, len(measured)):
        s, z, _ = measured[i]
        before = measured[i - 1]
        if z != "tired" and before[1] == "tired" and i >= 2 and measured[i - 2][1] == "tired":
            k = i - 1
            while k > 0 and measured[k - 1][1] == "tired":
                k -= 1
            if intensified(sessions, measured[k][0].day, effort):
                ends.append(measured[i - 1][0].day + 1)
    for end in ends:
        after = [(s, p) for s, _, p in measured if end <= s.day <= end + REBOUND_DAYS]
        first = next((s for s, p in after if p >= 100 or s.record), None)
        if first is not None and first is last:
            return Phase("rebound", since=last.day)

    # Ressenti × mesure (Saw et al. 2016) : fatigué ressenti, Forme normale
    felt = last.fatigue is not None and last.fatigue >= 4 and zone != "tired"
    return Phase("building", felt=felt)


# --- Historiques synthétiques ---------------------------------------------------------------

PACE, SLOWDOWN = 2.0, 1.15
TRAINING_DAYS = (0, 2, 4)     # lundi, mercredi, vendredi


def measure(condition, rng, noise=0.02):
    """Une séance d'une personne dont la condition vaut `condition` (1 = habituelle) : la Forme
    vaut à peu près 100 × condition."""
    pace = PACE / condition * (1 + rng.gauss(0, noise))
    slowdown = SLOWDOWN / condition * (1 + rng.gauss(0, noise))
    return (pace, slowdown)


def schedule(weeks, condition, load=lambda d: 1.0, skip=lambda d: False, seed=1, effort=5):
    rng = random.Random(seed)
    out = []
    for week in range(weeks):
        for wd in TRAINING_DAYS:
            day = week * 7 + wd
            if skip(day):
                continue
            out.append(Session(day=day, minutes=15 * load(day), effort=effort,
                               measure=measure(condition(day), rng)))
    return out


def ramp(day, start, end, a, b):
    if day <= start:
        return a
    if day >= end:
        return b
    return a + (b - a) * (day - start) / (end - start)


@dataclass
class Scenario:
    name: str
    sessions: list
    expected: dict                # jour → phase attendue (premier jour d'une phase)
    deload_starts: list = field(default_factory=list)
    forbidden: tuple = ()         # phases qui ne doivent jamais apparaître


def regular(seed):
    return Scenario(f"progression régulière (graine {seed})",
                    schedule(12, lambda d: 1 + 0.001 * d, seed=seed), {},
                    forbidden=("persistentFatigue", "deloadAdvised", "overreaching"))


def overreach_rebound():
    # 5 semaines normales ; semaines 6-7 : volume +50 %, la condition baisse à 0,90 ;
    # la personne suit le conseil et décharge une semaine ; puis rebond à 1,06.
    deload = 51
    def condition(d):
        if d < 35:
            return 1.0
        if d < deload:
            return ramp(d, 35, 46, 1.0, 0.90)
        if d < deload + 7:
            return ramp(d, deload, deload + 7, 0.90, 1.0)
        return 1.06
    sessions = schedule(10, condition, load=lambda d: 1.5 if 35 <= d < deload else (0.4 if deload <= d < deload + 7 else 1.0),
                        skip=lambda d: deload <= d < deload + 7 and d % 7 != 2)
    # Vérité : la condition passe sous la variation normale (-3 %) vers le jour 39 ; la baisse
    # est établie à la 2e séance sous la bande (Hopkins : une seule ne suffit pas), lundi 42.
    # Décharge déclarée le jeudi 51 ; première séance après, lundi 58.
    return Scenario("surcharge, décharge, rebond", sessions,
                    {42: "overreaching", 51: "deload", 58: "rebound"}, deload_starts=[deload],
                    forbidden=("persistentFatigue",))


def overreach_no_rebound():
    deload = 51
    def condition(d):
        if d < 35:
            return 1.0
        return ramp(d, 35, 46, 1.0, 0.90)
    sessions = schedule(10, condition, load=lambda d: 1.5 if 35 <= d < deload else (0.4 if deload <= d < deload + 7 else 1.0),
                        skip=lambda d: deload <= d < deload + 7 and d % 7 != 2)
    return Scenario("surcharge sans rebond", sessions,
                    {42: "overreaching", 51: "deload", 58: "persistentFatigue"}, deload_starts=[deload])


def advised():
    # Même surcharge, sans décharge : le conseil arrive 2 semaines après le début de la baisse.
    def condition(d):
        return 1.0 if d < 35 else ramp(d, 35, 46, 1.0, 0.90)
    sessions = schedule(9, condition, load=lambda d: 1.5 if d >= 35 else 1.0)
    return Scenario("surcharge qui dure : décharge conseillée", sessions,
                    {42: "overreaching", 53: "deloadAdvised"})


def comeback():
    # 6 semaines normales, 3 semaines d'arrêt, reprise un peu en dessous (désentraînement).
    def condition(d):
        return 1.0 if d < 42 else ramp(d, 63, 77, 0.92, 1.0)
    sessions = schedule(13, condition, skip=lambda d: 42 <= d < 63)
    return Scenario("reprise après 3 semaines d'arrêt", sessions, {47: "rest", 65: "comeback"},
                    forbidden=("overreaching", "persistentFatigue", "deloadAdvised"))


def dip():
    # Charge inchangée, un passage à vide d'une semaine (sommeil, maladie) : forme basse, pas
    # surcharge (rien n'a été intensifié), puis retour à la normale sans rebond.
    def condition(d):
        return 0.91 if 49 <= d < 56 else 1.0
    return Scenario("passage à vide sans surcharge", schedule(10, condition), {51: "lowForm", 56: "building"},
                    forbidden=("overreaching", "deloadAdvised", "persistentFatigue"))


def noisy(seed):
    # Mesure plus bruitée (4 %) : aucune fausse alerte attendue
    rng = random.Random(seed)
    sessions = [Session(day=w * 7 + d, effort=5, measure=measure(1.0, rng, noise=0.04))
                for w in range(12) for d in TRAINING_DAYS]
    return Scenario(f"mesure bruitée (graine {seed})", sessions, {},
                    forbidden=("persistentFatigue", "deloadAdvised"))


def run(scenario, verbose=False):
    last_day = max(s.day for s in scenario.sessions) + 1
    timeline = []
    previous = None
    for day in range(last_day):
        p = phase(scenario.sessions, "pushups", day, scenario.deload_starts)
        timeline.append(p.kind)
        if verbose and p.kind != previous:
            print(f"    jour {day:3d} : {p.kind}")
        previous = p.kind
    errors = []
    for day, kind in scenario.expected.items():
        window = range(max(0, day - 2), min(last_day, day + 3))
        first = next((d for d in range(last_day) if timeline[d] == kind and (d == 0 or timeline[d - 1] != kind)
                      and abs(d - day) <= 2), None)
        if first is None:
            near = [f"{d}:{timeline[d]}" for d in window]
            errors.append(f"« {kind} » attendu le jour {day} (±2) ; trouvé {', '.join(near)}")
    for kind in scenario.forbidden:
        days = [d for d, k in enumerate(timeline) if k == kind]
        if days:
            errors.append(f"« {kind} » ne doit pas apparaître (jours {days[:5]}…)")
    return errors


def main():
    verbose = "-v" in sys.argv
    scenarios = [overreach_rebound(), overreach_no_rebound(), advised(), comeback(), dip()]
    scenarios += [noisy(seed) for seed in range(1, 21)]
    scenarios += [regular(seed) for seed in range(1, 21)]
    failed = 0
    for sc in scenarios:
        if verbose:
            print(sc.name)
        errors = run(sc, verbose)
        if errors:
            failed += 1
            print(f"ÉCHEC {sc.name}")
            for e in errors:
                print(f"    {e}")
        elif not verbose:
            print(f"ok    {sc.name}")
    print(f"\n{len(scenarios) - failed}/{len(scenarios)} scénarios réussis")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())

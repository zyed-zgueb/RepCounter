#!/usr/bin/env python3
"""Plan d'entraînement : miroir Python de RepCounter/Plan.swift et Prescription.swift, et sa
validation sur des historiques synthétiques.

Usage : python3 Simulation/plan.py      (code de sortie 1 si un scénario échoue)

Un bloc : 3 semaines de progression, 1 semaine allégée, puis un test (le lundi qui suit la
semaine allégée). Une semaine de progression finie avec moins de 2 séances, ou deux séances en
Forme basse, est refaite (deux fois au plus par bloc) : le test et la date de l'objectif reculent
d'autant.
Séance prévue (ACSM 2026, Currier et al. : au moins 2 séances par semaine, 2–3 séries, 2–3
répétitions en réserve) : 3 séries enchaînées avec le repos habituel ; série 1 = max − 3 (le max
étant le dernier test, sinon la meilleure série des 4 semaines avant le bloc) ; séries 2 et 3 =
série 1 × la baisse habituelle (rapports médians série k / série 1, séances à ± 30 s du repos
prévu, au moins 3), sinon 80 % de la précédente (choix de l'app). En séance, une série sous sa
cible réajuste la suivante (faite × rapport), sans rattrapage ; une nouvelle séance le même jour
(séries espacées) repart de la série 1. Pas de hausse hebdomadaire ; allégée et légère : la
moitié des séries, arrondie au-dessus (choix de l'app).
Pas de jours prévus (Science/METHODE-JOURS.md, décision de Vincent) : chaque jour, une séance est
proposée, sauf repos conseillé la veille du test, en fatigue persistante, le lendemain d'une
séance « Très difficile » (effort ≥ 7), ou après 20 séries sur les 7 derniers jours.
Jours comptés depuis un lundi (jour 0 = lundi de la semaine où l'objectif est fixé).
"""

import sys
from dataclasses import dataclass, field
from statistics import median

PROGRESSION_WEEKS, MAX_REPEATS, HABIT_DAYS = 3, 2, 28
SETS, RESERVE, MIN_PER_WEEK = 3, 3, 2
DEFAULT_STEP, RATIO_SESSIONS, REST_TOLERANCE = 0.8, 3, 30
HARD_EFFORT, WEEKLY_SET_CAP = 7, 20   # METHODE-JOURS.md, règle 3 (c) et (d)


@dataclass
class Session:
    day: float
    sets: list
    tired: bool = False
    rests: list = None    # repos avant les séries 2, 3… (s)
    roles: list = None    # None (normale), "warmup" (échauffement) ou "test", série par série
    targets: list = None  # la cible de chaque série (None sans plan)
    effort: int = None    # « Effort ? » de fin de séance, 0–10 (None sans réponse)

    def __post_init__(self):
        if self.rests is None:
            self.rests = [60] * (len(self.sets) - 1)
        if self.roles is None:
            self.roles = [None] * len(self.sets)
        if self.targets is None:
            self.targets = [None] * len(self.sets)

    @property
    def test_best(self):
        """Le résultat d'un test : la meilleure série faite en mode test (None sans test)."""
        values = [r for r, role in zip(self.sets, self.roles) if role == "test" and r > 0]
        return max(values) if values else None

    @property
    def is_test(self):
        return "test" in self.roles

    @property
    def work_sets(self):
        """Séries faites, échauffement exclu."""
        return sum(1 for r, role in zip(self.sets, self.roles) if r > 0 and role != "warmup")

    @property
    def total(self):
        return sum(self.sets)

    @property
    def best(self):
        return max(self.sets)


def rnd(x):
    return int(x + 0.5)   # arrondi au plus proche, comme Swift .rounded()


def targets(first, ratios):
    return [max(1, rnd(first * (ratios[k] if ratios else DEFAULT_STEP ** k))) for k in range(SETS)]


def step(k, ratios):
    if not ratios or k <= 0 or k >= len(ratios) or ratios[k - 1] <= 0:
        return DEFAULT_STEP
    return ratios[k] / ratios[k - 1]


def ratios_of(sessions, rest):
    eligible = [s for s in sessions if len(s.sets) >= SETS and s.sets[0] > 0
                and all(abs(s.rests[k - 1] - rest) <= REST_TOLERANCE for k in range(1, SETS))]
    if len(eligible) < RATIO_SESSIONS:
        return None
    return [1.0] + [median(s.sets[k] / s.sets[0] for s in eligible) for k in range(1, SETS)]


def next_target(session, ratios, day_done, session_done):
    k = len(day_done)
    if k >= len(session[0]):
        return None
    if not session_done:
        return session[0][0]
    adjusted = max(1, rnd(session_done[-1] * step(k, ratios)))
    return min(session[0][k], adjusted)


def habitual(sessions, before, test_max=None):
    recent = [s for s in sessions if before - HABIT_DAYS <= s.day < before]
    if not recent:
        return None
    best = max(s.best for s in recent)
    rests = [r for s in recent for r in s.rests]
    rest = median(rests) if len(rests) >= 3 else 60
    rest = min(max(rnd(rest / 15) * 15, 30), 300)
    ratios = ratios_of(recent, rest)
    return (targets(max(1, (test_max or best) - RESERVE), ratios), rest), ratios


def lighter(session):
    return (session[0][:max(1, (len(session[0]) + 1) // 2)], session[1])


def training_days(sessions):
    return len({int(s.day) for s in sessions})


def rest_reason(sessions, day, test_day=None):
    """Le repos conseillé le jour `day` (METHODE-JOURS.md, règle 3), d'après les séances d'avant ce
    jour ; None : séance. La fatigue persistante, connue pour aujourd'hui seulement, est à part."""
    if test_day is not None and day + 1 == int(test_day):
        return "before_test"
    if any(int(s.day) == day - 1 and (s.effort or 0) >= HARD_EFFORT for s in sessions):
        return "hard_yesterday"
    if sum(s.work_sets for s in sessions if day - 7 <= s.day < day) >= WEEKLY_SET_CAP:
        return "weekly_volume"
    return None


def next_day(sessions, now, test_day=None):
    """La prochaine séance après aujourd'hui : le premier jour sans repos conseillé."""
    for d in range(int(now) + 1, int(now) + 8):
        if rest_reason(sessions, d, test_day) is None:
            return d
    return int(now) + 1


COMEBACK_DAYS = 28   # choix de l'app : au-delà, le plan repart de zéro (nouveau bloc 1)
REPRISE_DAYS = 7     # choix de l'app : au-delà, une semaine de reprise avant le test (Bell 2023)


def test_session(day, warmup=None, attempts=(30,)):
    """Une séance faite en mode test : un échauffement facultatif, puis les tentatives."""
    sets = ([warmup] if warmup is not None else []) + list(attempts)
    roles = (["warmup"] if warmup is not None else []) + ["test"] * len(attempts)
    return Session(day, sets, roles=roles)


def make(goal_day, sessions, now, low_form=False, persistent_fatigue=False, legacy_before=None):
    """Miroir de TrainingPlan.make : test annoncé (Science/METHODE-TEST.md). `legacy_before` : les
    séances plus anciennes, sans rôle de série, gardent l'ancienne règle du test."""
    sessions = sorted([s for s in sessions if s.day <= now], key=lambda s: s.day)
    if not sessions:
        return None
    last = sessions[-1]
    # Plus de 28 jours sans séance : une séance de reprise libre
    if now - last.day > COMEBACK_DAYS:
        return dict(block=1, weeks=[], test_day=now, tests=[], shift=0, today=("comeback", None),
                    status="due", next=None, ratios=None, missed_tests=[])
    # Une séance après plus de 28 jours sans séance ouvre un nouveau bloc 1, ancré sur elle
    anchor = goal_day
    comeback = None
    for before, after in zip(sessions, sessions[1:]):
        if after.day - before.day > COMEBACK_DAYS:
            anchor = max(anchor, after.day)
            comeback = after.day
    usable = [s for s in sessions if comeback is None or s.day >= comeback]
    first_day = int(anchor)
    block_start = (int(anchor) // 7) * 7

    def required(week_start):
        # Au moins 2 séances par semaine (ACSM 2026) ; une seule la semaine où le plan commence
        # en cours de semaine (choix de l'app : la semaine n'est pas entière)
        return MIN_PER_WEEK if week_start >= first_day else 1

    def today_of(today, test_day):
        """Le statut du jour et le repos conseillé (METHODE-JOURS.md)."""
        today_sessions = [s for s in sessions if int(s.day) == int(now)]
        planned_today = sum(today[1][0]) if today[1] else 1
        # Un jour de test, seule la fatigue persistante conseille un repos
        reason = ("persistent_fatigue" if persistent_fatigue
                  else None if today[0] == "test" else rest_reason(sessions, int(now), test_day))
        if today[0] == "test" and any(s.test_best for s in today_sessions):
            status = "done"
        elif today[0] != "test" and today_sessions:
            # Une séance terminée est faite, cible atteinte ou non (décision de Vincent)
            status = "done"
        elif today_sessions or reason is None:
            status = "due"
        else:
            status = "rest"
        recent = {int(s.day) for s in sessions if int(now) - 6 <= s.day < int(now) + 1}
        below = status == "due" and int(now) - first_day >= 7 and len(recent) < MIN_PER_WEEK
        missed = (status == "done" and today[0] != "test"
                  and sum(s.total for s in today_sessions) < planned_today)
        return dict(status=status, rest_reason=reason if status == "rest" else None,
                    next=next_day(sessions, now, test_day), below_minimum=below, target_missed=missed)

    def waiting_weeks(test_day, day):
        late = int(day) - int(test_day)
        return -(-late // 7) if late > 0 else 0

    block, tests, missed_tests, shift, excluded = 1, [], [], 0, set()
    base_max = None
    while True:
        # Bloc 1 : 2 tests sur 2 jours de la première semaine, le meilleur sert de départ
        calibration_days = 0
        kept_days = []
        if block == 1:
            calibration = [s for s in sessions if block_start <= s.day < block_start + 7 and s.test_best]
            kept_days = sorted({int(s.day) for s in calibration})[:2]
            kept = [s for s in calibration if int(s.day) in kept_days]
            calibration_days = len(kept_days)
            excluded |= {id(s) for s in kept}
            if kept:
                best = max(s.test_best for s in kept)
                tests.append((kept[0].day, best, 0))
                base_max = best
        reference = [s for s in usable if id(s) not in excluded]
        h = (habitual(reference, block_start, base_max)
             or habitual(reference, min(now + 1e-6, block_start + 7), base_max)
             or habitual(reference, now + 1e-6, base_max))
        if h is None:
            return None
        habit, ratios = h
        current_max = base_max if base_max is not None else habit[0][0] + RESERVE
        last_raise = None

        def session_for(m):
            return (targets(max(1, m - RESERVE), ratios), habit[1])

        weeks, start, progression, repeats, redo = [], block_start, 0, 0, False
        while progression < PROGRESSION_WEEKS:
            done = [s for s in sessions if start <= s.day < start + 7]
            past = start + 7 <= now
            reason = None
            if past and repeats < MAX_REPEATS:
                count = training_days(done)
                tired = sum(s.tired for s in done)
                if count < required(start):
                    reason = f"{count} séance(s)"
                elif tired >= 2:
                    reason = f"Forme basse × {tired}"
            weeks.append((f"P{progression + 1}{' bis' if redo else ''}", start, past, start <= now < start + 7,
                          training_days(done), reason))
            # Le max relevé en cours de bloc : une série (ou un test) qui le dépasse ; nouveau max =
            # les répétitions faites (un seul relèvement par séance, échauffement exclu)
            for x in sorted(done, key=lambda x: x.day):
                if x.test_best:
                    excluded.add(id(x))
                    if x.test_best > current_max:
                        current_max = last_raise = x.test_best
                    continue
                best = max([r for r, role in zip(x.sets, x.roles) if role != "warmup"], default=0)
                if best > current_max:
                    current_max = last_raise = best
            start += 7
            if reason:
                repeats += 1
                shift += 1
                redo = True
            else:
                progression += 1
                redo = False
        session_now = session_for(current_max)
        deload = lighter(session_now)
        deload_start = start
        deload_done = [s for s in sessions if deload_start <= s.day < deload_start + 7]
        weeks.append(("Allégée", deload_start, deload_start + 7 <= now, deload_start <= now < deload_start + 7,
                      training_days(deload_done), None))
        # Jour de test : le lundi qui suit la semaine allégée (METHODE-JOURS.md, règle 7)
        test_day = deload_start + 7
        def closing(x):
            # Le test annoncé, ou (séance d'avant la mise à jour, sans rôle) l'ancienne règle
            if x.test_best:
                return x.test_best
            if (legacy_before is not None and x.day < legacy_before and x.day >= deload_start + 7
                    and all(role is None for role in x.roles)):
                return next((r for r in x.sets if r > 0), None)
            return None

        # Un test lancé dès la semaine allégée compte et clôt le bloc
        first_test = next((s for s in sessions if s.day >= deload_start and id(s) not in excluded and closing(s)), None)
        excluded |= {id(s) for s in deload_done if not s.test_best}
        reprise_today = False
        candidate = next((s for s in sessions if s.day >= test_day), None)
        previous = [s for s in sessions if candidate is not None and s.day < candidate.day]
        if (candidate is not None and candidate is not first_test
                and (first_test is None or first_test.day > candidate.day)
                and previous and candidate.day - previous[-1].day > REPRISE_DAYS):
            reprise_start = (int(candidate.day) // 7) * 7
            reprise_done = [s for s in sessions if reprise_start <= s.day < reprise_start + 7 and not s.test_best]
            excluded |= {id(s) for s in reprise_done}
            weeks.append(("Reprise", reprise_start, reprise_start + 7 <= now, reprise_start <= now < reprise_start + 7,
                          training_days(reprise_done), None))
            test_day = reprise_start + 7
        elif first_test is None and now >= test_day and now - last.day > REPRISE_DAYS:
            # Plus de 7 jours sans séance, même pendant l'attente du test : la reprise prime
            reprise_today = True
            reprise_start = (int(now) // 7) * 7
            weeks.append(("Reprise", reprise_start, False, True, 0, None))
            test_day = reprise_start + 7
        # En attendant le test : séances comptées, mais ni test ni séance habituelle
        waiting_end = first_test.day if first_test else min(now + 1, test_day + REPRISE_DAYS)
        excluded |= {id(s) for s in sessions if test_day <= s.day < waiting_end and not s.test_best}

        if first_test is not None:
            nxt_block = (int(first_test.day) // 7) * 7 + 7
            window = [s for s in sessions if first_test.day <= s.day < nxt_block and closing(s)]
            excluded |= {id(s) for s in window}
            value = max(closing(s) for s in window)
            tests.append((first_test.day, value, block))
            shift += waiting_weeks(test_day, first_test.day)
            base_max = value
            block_start = nxt_block
            block += 1
            if block_start <= now:
                continue
            reference = [x for x in usable if id(x) not in excluded]
            fresh = habitual(reference, now + 1, test_max=value)
            # Test fait : jusqu'au bloc suivant (lundi), la séance de son nouveau max, au jour le jour
            today = ("session", fresh[0] if fresh else habit)
            return dict(block=block - 1, weeks=weeks, test_day=test_day, tests=[t[:2] for t in tests], shift=shift,
                        today=today, ratios=ratios, missed_tests=missed_tests, current_max=value,
                        **today_of(today, None))
        # Test pas lancé 7 jours après le jour prévu, en s'entraînant : bloc suivant sur le dernier max
        give_up = test_day + REPRISE_DAYS
        if not reprise_today and now >= give_up:
            missed_tests.append(test_day)
            shift += 1
            monday = (give_up // 7) * 7
            block_start = give_up if monday == give_up else monday + 7
            base_max = current_max
            block += 1
            if block_start <= now:
                continue
            today = ("session", session_now)
            return dict(block=block - 1, weeks=weeks, test_day=test_day, tests=[t[:2] for t in tests], shift=shift,
                        today=today, ratios=ratios, missed_tests=missed_tests, current_max=current_max,
                        **today_of(today, None))
        current = next((w for w in reversed(weeks) if w[3]), None)
        today_sessions = [s for s in sessions if int(s.day) == int(now)]
        test_step = None
        # Les 2 tests de départ (bloc 1, 1re semaine) : le 1er au plus tard le vendredi, le 2e
        # 2 jours après le 1er, dans la même semaine ; sinon la semaine calibre sur les séances
        calib_next = None
        if block == 1 and current and current[0] == "P1" and calibration_days < 2:
            week_end = block_start + 7
            if calibration_days == 0:
                calib_next = max(int(now), first_day) if int(now) <= week_end - 3 else None
            else:
                second = kept_days[0] + 2
                calib_next = second if second < week_end else None
        if reprise_today or (current and current[0] == "Reprise"):
            today = ("reprise", deload)
        elif now >= test_day:
            today = ("test", None)
        elif current and current[0] == "Allégée":
            today = ("deload", deload)
        elif (block == 1 and current and current[0] == "P1" and calibration_days < 2
              and (any(s.test_best for s in today_sessions)
                   or (not today_sessions and calib_next is not None and calib_next <= int(now)))):
            today = ("test", None)
            test_step = (calibration_days + (0 if any(s.test_best for s in today_sessions) else 1), 2)
        elif low_form or persistent_fatigue:
            today = ("light", lighter(session_now))
        else:
            today = ("session", session_now)
        overdue = today[0] == "test" and test_step is None and int(now) > int(test_day)
        if overdue:
            shift += waiting_weeks(test_day, now)
        return dict(block=block, weeks=weeks, test_day=test_day, tests=[t[:2] for t in tests], shift=shift, today=today,
                    ratios=ratios, overdue=overdue, test_step=test_step,
                    missed_tests=missed_tests, current_max=current_max, max_raise=last_raise,
                    calib_next=calib_next, calib_done=calibration_days if block == 1 else None,
                    fallback=(deload if test_step is None else session_now) if today[0] == "test" else None,
                    **today_of(today, test_day))


# --- Scénarios -------------------------------------------------------------------------------

def schedule(first_day, last_day, sets=(15, 15, 15, 15), skip=(), tired=(), days=(0, 2, 4), rests=None):
    out = []
    for d in range(first_day, last_day):
        if d % 7 in days and d not in skip:
            out.append(Session(d + 0.75, list(sets), tired=d in tired, rests=rests))
    return out


def first_target(p):
    """La série 1 du jour, ou de la séance proposée à la place d'un test (bloc 1, calibrage)."""
    return (p["today"][1] or p["fallback"])[0][0]


def check(name, got, expect):
    errors = [f"{k} : attendu {v!r}, obtenu {got.get(k)!r}" for k, v in expect.items() if got.get(k) != v]
    print(("ok    " if not errors else "ÉCHEC ") + name)
    for e in errors:
        print("      " + e)
    return not errors


def main():
    ok = True
    # Historique : 4 semaines avant l'objectif (lundi, mercredi, vendredi, 4 × 15, repos 60 s)
    history = schedule(-28, 0)
    default = ([12, 10, 8], 60)          # 12, 12 × 0,8 = 9,6 → 10, 12 × 0,64 = 7,7 → 8

    # 1. Bloc régulier, cibles dégressives sans baisse mesurée (4 × 15 : pas de baisse, mais les
    #    rapports valent 1 : les séances sont éligibles ; voir le scénario 9 pour le défaut)
    s = history + schedule(0, 10)
    p = make(0, s, 10.5)
    ok &= check("régulier, jour 10 (jeudi) : séance proposée", p, dict(block=1, test_day=28, shift=0,
                                                                       today=("session", ([12, 12, 12], 60)),
                                                                       status="due", next=11, rest_reason=None))
    ok &= check("régulier, jour 11 (vendredi)", make(0, s, 11.3), dict(status="due"))
    s = history + schedule(0, 22)
    ok &= check("semaine allégée, jour 22", make(0, s, 22.5), dict(today=("deload", ([12, 12], 60))))
    s = history + schedule(0, 28)
    ok &= check("jour de test, jour 28", make(0, s, 28.2), dict(today=("test", None), test_day=28, status="due"))

    # 2. Test fait en mode test (jour 28, 32) : le bloc 2 commence le lundi suivant, série 1 = 29
    s = history + schedule(0, 28) + [test_session(28.75, attempts=(32,))]
    p = make(0, s, 36.5)
    ok &= check("bloc 2 après le test", p, dict(block=2, tests=[(28.75, 32)], test_day=63))
    ok &= check("bloc 2 : série 1 = 32 − 3", dict(first=p["today"][1][0][0]), dict(first=29))

    # 3. Séances manquées en semaine 2 : semaine refaite, test au jour 35
    s = history + schedule(0, 21, skip=(9, 11))
    p = make(0, s, 21.5)
    ok &= check("séances manquées : semaine refaite", p, dict(shift=1, test_day=35))
    ok &= check("frise avec P2 bis", dict(names=[w[0] for w in p["weeks"]]),
                dict(names=["P1", "P2", "P2 bis", "P3", "Allégée"]))

    # 4. Forme basse deux fois en semaine 1 : refaite
    s = history + schedule(0, 14, tired=(0, 2))
    ok &= check("Forme basse × 2 : semaine refaite", make(0, s, 14.5), dict(shift=1, test_day=35))

    # 5. Plafond : deux semaines refaites au plus par bloc
    s = history + schedule(0, 7)
    # (jour 30 : moins de 28 jours sans séance, sinon c'est une reprise, scénario 16)
    ok &= check("deux semaines refaites au plus", make(0, s, 30.5), dict(shift=2))

    # 6. Séance légère quand la Forme est basse aujourd'hui (semaine 2 : la semaine 1 du bloc 1
    #    est celle des tests de calibrage)
    s = history + schedule(0, 10)
    ok &= check("séance légère", make(0, s, 11.5, low_form=True), dict(today=("light", ([12, 12], 60))))

    # 7. Une séance par semaine (le lundi) : chaque jour une séance est proposée ; au-delà de la
    #    première semaine, la ligne « au moins 2 séances par semaine » (règle 6)
    s = schedule(-28, 0, days=(0,)) + schedule(0, 10, days=(0,))
    ok &= check("1re semaine : pas de rappel", make(0, s, 1.5), dict(status="due", next=2, below_minimum=False))
    ok &= check("une séance en 7 jours : au moins 2", make(0, s, 8.5), dict(status="due", below_minimum=True))
    s2 = s + [Session(6.5, [15, 15])]
    ok &= check("deux séances en 7 jours : pas de rappel", make(0, s2, 8.5), dict(below_minimum=False))

    # 8. Baisse habituelle mesurée : 30 · 26 · 23 avec 90 s de repos → 27 · 23 · 21
    h = schedule(-28, 7, sets=(30, 26, 23), rests=[90, 90])
    p = make(0, h, 7.5)
    ok &= check("cibles selon la baisse habituelle", dict(t=p["today"][1]), dict(t=([27, 23, 21], 90)))

    # 9. Sans baisse mesurable (repos trop différents du repos prévu) : 80 % de la précédente
    h = schedule(-28, -14, sets=(15, 13, 11), rests=[30, 30]) + schedule(-14, 7, sets=(15, 13, 11), rests=[150, 150])
    p = make(0, h, 7.5)
    ok &= check("baisse par défaut (80 %)", dict(t=p["today"][1][0], r=p["ratios"]), dict(t=default[0], r=None))

    # 10. Réajustement en séance : cibles 29 · 23 · 19 (par défaut)
    session = ([29, 23, 19], 90)
    ok &= check("série 1 dépassée : cible 2 inchangée", dict(n=next_target(session, None, [30], [30])), dict(n=23))
    ok &= check("série 1 sous sa cible : série 2 réajustée", dict(n=next_target(session, None, [20], [20])), dict(n=16))
    ok &= check("pas de rattrapage", dict(n=next_target(session, None, [20, 16], [20, 16])), dict(n=13))
    ok &= check("séries espacées : repart de la série 1", dict(n=next_target(session, None, [29], [])), dict(n=29))
    ok &= check("toutes les séries faites", dict(n=next_target(session, None, [29, 23, 19], [29, 23, 19])), dict(n=None))

    # 11. Le coach au jour le jour (METHODE-JOURS.md) : pas de jours prévus
    s = schedule(-28, 0, days=(0, 3))
    ok &= check("sans séance hier : séance proposée", make(0, s, 1.5), dict(status="due", next=2))
    s2 = s + [Session(1.5, [15, 15, 15])]
    ok &= check("séance du jour faite", make(0, s2, 1.7), dict(status="done", next=2, target_missed=False))
    # Séance terminée sous la cible (cibles 12 · 12 · 12, fait 8 · 12 · 12) : faite, cible non atteinte
    ok &= check("séance sous la cible : faite, cible non atteinte", make(0, s + [Session(8.5, [8, 12, 12])], 8.7),
                dict(status="done", target_missed=True))
    # (c) La séance d'hier « Très difficile » (effort ≥ 7) : repos conseillé, prochaine demain
    #     (semaine 2 : en semaine 1 du bloc 1, chaque jour propose un test de calibrage)
    w2 = schedule(-28, 8, days=(0, 3))
    hard = w2 + [Session(8.5, [15, 15, 15], effort=8)]
    ok &= check("séance d'hier très difficile : repos", make(0, hard, 9.4),
                dict(status="rest", rest_reason="hard_yesterday", next=10))
    ok &= check("effort 6 : séance", make(0, w2 + [Session(8.5, [15, 15, 15], effort=6)], 9.4), dict(status="due"))
    # Un repos est une proposition : une séance faite ce jour-là compte
    ok &= check("séance faite un jour de repos", make(0, hard + [Session(9.5, [15, 15, 15])], 9.7), dict(status="done"))
    # (d) 21 séries sur les 7 derniers jours : repos ; le lendemain, 18 : séance
    daily = s + [Session(d + 0.5, [12, 12, 12]) for d in range(0, 7)]
    ok &= check("20 séries en 7 jours : repos", make(0, daily, 7.4),
                dict(status="rest", rest_reason="weekly_volume", next=8))
    # (a) La veille du test (dimanche de la semaine allégée) : repos, prochaine le jour de test
    s3 = history + schedule(0, 27)
    p = make(0, s3, 27.5)
    ok &= check("veille du test : repos", p, dict(status="rest", rest_reason="before_test", next=28))
    # (b) Fatigue persistante : repos
    ok &= check("fatigue persistante : repos", make(0, history + schedule(0, 10), 10.5, persistent_fatigue=True),
                dict(status="rest", rest_reason="persistent_fatigue"))
    # Fatigue persistante, séance faite quand même : la séance légère
    ok &= check("fatigue persistante : séance légère si l'on s'entraîne", make(0, history + schedule(0, 10), 10.5, persistent_fatigue=True),
                dict(today=("light", ([12, 12], 60))))
    # Un jour de repos conseillé : pas de rappel du minimum (qui contredirait le repos)
    ok &= check("repos conseillé : pas de rappel du minimum", make(0, s + [Session(d + 0.5, [12, 12, 12]) for d in range(0, 7)], 7.4),
                dict(status="rest", below_minimum=False))
    # Jour de test : l'effort d'hier ne repousse pas le test (test du jour, à faire, calibrage 2 / 2)
    s5 = history + schedule(0, 26) + [Session(27.5, [15, 15, 15], effort=9)]
    ok &= check("jour de test après une séance très difficile : test", make(0, s5, 28.3),
                dict(today=("test", None), status="due"))
    cal = history + [Session(test_session(0.75, attempts=(30,)).day, [30], roles=["test"], effort=10)]
    p = make(0, cal, 2.5)
    ok &= check("calibrage : test 2 / 2 deux jours après un test noté 10", dict(t=p["today"][0], st=p["status"], step=p["test_step"]),
                dict(t="test", st="due", step=(2, 2)))
    # Après le test, jusqu'au bloc suivant : une séance chaque jour, de son nouveau max
    s4 = history + schedule(0, 28) + [test_session(28.75, attempts=(32,))]
    p = make(0, s4, 29.5)
    ok &= check("après le test : séance du nouveau max", dict(st=p["status"], first=p["today"][1][0][0]), dict(st="due", first=29))

    # 12. Séries espacées : deux séances le même jour comptent pour un seul jour d'entraînement
    s4 = s + [Session(0.4, [15]), Session(0.8, [12, 10])]
    p = make(0, s4, 0.9)
    ok &= check("séries espacées : une seule séance du jour", dict(done=p["weeks"][0][4]), dict(done=1))

    # 13. Sans aucune séance : pas de plan
    ok &= check("sans séance, pas de plan", dict(plan=make(0, [], 2)), dict(plan=None))

    # 14. Test annoncé : seules les séries en mode test comptent ; la meilleure (échauffement exclu)
    s = history + schedule(0, 28) + [test_session(28.75, warmup=10, attempts=(20, 34))]
    ok &= check("test annoncé : meilleure tentative, échauffement exclu", make(0, s, 36.5), dict(tests=[(28.75, 34)]))
    # Une séance normale le jour de test n'est pas un test : il reste à faire
    s = history + schedule(0, 28) + [Session(28.75, [40, 30, 25])]
    p = make(0, s, 29.5)
    ok &= check("séance normale le jour de test : pas un test", p, dict(tests=[], overdue=True))
    ok &= check("test à faire : séance allégée en attendant", dict(today=p["today"][0], f=p["fallback"]),
                dict(today="test", f=([12, 12], 60)))

    # 15. Plus de 7 jours sans séance avant le test (rien en semaine allégée, retour jour 30) :
    #     semaine de reprise (lundi 28 → 35), puis le test à partir du jour 35
    s = history + schedule(0, 21) + [Session(30.75, [15, 15])]
    p = make(0, s, 31.5)
    ok &= check("reprise avant le test", p, dict(test_day=35, tests=[]))
    ok &= check("reprise : séance allégée", dict(kind=p["today"][0], week=p["weeks"][-1][0]), dict(kind="reprise", week="Reprise"))
    s2 = s + [test_session(35.75, attempts=(30,))]
    ok &= check("test après la reprise", make(0, s2, 36.5), dict(tests=[(35.75, 30)], block=1, status="due"))
    # Pas encore revenu, jour de test atteint après 9 jours sans séance : la reprise, pas le test
    s = history + schedule(0, 19)
    ok &= check("pas de test après 7 jours d'absence", dict(kind=make(0, s, 28.3)["today"][0]), dict(kind="reprise"))
    # Moins de 7 jours d'écart : le test directement
    s = history + schedule(0, 26) + [test_session(28.75, attempts=(31,))]
    ok &= check("test sans reprise", make(0, s, 29.5), dict(tests=[(28.75, 31)]))

    # 16. Plus de 28 jours sans séance : jamais de plan nul, une séance de reprise libre
    s = history + schedule(0, 10)
    p = make(0, s, 45)
    ok &= check("longue absence : reprise", p, dict(today=("comeback", None), status="due", block=1))
    # La séance de reprise (jour 50, lundi 49) ouvre un nouveau bloc 1 ancré sur sa semaine
    s2 = s + [Session(50.75, [12, 10, 8])]
    p = make(0, s2, 51.5)
    ok &= check("nouveau bloc 1 après l'absence", p, dict(block=1, tests=[], test_day=49 + 28))
    # Semaine 1 : les cibles suivent chaque séance (calibrage) ; semaine 2 : figées
    s3 = s2 + [Session(52.75, [20, 16, 13])]
    p = make(0, s3, 53.5)
    ok &= check("calibrage : la cible suit la séance", dict(first=first_target(p)), dict(first=17))
    s4 = s3 + [Session(57.75, [18, 15, 12])]
    p = make(0, s4, 58.5)
    ok &= check("semaine 2 : cibles figées", dict(first=p["today"][1][0][0]), dict(first=17))
    # … sauf si une série dépasse le max (30 > 20) : le max est relevé, série 1 = 27
    s5 = s3 + [Session(57.75, [30, 25, 20])]
    ok &= check("semaine 2 : une série au-dessus du max le relève", dict(first=make(0, s5, 58.5)["today"][1][0][0]), dict(first=27))

    # 17. Relecture : test à série nulle, reprise sans date passée, retour en milieu de semaine
    s = history + schedule(0, 28) + [test_session(28.75, attempts=(0, 30))]
    ok &= check("tentative à 0 ignorée", make(0, s, 36.5), dict(tests=[(28.75, 30)]))
    s = history + schedule(0, 28) + [test_session(28.4, attempts=(0,)), test_session(29.75, attempts=(31,))]
    ok &= check("test abandonné à 0 : reste à faire", make(0, s, 36.5), dict(tests=[(29.75, 31)]))
    s = history + schedule(0, 19)
    p = make(0, s, 30.3)
    ok &= check("reprise pas faite : test à venir", dict(test_day=p["test_day"], kind=p["today"][0]),
                dict(test_day=35, kind="reprise"))
    # Retour un mercredi (jour 51) après 40 jours : lundi 49 n'est pas « manqué »
    s = history + schedule(0, 10) + [Session(51.75, [12, 10, 8])]
    p = make(0, s, 56.5)
    ok &= check("retour en milieu de semaine : rien de manqué avant", dict(shift=p["shift"]), dict(shift=0))
    # Après l'absence, la séance d'avant ne sert pas au calibrage (série 1 = 12 − 3, pas 15 − 3)
    s = history + schedule(0, 10) + [Session(38.75, [12, 10, 8])]
    p = make(0, s, 39.5)
    ok &= check("calibrage sans les séances d'avant l'absence", dict(first=first_target(p)), dict(first=9))

    # 18. Test annoncé (METHODE-TEST.md) — 2e tentative : le meilleur des deux compte
    s = history + schedule(0, 28) + [test_session(28.75, warmup=10, attempts=(28, 33))]
    ok &= check("2e tentative : le meilleur des deux", make(0, s, 36.5), dict(tests=[(28.75, 33)]))
    # Tests sur plusieurs jours : le meilleur du premier test au début du bloc suivant
    s = history + schedule(0, 28) + [test_session(28.75, attempts=(30,)), test_session(30.75, attempts=(34,))]
    ok &= check("tests sur 2 jours : le meilleur", make(0, s, 36.5), dict(tests=[(28.75, 34)], block=2))
    # Test anticipé en semaine allégée (jour 23) : il compte et clôt le bloc (bloc 2 dès le lundi 28)
    s = history + schedule(0, 21) + [test_session(23.75, attempts=(31,))]
    p = make(0, s, 29.5)
    ok &= check("test anticipé en semaine allégée : clôt le bloc", p, dict(tests=[(23.75, 31)], block=2))
    # Test lancé en semaine de progression (jour 9, 40 > max 15) : le bloc continue, le max est relevé
    s = history + schedule(0, 9) + [test_session(9.75, attempts=(40,))]
    p = make(0, s, 10.5)
    ok &= check("test en progression : bloc continu, max relevé", p, dict(block=1, tests=[], current_max=40, max_raise=40))
    ok &= check("test en progression : cibles recalculées", dict(first=p["today"][1][0][0]), dict(first=37))
    # Test lancé en progression sous le max : rien ne change
    s = history + schedule(0, 9) + [test_session(9.75, attempts=(10,))]
    ok &= check("test en progression sous le max", make(0, s, 10.5), dict(current_max=15, max_raise=None))
    # Test non lancé : « à faire » ; 7 jours après le jour prévu (28 → 35), le bloc suivant repart
    # du dernier max, sans recalage
    s = history + schedule(0, 35)
    p = make(0, s, 30.5)
    ok &= check("test non lancé : à faire", p, dict(today=("test", None), overdue=True, block=1))
    p = make(0, s, 35.5)
    ok &= check("7 jours sans test : bloc suivant sur le dernier max", p,
                dict(block=2, tests=[], missed_tests=[28], current_max=15))
    # Bloc 1 : 2 tests sur 2 jours de la première semaine, le meilleur sert de départ
    s = history + [test_session(0.75, attempts=(30,))]
    p = make(0, s, 1.5)
    ok &= check("bloc 1 : test 1 / 2 fait, le 2e reste à faire", p, dict(tests=[(0.75, 30)]))
    p = make(0, s, 1.5)
    ok &= check("bloc 1 : pas de 2e test le lendemain du 1er", dict(today=p["today"][0], nxt=p["calib_next"]), dict(today="session", nxt=2))
    p = make(0, s, 2.5)
    ok &= check("bloc 1 : 2e test proposé 2 jours après", dict(today=p["today"][0], step=p["test_step"]), dict(today="test", step=(2, 2)))
    # Pas de test de départ commencé le samedi : il n'y aurait pas la place du 2e dans la semaine
    ok &= check("bloc 1 : pas de 1er test après le vendredi", dict(t=make(0, history, 5.5)["today"][0],
                n=make(0, history, 5.5)["calib_next"]), dict(t="session", n=None))
    ok &= check("bloc 1 : 1er test proposé le vendredi", dict(t=make(0, history, 4.5)["today"][0]), dict(t="test"))
    # 1er test le samedi quand même : le 2e n'a plus la place cette semaine
    s6 = history + [test_session(5.75, attempts=(30,))]
    ok &= check("bloc 1 : 1er test le samedi, pas de 2e", dict(n=make(0, s6, 6.5)["calib_next"], t=make(0, s6, 6.5)["today"][0]),
                dict(n=None, t="session"))
    s2 = s + [test_session(2.75, attempts=(34,))]
    p = make(0, s2, 7.5)
    ok &= check("bloc 1 : le meilleur des 2 tests sert de départ", dict(tests=p["tests"], first=p["today"][1][0][0]),
                dict(tests=[(0.75, 34)], first=31))
    # Max relevé en cours de bloc (Science, validé par Vincent) : une série qui dépasse le max
    # (15) le remplace par ses répétitions : 17 → max 17, série 1 = 14
    s = history + schedule(0, 7) + [Session(7.75, [17, 14, 11], targets=[12, 10, 8])]
    p = make(0, s, 8.5)
    ok &= check("max relevé : la série qui dépasse le max", dict(m=p["current_max"], r=p["max_raise"]), dict(m=17, r=17))
    ok &= check("max relevé : cibles recalculées dès la séance suivante", dict(first=p["today"][1][0][0]), dict(first=14))
    s = history + schedule(0, 7) + [Session(7.75, [15, 12, 10], targets=[12, 12, 12])]
    ok &= check("série égale au max : rien ne change", make(0, s, 8.5), dict(current_max=15, max_raise=None))
    # Un seul relèvement par séance (cibles 17 · 14 · 11 faites à 20 · 17 · 14 : max 20, pas plus)
    s = history + schedule(0, 7) + [Session(7.75, [20, 17, 14], targets=[17, 14, 11])]
    ok &= check("un seul relèvement par séance", make(0, s, 8.5), dict(current_max=20))

    # 20. Relecture de 31c8351 — sans aucun test (lun/mer/ven), le plan ne disparaît jamais
    s = history + schedule(0, 120)
    alive = all(make(0, s, d + 0.5) is not None for d in range(0, 120, 3))
    ok &= check("sans test pendant 17 semaines : toujours un plan", dict(alive=alive), dict(alive=True))
    # Séances d'avant la mise à jour (aucun rôle) : l'ancienne règle du test (première série > 0)
    s = history + schedule(0, 28) + [Session(28.75, [0, 31, 25])]
    ok &= check("ancienne séance : ancienne règle du test", make(0, s, 36.5, legacy_before=40), dict(tests=[(28.75, 31)]))
    ok &= check("après la mise à jour : pas un test", make(0, s, 36.5, legacy_before=20), dict(tests=[]))
    # Une pause de plus de 7 jours pendant l'attente du test : la reprise prime
    s = history + schedule(0, 31)
    ok &= check("pause pendant l'attente : reprise", dict(kind=make(0, s, 40.5)["today"][0]), dict(kind="reprise"))

    print("\nOK" if ok else "\nÉCHEC")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
"""Plan d'entraînement : miroir Python de RepCounter/Plan.swift et Prescription.swift, et sa
validation sur des historiques synthétiques.

Usage : python3 Simulation/plan.py      (code de sortie 1 si un scénario échoue)

Un bloc : 3 semaines de progression, 1 semaine allégée, puis un test (la première séance après la
semaine allégée). Une semaine de progression finie avec des séances manquées, ou deux séances en
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
Les séances sont placées dans la semaine (2 : lundi, jeudi ; 3 : lundi, mercredi, vendredi) ; les
jours d'entraînement consomment les jours prévus dans l'ordre.
Jours comptés depuis un lundi (jour 0 = lundi de la semaine où l'objectif est fixé).
"""

import sys
from dataclasses import dataclass, field
from statistics import median

PROGRESSION_WEEKS, MAX_REPEATS, HABIT_DAYS = 3, 2, 28
SETS, RESERVE, MIN_PER_WEEK = 3, 3, 2
DEFAULT_STEP, RATIO_SESSIONS, REST_TOLERANCE = 0.8, 3, 30
WEEKDAYS = {1: [1], 2: [1, 4], 3: [1, 3, 5], 4: [1, 2, 4, 5], 5: [1, 2, 3, 4, 5], 6: [1, 2, 3, 4, 5, 6]}


@dataclass
class Session:
    day: float
    sets: list
    tired: bool = False
    rests: list = None    # repos avant les séries 2, 3… (s)

    def __post_init__(self):
        if self.rests is None:
            self.rests = [60] * (len(self.sets) - 1)

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
    # Des jours d'entraînement, pas des séances (séries espacées le même jour : une séance)
    weeks = {}
    for s in recent:
        weeks.setdefault(int(s.day // 7), set()).add(int(s.day))
    per_week = max(MIN_PER_WEEK, rnd(median([len(d) for d in weeks.values()])))
    ratios = ratios_of(recent, rest)
    return (targets(max(1, (test_max or best) - RESERVE), ratios), rest), ratios, per_week


def lighter(session):
    return (session[0][:max(1, (len(session[0]) + 1) // 2)], session[1])


def training_days(sessions):
    return len({int(s.day) for s in sessions})


def week_status(days, start, sessions, now):
    """Jours prévus, consommés dans l'ordre par les jours d'entraînement : (due, prochaine)."""
    today = int(now)
    trained = {int(s.day) for s in sessions}
    planned = [start + d - 1 for d in days]
    remaining = planned[len(trained):]
    due = today not in trained and any(d <= today for d in remaining)
    later = [d for d in remaining if d > today]
    return due, (later[0] if later else None)


def make(goal_day, sessions, now, low_form=False, weekdays=None):
    sessions = sorted([s for s in sessions if s.day <= now], key=lambda s: s.day)
    block_start = (goal_day // 7) * 7
    block, tests, shift, excluded = 1, [], 0, set()
    while True:
        reference = [s for s in sessions if id(s) not in excluded]
        test_max = tests[-1][1] if tests else None
        h = habitual(reference, block_start, test_max) or habitual(reference, now + 1e-6, test_max)
        if h is None:
            return None
        habit, ratios, per_week = h
        days = sorted(set(weekdays or WEEKDAYS.get(per_week, [1, 2, 3, 4, 5, 6, 7])))
        per_week = len(days)
        weeks, start, progression, repeats, redo = [], block_start, 0, 0, False
        while progression < PROGRESSION_WEEKS:
            done = [s for s in sessions if start <= s.day < start + 7]
            past = start + 7 <= now
            reason = None
            if past and repeats < MAX_REPEATS:
                missed = per_week - training_days(done)
                tired = sum(s.tired for s in done)
                if missed > 0:
                    reason = f"{missed} manquée(s)"
                elif tired >= 2:
                    reason = f"Forme basse × {tired}"
            weeks.append((f"P{progression + 1}{' bis' if redo else ''}", start, past, start <= now < start + 7,
                          training_days(done), reason))
            start += 7
            if reason:
                repeats += 1
                shift += 1
                redo = True
            else:
                progression += 1
                redo = False
        deload_done = [s for s in sessions if start <= s.day < start + 7]
        excluded |= {id(s) for s in deload_done}
        weeks.append(("Allégée", start, start + 7 <= now, start <= now < start + 7, training_days(deload_done), None))
        test_day = start + 7
        test = next((s for s in sessions if s.day >= test_day), None)
        if test is not None:
            tests.append((test.day, test.best))
            excluded.add(id(test))
            block_start = (int(test.day) // 7) * 7 + 7
            block += 1
            if block_start <= now:
                continue
            # Jusqu'au bloc suivant, repos ; ses cibles partent déjà du nouveau max
            reference = [x for x in sessions if id(x) not in excluded]
            fresh = habitual(reference, now + 1, test_max=test.best)
            if fresh is not None:
                habit = fresh[0]
            return dict(block=block - 1, weeks=weeks, test_day=test_day, tests=tests, shift=shift,
                        today=("session", habit), status="rest", next=block_start + days[0] - 1,
                        per_week=per_week, ratios=ratios)
        current = next((w for w in weeks if w[3]), None)
        if now >= test_day:
            today = ("test", None)
        elif current and current[0] == "Allégée":
            today = ("deload", lighter(habit))
        elif low_form:
            today = ("light", lighter(habit))
        else:
            today = ("session", habit)
        this_week = (int(now) // 7) * 7
        week_sessions = [s for s in sessions if this_week <= s.day < this_week + 7]
        due, nxt = week_status(days, this_week, week_sessions, now)
        today_sessions = [s for s in sessions if int(s.day) == int(now)]
        planned_today = sum(today[1][0]) if today[1] else 1
        if today_sessions and sum(s.total for s in today_sessions) >= planned_today:
            status = "done"
        elif today[0] == "test" or today_sessions or due:
            status = "due"
        else:
            status = "rest"
        if nxt is None:
            nxt = test_day if this_week + 7 >= test_day else this_week + 7 + days[0] - 1
        return dict(block=block, weeks=weeks, test_day=test_day, tests=tests, shift=shift, today=today,
                    status=status, next=nxt, per_week=per_week, ratios=ratios)


# --- Scénarios -------------------------------------------------------------------------------

def schedule(first_day, last_day, sets=(15, 15, 15, 15), skip=(), tired=(), days=(0, 2, 4), rests=None):
    out = []
    for d in range(first_day, last_day):
        if d % 7 in days and d not in skip:
            out.append(Session(d + 0.75, list(sets), tired=d in tired, rests=rests))
    return out


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
    ok &= check("régulier, jour 10 (jeudi, repos)", p, dict(block=1, test_day=28, shift=0, per_week=3,
                                                            today=("session", ([12, 12, 12], 60)),
                                                            status="rest", next=11))
    ok &= check("régulier, jour 11 (vendredi)", make(0, s, 11.3), dict(status="due"))
    s = history + schedule(0, 22)
    ok &= check("semaine allégée, jour 22", make(0, s, 22.5), dict(today=("deload", ([12, 12], 60))))
    s = history + schedule(0, 28)
    ok &= check("jour de test, jour 28", make(0, s, 28.2), dict(today=("test", None), test_day=28, status="due"))

    # 2. Test fait (jour 28, 32) : le bloc 2 commence le lundi suivant, série 1 = 29
    s = history + schedule(0, 28) + [Session(28.75, [32])]
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
    ok &= check("deux semaines refaites au plus", make(0, s, 35.5), dict(shift=2))

    # 6. Séance légère quand la Forme est basse aujourd'hui (jour 3 : jeudi, pas prévu → repos)
    s = history + schedule(0, 3)
    ok &= check("séance légère", make(0, s, 4.5, low_form=True), dict(today=("light", ([12, 12], 60))))

    # 7. Une séance par semaine d'habitude : le plan en demande 2, lundi et jeudi
    s = schedule(-28, 0, days=(0,)) + schedule(0, 3, days=(0,))
    p = make(0, s, 1.5)
    ok &= check("au moins 2 séances par semaine", p, dict(per_week=2, status="rest", next=3))

    # 8. Baisse habituelle mesurée : 30 · 26 · 23 avec 90 s de repos → 27 · 23 · 21
    h = schedule(-28, 0, sets=(30, 26, 23), rests=[90, 90])
    p = make(0, h, 0.5)
    ok &= check("cibles selon la baisse habituelle", dict(t=p["today"][1]), dict(t=([27, 23, 21], 90)))

    # 9. Sans baisse mesurable (repos trop différents du repos prévu) : 80 % de la précédente
    h = schedule(-28, -14, sets=(15, 13, 11), rests=[30, 30]) + schedule(-14, 0, sets=(15, 13, 11), rests=[150, 150])
    p = make(0, h, 0.5)
    ok &= check("baisse par défaut (80 %)", dict(t=p["today"][1][0], r=p["ratios"]), dict(t=default[0], r=None))

    # 10. Réajustement en séance : cibles 29 · 23 · 19 (par défaut)
    session = ([29, 23, 19], 90)
    ok &= check("série 1 dépassée : cible 2 inchangée", dict(n=next_target(session, None, [30], [30])), dict(n=23))
    ok &= check("série 1 sous sa cible : série 2 réajustée", dict(n=next_target(session, None, [20], [20])), dict(n=16))
    ok &= check("pas de rattrapage", dict(n=next_target(session, None, [20, 16], [20, 16])), dict(n=13))
    ok &= check("séries espacées : repart de la série 1", dict(n=next_target(session, None, [29], [])), dict(n=29))
    ok &= check("toutes les séries faites", dict(n=next_target(session, None, [29, 23, 19], [29, 23, 19])), dict(n=None))

    # 11. Placement : 2 séances (lundi, jeudi). Mardi sans séance lundi : à rattraper ; prochaine jeudi
    s = schedule(-28, 0, days=(0, 3)) + []
    p = make(0, s, 1.5)
    ok &= check("lundi manqué : séance due mardi", p, dict(status="due", next=3))
    # Séance faite mercredi (jour non prévu) : elle remplace lundi ; prochaine jeudi
    s2 = s + [Session(2.5, [15, 12, 10])]
    p = make(0, s2, 2.7)
    ok &= check("séance faite un jour non prévu", p, dict(status="done", next=3))
    # Jeudi, après la séance de lundi : jeudi est dû
    s3 = s + [Session(0.5, [15, 12, 10])]
    ok &= check("jeudi prévu", make(0, s3, 3.4), dict(status="due"))
    ok &= check("mardi : repos, prochaine jeudi", make(0, s3, 1.4), dict(status="rest", next=3))
    # Jours déplacés : mardi et samedi ; la séance de lundi remplace celle de mardi
    ok &= check("jours déplacés", make(0, s3, 1.4, weekdays=[2, 6]), dict(status="rest", next=5))
    ok &= check("jours déplacés, sans séance lundi", make(0, s, 1.4, weekdays=[2, 6]), dict(status="due", next=5))

    # 12. Séries espacées : deux séances le même jour comptent pour un seul jour d'entraînement
    s4 = s + [Session(0.4, [15]), Session(0.8, [12, 10])]
    p = make(0, s4, 0.9)
    ok &= check("séries espacées : une seule séance du jour", dict(done=p["weeks"][0][4]), dict(done=1))

    # 13. Sans aucune séance : pas de plan
    ok &= check("sans séance, pas de plan", dict(plan=make(0, [], 2)), dict(plan=None))

    print("\nOK" if ok else "\nÉCHEC")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())

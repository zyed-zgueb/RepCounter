#!/usr/bin/env python3
"""Plan d'entraînement : miroir Python de RepCounter/Plan.swift et Prescription.swift, et sa
validation sur des historiques synthétiques.

Usage : python3 Simulation/plan.py      (code de sortie 1 si un scénario échoue)

Un bloc : 3 semaines de progression, 1 semaine allégée, puis un test (la première séance après la
semaine allégée). Une semaine de progression finie avec des séances manquées, ou deux séances en
Forme basse, est refaite (deux fois au plus par bloc) : le test et la date de l'objectif reculent
d'autant. Séance prévue (ACSM 2026, Currier et al.) : 3 séries de (max − 3) répétitions, le max
étant le dernier test (sinon la meilleure série des 4 semaines avant le bloc), repos habituel, au
moins 2 séances par semaine ; pas de hausse hebdomadaire ; allégée et légère : la moitié des
séries, arrondie au-dessus (choix de l'app).
Jours comptés depuis un lundi (jour 0 = lundi de la semaine où l'objectif est fixé).
"""

import sys
from dataclasses import dataclass, field
from statistics import median

PROGRESSION_WEEKS, MAX_REPEATS, HABIT_DAYS = 3, 2, 28
SETS, RESERVE, MIN_PER_WEEK = 3, 3, 2


@dataclass
class Session:
    day: float
    sets: list
    tired: bool = False
    rests: list = field(default_factory=lambda: [60])

    @property
    def total(self):
        return sum(self.sets)

    @property
    def best(self):
        return max(self.sets)


def habitual(sessions, before, test_max=None):
    recent = [s for s in sessions if before - HABIT_DAYS <= s.day < before]
    if not recent:
        return None
    best = max(s.best for s in recent)
    reps = max(1, (test_max or best) - RESERVE)
    rests = [r for s in recent for r in s.rests]
    rest = median(rests) if len(rests) >= 3 else 60
    weeks = {}
    for s in recent:
        weeks[int(s.day // 7)] = weeks.get(int(s.day // 7), 0) + 1
    per_week = max(MIN_PER_WEEK, round(median(weeks.values())))
    return (SETS, reps, min(max(round(rest / 15) * 15, 30), 300)), per_week


def lighter(session):
    return (max(1, (session[0] + 1) // 2), session[1], session[2])


def make(goal_day, sessions, now, low_form=False):
    """Renvoie un dict : block, weeks [(nom, début, passée, en cours, faites, refaite pour…)],
    test_day, tests [(jour, valeur)], shift, today."""
    sessions = sorted([s for s in sessions if s.day <= now], key=lambda s: s.day)
    block_start = (goal_day // 7) * 7
    block, tests, shift, excluded = 1, [], 0, set()
    while True:
        reference = [s for s in sessions if id(s) not in excluded]
        test_max = tests[-1][1] if tests else None
        h = habitual(reference, block_start, test_max) or habitual(reference, now + 1e-6, test_max)
        if h is None:
            return None
        habit, per_week = h
        weeks, start, progression, repeats, redo = [], block_start, 0, 0, False
        while progression < PROGRESSION_WEEKS:
            done = [s for s in sessions if start <= s.day < start + 7]
            past = start + 7 <= now
            reason = None
            if past and repeats < MAX_REPEATS:
                missed = per_week - len(done)
                tired = sum(s.tired for s in done)
                if missed > 0:
                    reason = f"{missed} manquée(s)"
                elif tired >= 2:
                    reason = f"Forme basse × {tired}"
            weeks.append((f"P{progression + 1}{' bis' if redo else ''}", start, past, start <= now < start + 7, len(done), reason))
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
        weeks.append(("Allégée", start, start + 7 <= now, start <= now < start + 7, len(deload_done), None))
        test_day = start + 7
        test = next((s for s in sessions if s.day >= test_day), None)
        if test is not None:
            tests.append((test.day, test.best))
            excluded.add(id(test))
            block_start = (int(test.day) // 7) * 7 + 7
            block += 1
            if block_start <= now:
                continue
            return dict(block=block - 1, weeks=weeks, test_day=test_day, tests=tests, shift=shift,
                        today=("session", habit), per_week=per_week)
        current = next((w for w in weeks if w[3]), None)
        if now >= test_day:
            today = ("test", None)
        elif current and current[0] == "Allégée":
            today = ("deload", lighter(habit))
        elif low_form:
            today = ("light", lighter(habit))
        else:
            today = ("session", habit)
        return dict(block=block, weeks=weeks, test_day=test_day, tests=tests, shift=shift, today=today,
                    per_week=per_week)


# --- Scénarios -------------------------------------------------------------------------------

def schedule(first_day, last_day, sets=(15, 15, 15, 15), skip=(), tired=(), days=(0, 2, 4)):
    out = []
    for d in range(first_day, last_day):
        if d % 7 in days and d not in skip:
            out.append(Session(d + 0.75, list(sets), tired=d in tired))
    return out


def check(name, plan, expect):
    errors = [f"{k} : attendu {v!r}, obtenu {plan.get(k)!r}" for k, v in expect.items() if plan.get(k) != v]
    print(("ok    " if not errors else "ÉCHEC ") + name)
    for e in errors:
        print("      " + e)
    return not errors


def main():
    ok = True
    # Historique : 4 semaines avant l'objectif (lundi, mercredi, vendredi, 4 × 15)
    history = schedule(-28, 0)

    # 1. Bloc régulier : au jour 10, semaine 2 ; au jour 22, semaine allégée ; au jour 28, test
    s = history + schedule(0, 10)
    p = make(0, s, 10.5)
    ok &= check("régulier, jour 10", p, dict(block=1, test_day=28, shift=0, today=("session", (3, 12, 60))))
    ok &= check("régulier, semaines", p, dict(per_week=3))
    s = history + schedule(0, 22)
    ok &= check("semaine allégée, jour 22", make(0, s, 22.5), dict(today=("deload", (2, 12, 60))))
    s = history + schedule(0, 28)
    ok &= check("jour de test, jour 28", make(0, s, 28.2), dict(today=("test", None), test_day=28))

    # 2. Test fait (jour 28, 32 d'affilée) : le bloc 2 commence le lundi suivant (jour 35)
    s = history + schedule(0, 28) + [Session(28.75, [32])]
    p = make(0, s, 36.5)
    ok &= check("bloc 2 après le test", p, dict(block=2, tests=[(28.75, 32)], test_day=63,
                                                today=("session", (3, 29, 60))))

    # 3. Deux séances manquées en semaine 2 : semaine 2 refaite, test au jour 35
    s = history + schedule(0, 21, skip=(9, 11))
    p = make(0, s, 21.5)
    ok &= check("séances manquées : semaine refaite", p, dict(shift=1, test_day=35))
    names = [w[0] for w in p["weeks"]]
    ok &= check("frise avec P2 bis", dict(names=names), dict(names=["P1", "P2", "P2 bis", "P3", "Allégée"]))

    # 4. Forme basse deux fois en semaine 1 : refaite
    s = history + schedule(0, 14, tired=(0, 2))
    ok &= check("Forme basse × 2 : semaine refaite", make(0, s, 14.5), dict(shift=1, test_day=35))

    # 5. Plafond : une semaine sans aucune séance trois fois de suite n'est refaite que deux fois
    s = history + schedule(0, 7)
    p = make(0, s, 35.5)
    ok &= check("deux semaines refaites au plus", p, dict(shift=2))

    # 6. Séance légère quand la Forme est basse aujourd'hui
    s = history + schedule(0, 3)
    ok &= check("séance légère", make(0, s, 3.5, low_form=True), dict(today=("light", (2, 12, 60))))

    # 7. Une séance par semaine d'habitude : le plan en demande 2 (ACSM 2026)
    s = schedule(-28, 0, days=(0,)) + schedule(0, 3, days=(0,))
    ok &= check("au moins 2 séances par semaine", make(0, s, 3.5), dict(per_week=2))

    # 8. Sans aucune séance : pas de plan
    ok &= check("sans séance, pas de plan", dict(plan=make(0, [], 2)), dict(plan=None))

    print("\nOK" if ok else "\nÉCHEC")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())

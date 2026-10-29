"""Sons de l'app, synthétisés (aucun fichier source) : notes brèves et feutrées en la majeur.

Usage : python3 Design/sound/make_sounds.py  → Design/sound/out/*.wav (+ démos .m4a si ffmpeg)
Deux timbres à comparer : « feutre » (marteau de feutre, corde étouffée) et « bois » (touche douce).
Le timbre INSTALLED est aussi écrit dans RepCounter/Sounds/, embarqué dans l'app.
Chaque son a un rôle unique, reconnaissable sans regarder l'écran :
  rep      une note (la)            répétition
  rep5     deux notes montantes     palier de 5
  rep10    arpège de trois notes    palier de 10
  count    bip court (mi)           3, 2, 1
  go       accord lumineux          départ
  setEnd   deux notes descendantes  fin de série
  target   accord aigu, cloche      cible de la série atteinte
  rest     un bip bref                récupération : 0:15 (puis 1:15, 2:15…)
  rest2    deux bips montants         récupération : 0:30
  rest3    trois bips montants        récupération : 0:45
  restMinute  accord grave, plus long récupération : chaque minute pleine
  finish   arpège complet, longue résonance   fin de séance
"""
import os
import subprocess
import wave

import numpy as np

RATE = 44_100
OUT = os.path.join(os.path.dirname(__file__), "out")

A3, CS4, E4, A4, CS5, E5, A5 = 220.0, 277.18, 329.63, 440.0, 554.37, 659.26, 880.0
CS6, E6 = 1108.73, 1318.51


def lowpass(signal, cutoff):
    """Filtre passe-bas à un pôle, appliqué deux fois : enlève le brillant, rend le son mat."""
    k = 1 - np.exp(-2 * np.pi * cutoff / RATE)
    for _ in range(2):
        out = np.empty_like(signal)
        acc = 0.0
        for i, x in enumerate(signal):
            acc += k * (x - acc)
            out[i] = acc
        signal = out
    return signal


def felt(freq, decay=0.045, level=0.6, duration=None):
    """Note feutrée : marteau de feutre sur une corde étouffée. Attaque arrondie de 6 ms,
    fondamentale dominante, légère chute de hauteur, extinction en quelques dizaines de ms."""
    duration = duration or decay * 6
    t = np.arange(int(RATE * duration)) / RATE
    glide = freq * (1 + 0.03 * np.exp(-t / 0.012))          # le feutre « appuie » sur la note
    phase = 2 * np.pi * np.cumsum(glide) / RATE
    tone = np.sin(phase) + 0.18 * np.sin(2 * phase) * np.exp(-t / (decay * 0.4))
    attack = 0.5 - 0.5 * np.cos(np.pi * np.minimum(t / 0.006, 1.0))
    return lowpass(level * tone * attack * np.exp(-t / decay), 1600)


def tap(freq, decay=0.028, level=0.75):
    """Touche douce : un souffle de bruit filtré qui porte une note très brève (bois étouffé)."""
    t = np.arange(int(RATE * decay * 6)) / RATE
    rng = np.random.default_rng(int(freq))
    body = np.sin(2 * np.pi * freq * t) * np.exp(-t / decay)
    breath = lowpass(rng.standard_normal(len(t)), 900) * np.exp(-t / 0.008) * 0.9
    attack = 0.5 - 0.5 * np.cos(np.pi * np.minimum(t / 0.003, 1.0))
    return lowpass(level * (body + breath) * attack, 2200)


def mix(*events, length=None):
    """events : (début en s, signal)."""
    end = max(start + len(sig) / RATE for start, sig in events)
    out = np.zeros(int(RATE * (length or end + 0.02)))
    for start, sig in events:
        i = int(start * RATE)
        out[i:i + len(sig)] += sig[: len(out) - i]
    return out


def palette(note):
    """Les mêmes rôles, joués avec un timbre donné (felt ou tap)."""
    return {
        "rep": lambda: mix((0, note(A4))),
        "rep5": lambda: mix((0, note(A4)), (0.05, note(E5, level=0.5))),
        "rep10": lambda: mix((0, note(A4)), (0.045, note(CS5, level=0.5)), (0.09, note(E5, level=0.5))),
        "count": lambda: mix((0, note(E4, level=0.55))),
        "go": lambda: mix((0, note(A4, decay=0.09, level=0.4)), (0, note(CS5, decay=0.09, level=0.3)),
                          (0, note(E5, decay=0.09, level=0.3))),
        "setEnd": lambda: mix((0, note(E5, level=0.45)), (0.08, note(A4, decay=0.07, level=0.55))),
        # Récupération : des bips, toutes les 15 s (1, 2, 3), et à chaque
        # minute pleine un accord plus long : on sait où on en est sans regarder l'écran
        # Bips très brefs (≈ 35 ms), comme la lampe du dentiste ; plusieurs bips montent (la, do#,
        # mi : l'arpège de la majeur des autres sons) et s'espacent de 0,13 s, pour qu'on les
        # compte à l'oreille sans les confondre avec un seul
        "rest": lambda: mix((0, note(A5, decay=0.012, level=0.45))),
        "rest2": lambda: mix(*[(0.13 * k, note(f, decay=0.012, level=0.45)) for k, f in enumerate([A5, CS6])]),
        "rest3": lambda: mix(*[(0.13 * k, note(f, decay=0.012, level=0.45)) for k, f in enumerate([A5, CS6, E6])]),
        "restMinute": lambda: mix((0, note(A3, decay=0.16, level=0.4)), (0.05, note(CS4, decay=0.16, level=0.3)),
                                  (0.1, note(E4, decay=0.18, level=0.3))),
        # Cible de la série atteinte : un accord aigu (la, do#, mi une octave au-dessus), plus long,
        # distinct des paliers de 5 et 10
        "target": lambda: mix((0, note(A5, decay=0.12, level=0.35)), (0, note(CS6, decay=0.12, level=0.28)),
                              (0, note(E6, decay=0.14, level=0.28))),
        "finish": lambda: mix(*[(0.07 * i, note(f, decay=0.06 if i < 3 else 0.12, level=0.45))
                                for i, f in enumerate([A4, CS5, E5, A5])]),
    }


VARIANTS = {"feutre": felt, "bois": tap}
# Timbre embarqué dans l'app (RepCounter/Sounds/<rôle>.wav)
INSTALLED = "feutre"
APP_SOUNDS = os.path.join(os.path.dirname(__file__), "../../RepCounter/Sounds")


def write_wav(path, signal):
    peak = np.max(np.abs(signal))
    if peak > 0.95:
        signal = signal * 0.95 / peak
    data = (signal * 32767).astype("<i2")
    with wave.open(path, "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(data.tobytes())


def demo_set(sounds):
    """Compte à rebours, 12 répétitions toutes les 1,7 s, fin de série, une marque de récupération, fin."""
    events = [(i, sounds["count"]()) for i in range(3)] + [(3, sounds["go"]())]
    t = 4.6
    for rep in range(1, 13):
        events.append((t, sounds["rep10" if rep % 10 == 0 else "rep5" if rep % 5 == 0 else "rep"]()))
        t += 1.7
    events.append((t + 2.5, sounds["setEnd"]()))
    for k, name in enumerate(["rest", "rest2", "rest3", "restMinute"]):
        events.append((t + 6.5 + 2 * k, sounds[name]()))
    events.append((t + 15, sounds["finish"]()))
    return mix(*events)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for variant, note in VARIANTS.items():
        sounds = palette(note)
        for name, make in sounds.items():
            write_wav(os.path.join(OUT, f"{variant}-{name}.wav"), make())
            if variant == INSTALLED:
                os.makedirs(APP_SOUNDS, exist_ok=True)
                write_wav(os.path.join(APP_SOUNDS, f"{name}.wav"), make())
        demo = os.path.join(OUT, f"demo-{variant}.wav")
        write_wav(demo, demo_set(sounds))
        try:
            subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", demo, "-c:a", "aac", "-b:a", "192k",
                            demo.replace(".wav", ".m4a")], check=True)
        except (OSError, subprocess.CalledProcessError):
            pass
    print("sons dans", OUT)

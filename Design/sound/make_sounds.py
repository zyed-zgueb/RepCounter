"""Sons de l'app, synthétisés (aucun fichier source) : clochettes douces en la majeur.

Usage : python3 Design/sound/make_sounds.py  → Design/sound/out/*.wav (+ démos .m4a si ffmpeg)
Chaque son a un rôle unique, reconnaissable sans regarder l'écran :
  rep      une note (la)            répétition
  rep5     deux notes montantes     palier de 5
  rep10    arpège de trois notes    palier de 10
  count    bip court (mi)           3, 2, 1
  go       accord lumineux          départ
  setEnd   deux notes descendantes  fin de série
  rest     battement grave, discret toutes les 30 s de récupération
  finish   arpège complet, longue résonance   fin de séance
"""
import os
import subprocess
import wave

import numpy as np

RATE = 44_100
OUT = os.path.join(os.path.dirname(__file__), "out")

A4, E5, A5, CS6, E6, A6 = 440.0, 659.26, 880.0, 1108.73, 1318.51, 1760.0


def bell(freq, duration=0.6, decay=0.16, level=0.5):
    """Clochette : fondamentale + partiels qui s'éteignent plus vite, attaque de 4 ms."""
    t = np.arange(int(RATE * duration)) / RATE
    partials = [(1.0, 1.0, decay), (2.0, 0.28, decay * 0.5), (3.0, 0.10, decay * 0.3), (4.16, 0.05, 0.03)]
    out = sum(a * np.sin(2 * np.pi * freq * k * t) * np.exp(-t / tau) for k, a, tau in partials)
    attack = np.minimum(t / 0.004, 1.0)
    return level * out * (0.5 - 0.5 * np.cos(np.pi * attack))


def beep(freq, duration=0.14, level=0.42):
    """Bip net de compte à rebours : sinus pur, attaque et extinction douces."""
    t = np.arange(int(RATE * duration)) / RATE
    envelope = np.minimum(t / 0.005, 1.0) * np.minimum((duration - t) / 0.03, 1.0)
    return level * envelope * (np.sin(2 * np.pi * freq * t) + 0.12 * np.sin(4 * np.pi * freq * t))


def mix(*events, length=None):
    """events : (début en s, signal)."""
    end = max(start + len(sig) / RATE for start, sig in events)
    out = np.zeros(int(RATE * (length or end + 0.05)))
    for start, sig in events:
        i = int(start * RATE)
        out[i:i + len(sig)] += sig[: len(out) - i]
    return out


def room(signal, wet=0.18, seconds=0.9):
    """Petite réverbération : bruit à décroissance exponentielle, convolué par FFT."""
    rng = np.random.default_rng(7)
    t = np.arange(int(RATE * seconds)) / RATE
    impulse = rng.standard_normal(len(t)) * np.exp(-t / 0.18)
    impulse /= np.sqrt(np.sum(impulse ** 2))
    n = len(signal) + len(impulse)
    size = 1 << (n - 1).bit_length()
    tail = np.fft.irfft(np.fft.rfft(signal, size) * np.fft.rfft(impulse, size), size)[:n]
    dry = np.concatenate([signal, np.zeros(len(impulse))])
    return dry + wet * tail


SOUNDS = {
    "rep": lambda: mix((0, bell(A5))),
    "rep5": lambda: mix((0, bell(A5)), (0.07, bell(E6, level=0.42))),
    "rep10": lambda: mix((0, bell(A5)), (0.06, bell(CS6, level=0.42)), (0.12, bell(E6, decay=0.3, level=0.42))),
    "count": lambda: mix((0, beep(E5))),
    "go": lambda: mix((0, beep(A5, 0.5, 0.3)), (0, beep(CS6, 0.5, 0.22)), (0, beep(E6, 0.5, 0.22))),
    "setEnd": lambda: mix((0, bell(E6, decay=0.25, level=0.38)), (0.16, bell(A5, decay=0.4, level=0.45))),
    "rest": lambda: mix((0, bell(A4, decay=0.1, level=0.22))),
    "finish": lambda: mix(*[(0.09 * i, bell(f, decay=0.6, level=0.36)) for i, f in enumerate([A5, CS6, E6, A6])]),
}


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


def demo_set():
    """Compte à rebours, 12 répétitions toutes les 1,7 s, fin de série, une marque de récupération."""
    events = [(i, SOUNDS["count"]()) for i in range(3)] + [(3, SOUNDS["go"]())]
    t = 4.6
    for rep in range(1, 13):
        events.append((t, SOUNDS["rep10" if rep % 10 == 0 else "rep5" if rep % 5 == 0 else "rep"]()))
        t += 1.7
    events.append((t + 2.5, SOUNDS["setEnd"]()))
    events.append((t + 6.5, SOUNDS["rest"]()))
    events.append((t + 9, SOUNDS["finish"]()))
    return mix(*events)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for name, make in SOUNDS.items():
        write_wav(os.path.join(OUT, f"{name}.wav"), room(make()))
    demo = os.path.join(OUT, "demo-serie.wav")
    write_wav(demo, room(demo_set()))
    try:
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", demo, "-c:a", "aac", "-b:a", "192k",
                        demo.replace(".wav", ".m4a")], check=True)
    except (OSError, subprocess.CalledProcessError):
        pass
    print("sons dans", OUT)

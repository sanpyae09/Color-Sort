#!/usr/bin/env python3
"""Generate the game's sound effects + soft music loop as WAV files.

No binary assets are committed to the repo: the CI workflow runs this script
before the Flutter build, so assets/sfx/ is always fresh. All sounds are
simple synthesized tones (sine/triangle + short noise bursts) mixed in pure
Python stdlib — no third-party packages needed.
"""
import math
import os
import struct
import wave

SR = 22050
OUT = "assets/sfx"


def write_wav(name, samples):
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        frames = b"".join(
            struct.pack("<h", max(-32767, min(32767, int(s * 32767))))
            for s in samples
        )
        w.writeframes(frames)
    print(f"wrote {path} ({len(samples)} samples)")


def tone(freq, dur, vol=0.5, kind="sine", slide_to=None):
    n = int(SR * dur)
    out = []
    for i in range(n):
        t = i / SR
        f = freq if slide_to is None else freq + (slide_to - freq) * (i / n)
        if kind == "sine":
            v = math.sin(2 * math.pi * f * t)
        else:  # triangle
            v = 2 * abs(2 * ((f * t) % 1) - 1) - 1
        env = min(1.0, i / (SR * 0.008)) * (1.0 - i / n)
        out.append(v * vol * env)
    return out


def knock():
    """Short wooden knock: low thump + tiny noise burst."""
    n = int(SR * 0.12)
    out = []
    for i in range(n):
        t = i / SR
        body = math.sin(2 * math.pi * 170 * t) * math.exp(-t * 40)
        click = (1.0 if i < 300 else 0.0) * 0.25 * math.exp(-t * 90)
        out.append(body * 0.8 + click)
    return out


def mix(*tracks):
    n = max(len(t) for t in tracks)
    out = [0.0] * n
    for t in tracks:
        for i, v in enumerate(t):
            out[i] += v
    peak = max(0.001, max(abs(v) for v in out))
    return [v / peak * 0.9 for v in out]


def seq(notes):
    """notes: list of (freq, dur, vol). Concatenate with tiny gaps."""
    out = []
    for freq, dur, vol in notes:
        out += tone(freq, dur, vol)
        out += [0.0] * int(SR * 0.02)
    return out


def main():
    write_wav("click.wav", tone(760, 0.06, 0.35))
    write_wav("pickup.wav", tone(420, 0.09, 0.4, slide_to=720))
    write_wav("place.wav", knock())
    write_wav("invalid.wav", tone(140, 0.14, 0.4, kind="triangle"))
    write_wav("clear.wav", seq([(660, 0.09, 0.5), (880, 0.09, 0.5), (1320, 0.14, 0.45)]))
    write_wav("combo.wav", seq([(523, 0.08, 0.5), (659, 0.08, 0.5), (784, 0.08, 0.5), (1047, 0.16, 0.5)]))
    write_wav("gameover.wav", seq([(392, 0.18, 0.45), (330, 0.18, 0.45), (262, 0.3, 0.45)]))
    write_wav("coin.wav", seq([(988, 0.07, 0.4), (1319, 0.12, 0.4)]))
    write_wav("shuffle.wav", tone(300, 0.16, 0.35, slide_to=900))
    # Soft music loop: slow C-major pad arpeggio, 16 seconds, quiet.
    pad = []
    chords = [(261.6, 329.6, 392.0), (293.7, 349.2, 440.0), (329.6, 392.0, 493.9), (293.7, 349.2, 440.0)]
    for chord in chords:
        bar = [0.0] * int(SR * 4)
        for f in chord:
            t = tone(f, 4.0, 0.12)
            for i, v in enumerate(t):
                bar[i] += v
        pad += bar
    write_wav("music.wav", pad)


if __name__ == "__main__":
    main()

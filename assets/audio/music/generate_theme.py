#!/usr/bin/env python3
"""Main gameplay theme generator — 90s SEGA arcade synth-rock (#138).

Synthesizes a seamlessly loopable 16-bar track at 138 BPM in A minor:
drum machine (kick/snare/hats/crash), FM-ish sub+saw bass on driving 8ths,
detuned power-chord stabs, 16th square arpeggio, and a heroic pulse lead
with vibrato + echo over the back half. Pure numpy — no samples.

Usage: python3 generate_theme.py [out.wav]   (then encode: ffmpeg -i out.wav -q:a 6 main_theme.ogg)
"""
import sys
import numpy as np

SR = 44100
BPM = 138.0
BEAT = 60.0 / BPM
BAR = 4 * BEAT
BARS = 16
LOOP_LEN = BARS * BAR

rng = np.random.default_rng(4213)


def t_arr(dur):
    return np.arange(int(round(dur * SR))) / SR


def env(n, a=0.004, d=0.12, s=0.55, r=0.05, dur=None):
    """ADSR over n samples; dur seconds of note before release."""
    total = n
    aN, dN, rN = int(a * SR), int(d * SR), int(r * SR)
    susN = max(0, total - aN - dN - rN)
    e = np.concatenate([
        np.linspace(0, 1, max(aN, 1)),
        np.linspace(1, s, max(dN, 1)),
        np.full(susN, s),
        np.linspace(s, 0, max(rN, 1)),
    ])
    return e[:total] if len(e) >= total else np.pad(e, (0, total - len(e)))


def midi_f(m):
    return 440.0 * 2 ** ((m - 69) / 12.0)


def saw(f, t, det=0.0):
    ph = (f * (1 + det) * t) % 1.0
    return 2.0 * ph - 1.0


def pulse(f, t, width=0.5):
    return np.where((f * t) % 1.0 < width, 1.0, -1.0)


def place(buf_l, buf_r, sig_l, sig_r, start):
    i = int(round(start * SR)) % len(buf_l)
    n = len(sig_l)
    end = i + n
    if end <= len(buf_l):
        buf_l[i:end] += sig_l
        buf_r[i:end] += sig_r
    else:  # wrap for seamless loop
        k = len(buf_l) - i
        buf_l[i:] += sig_l[:k]
        buf_r[i:] += sig_r[:k]
        buf_l[:end - len(buf_l)] += sig_l[k:]
        buf_r[:end - len(buf_r)] += sig_r[k:]


N = int(round(LOOP_LEN * SR))
L = np.zeros(N)
R = np.zeros(N)

# ---------------- Drums ----------------
def kick(start):
    t = t_arr(0.16)
    f = 150 * np.exp(-t * 28) + 45
    sig = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 22) * 1.0
    click = rng.standard_normal(len(t)) * np.exp(-t * 400) * 0.4
    s = (sig + click) * 0.9
    place(L, R, s, s, start)


def snare(start):
    t = t_arr(0.18)
    noise = rng.standard_normal(len(t)) * np.exp(-t * 26)
    body = np.sin(2 * np.pi * 190 * t) * np.exp(-t * 30) * 0.5
    s = (noise * 0.7 + body) * 0.62
    place(L, R, s * 1.0, s * 0.9, start)


def hat(start, open_=False):
    dur = 0.14 if open_ else 0.045
    t = t_arr(dur)
    noise = rng.standard_normal(len(t))
    noise = np.diff(noise, prepend=0)  # brighten
    s = noise * np.exp(-t * (28 if open_ else 90)) * 0.22
    place(L, R, s * 0.7, s * 1.0, start)


def crash(start):
    t = t_arr(1.2)
    noise = np.diff(rng.standard_normal(len(t)), prepend=0)
    s = noise * np.exp(-t * 3.2) * 0.30
    place(L, R, s, s * 0.85, start)


for bar in range(BARS):
    b0 = bar * BAR
    # rock pattern: kick 1, 2.75, 3; snare 2, 4
    for kb in (0.0, 1.75, 2.0 if bar % 4 == 3 else 2.5):
        kick(b0 + kb * BEAT)
    snare(b0 + 1 * BEAT)
    snare(b0 + 3 * BEAT)
    if bar % 4 == 3:  # fill: snare 16ths on beat 4
        for s16 in (3.25, 3.5, 3.75):
            snare(b0 + s16 * BEAT)
    for e8 in range(8):
        hat(b0 + e8 * 0.5 * BEAT, open_=(e8 == 7))
crash(0.0)
crash(8 * BAR)

# ---------------- Harmony ----------------
# 2 bars per chord: Am Am F G | Am Am F E  (midi roots)
ROOTS = [57, 57, 53, 55, 57, 57, 53, 52]  # A2.. actually A3=57
CHORD_AT = lambda bar: ROOTS[(bar // 2) % 8]

# Bass: driving 8ths, root with octave pops
for bar in range(BARS):
    root = CHORD_AT(bar) - 12  # low
    b0 = bar * BAR
    for e8 in range(8):
        note = root + (12 if e8 in (3, 7) else 0)
        f = midi_f(note)
        dur = 0.5 * BEAT * 0.92
        t = t_arr(dur)
        body = saw(f, t) * 0.5 + np.sin(2 * np.pi * f / 2 * t) * 0.6
        # FM-ish bite
        body += np.sin(2 * np.pi * f * t + 2.2 * np.sin(2 * np.pi * f * 2 * t) * np.exp(-t * 9)) * 0.35
        s = body * env(len(t), a=0.002, d=0.06, s=0.7, r=0.03) * 0.34
        place(L, R, s, s, b0 + e8 * 0.5 * BEAT)

# Power-chord stabs: offbeats (the "and" of 1 and 3), detuned saws L/R
for bar in range(BARS):
    root = CHORD_AT(bar)
    b0 = bar * BAR
    for pos in (0.5, 2.5, 3.5):
        dur = 0.32 * BEAT
        t = t_arr(dur)
        sl = np.zeros(len(t))
        sr = np.zeros(len(t))
        for iv in (0, 7, 12):
            f = midi_f(root + iv)
            sl += saw(f, t, det=-0.004)
            sr += saw(f, t, det=+0.004)
        e = env(len(t), a=0.003, d=0.10, s=0.3, r=0.04)
        place(L, R, sl * e * 0.10, sr * e * 0.10, b0 + pos * BEAT)

# Arpeggio: 16ths, root-5th-oct-5th, quiet square, ping-pong pan
for bar in range(BARS):
    root = CHORD_AT(bar) + 12
    b0 = bar * BAR
    pat = [0, 7, 12, 7]
    for s16 in range(16):
        f = midi_f(root + pat[s16 % 4])
        t = t_arr(0.25 * BEAT * 0.9)
        s = pulse(f, t, 0.25) * env(len(t), a=0.001, d=0.05, s=0.25, r=0.02) * 0.055
        pan = 0.35 + 0.3 * (s16 % 2)
        place(L, R, s * (1 - pan), s * pan, b0 + s16 * 0.25 * BEAT)

# ---------------- Lead (bars 9-16): heroic pulse melody ----------------
# events: (bar_offset_beats_from_bar9, midi, dur_beats)
MELODY = [
    (0.0, 69, 0.5), (0.5, 76, 0.5), (1.0, 79, 1.0), (2.0, 81, 1.5), (3.5, 79, 0.5),
    (4.0, 76, 1.0), (5.0, 79, 0.5), (5.5, 76, 0.5), (6.0, 74, 1.5), (7.5, 72, 0.5),
    (8.0, 69, 1.0), (9.0, 72, 0.5), (9.5, 74, 0.5), (10.0, 76, 2.0),
    (12.0, 77, 1.0), (13.0, 76, 0.5), (13.5, 74, 0.5), (14.0, 76, 1.5),  # over G: F->E->D->E
    (16.0, 81, 1.0), (17.0, 79, 0.5), (17.5, 76, 0.5), (18.0, 79, 2.0),
    (20.0, 76, 1.0), (21.0, 74, 0.5), (21.5, 72, 0.5), (22.0, 74, 1.5),
    (24.0, 72, 1.0), (25.0, 74, 0.5), (25.5, 76, 0.5), (26.0, 77, 1.0), (27.0, 79, 1.0),
    (28.0, 80, 1.5), (29.5, 76, 0.5), (30.0, 74, 0.75), (30.75, 71, 0.75), (31.5, 69, 0.5),  # over E: G# lands the V
]
lead_dry = np.zeros(N)
for beats, m, dur_b in MELODY:
    start = 8 * BAR + beats * BEAT
    dur = dur_b * BEAT * 0.96
    t = t_arr(dur)
    vib = 1 + 0.006 * np.sin(2 * np.pi * 5.5 * t) * np.minimum(t / 0.12, 1)
    f = midi_f(m)
    s = (pulse(f * 0.999, t * vib, 0.42) + pulse(f * 1.001, t * vib, 0.38)) * 0.5
    s *= env(len(t), a=0.006, d=0.08, s=0.75, r=0.06) * 0.16
    i = int(round(start * SR)) % N
    nseg = len(s)
    if i + nseg <= N:
        lead_dry[i:i + nseg] += s
    else:
        k = N - i
        lead_dry[i:] += s[:k]
        lead_dry[:nseg - k] += s[k:]

# echo: dotted-8th feedback delay, wraps the loop (seamless)
delay = int(round(0.75 * BEAT * SR))
echo = np.copy(lead_dry)
tap = lead_dry
for _ in range(3):
    tap = np.roll(tap, delay) * 0.38
    echo += tap
L += echo * 0.9
R += np.roll(echo, int(0.011 * SR)) * 1.0  # slight haas widen

# ---------------- Mix ----------------
mix = np.stack([L, R], axis=1)
mix = np.tanh(mix * 1.25)  # gentle bus saturation
mix *= 0.891 / np.max(np.abs(mix))  # -1 dBFS
out = (mix * 32767).astype(np.int16)

path = sys.argv[1] if len(sys.argv) > 1 else "/tmp/main_theme.wav"
import wave
with wave.open(path, "wb") as w:
    w.setnchannels(2)
    w.setsampwidth(2)
    w.setframerate(SR)
    w.writeframes(out.tobytes())
print(f"wrote {path}: {N/SR:.3f}s, {BARS} bars @ {BPM} BPM (seamless loop)")

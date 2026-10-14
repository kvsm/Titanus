#!/usr/bin/env python3
"""Synthesises Titanus' placeholder sound effects and synthwave music.

Run from the repo root:  python3 tools/gen_audio.py
SFX are written as 16-bit mono WAV; music is rendered to WAV and then
encoded to OGG Vorbis with ffmpeg (required for music).
Music loops seamlessly: the reverb/delay tail of each render is wrapped
around to the start of the loop.
"""
import os
import subprocess
import wave

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "audio")
SR = 32000
rng = np.random.default_rng(1234)


# ---------------------------------------------------------------- primitives

def t_axis(dur):
    return np.arange(int(dur * SR)) / SR


def midi_hz(n):
    return 440.0 * 2 ** ((n - 69) / 12)


def osc(kind, freq, dur, duty=0.5):
    """freq may be a scalar or an array (pitch sweep)."""
    n = int(dur * SR)
    f = np.broadcast_to(np.asarray(freq, dtype=float), (n,))
    phase = np.cumsum(f) / SR
    ph = phase % 1.0
    if kind == "sine":
        return np.sin(2 * np.pi * phase)
    if kind == "saw":
        return 2 * ph - 1
    if kind == "square":
        return np.where(ph < duty, 1.0, -1.0)
    if kind == "tri":
        return 4 * np.abs(ph - 0.5) - 1
    if kind == "noise":
        return rng.uniform(-1, 1, n)
    raise ValueError(kind)


def env(dur, a=0.005, d=0.1, s=0.0, r=0.05, hold=None):
    """ADSR. hold = time the note is held before release (default: dur - r)."""
    n = int(dur * SR)
    t = np.arange(n) / SR
    hold = dur - r if hold is None else hold
    e = np.empty(n)
    e[:] = s
    atk = t < a
    e[atk] = t[atk] / max(a, 1e-6)
    dec = (t >= a) & (t < a + d)
    e[dec] = 1 - (1 - s) * (t[dec] - a) / max(d, 1e-6)
    rel = t >= hold
    if rel.any():
        level = e[np.argmax(rel)] if s == 0 else s
        e[rel] = level * np.clip(1 - (t[rel] - hold) / max(r, 1e-6), 0, 1)
    return e


def exp_decay(dur, tau):
    return np.exp(-t_axis(dur) / tau)


def lowpass(x, cutoff):
    """Cheap lowpass: two passes of a moving-average box filter."""
    n = max(1, int(SR / max(cutoff, 1)))
    if n <= 1:
        return x
    k = np.ones(n) / n
    y = np.convolve(x, k, mode="same")
    return np.convolve(y, k, mode="same")


def highpass(x, cutoff):
    return x - lowpass(x, cutoff)


def add(buf, sig, at):
    i = int(at * SR)
    if i >= len(buf):
        return
    j = min(len(buf), i + len(sig))
    buf[i:j] += sig[: j - i]


def delay(x, time, feedback=0.4, taps=4, mix=0.35):
    out = x.copy()
    d = int(time * SR)
    g = mix
    for k in range(1, taps + 1):
        if d * k >= len(x):
            break
        out[d * k:] += x[: len(x) - d * k] * g
        g *= feedback
    return out


def normalize(x, peak=0.9):
    m = np.max(np.abs(x))
    return x if m == 0 else x * (peak / m)


def soft_clip(x):
    return np.tanh(x)


def write_wav(path, x):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    data = (np.clip(x, -1, 1) * 32767).astype(np.int16)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())


# ---------------------------------------------------------------- SFX

def sfx():
    S = {}
    # player shots (kept short and soft: auto-fire is constant)
    d = 0.05
    S["shot_vulcan"] = 0.25 * osc("square", np.linspace(1800, 900, int(d * SR)), d, 0.25) * exp_decay(d, 0.015)
    d = 0.09
    S["shot_wave"] = 0.3 * osc("sine", np.linspace(500, 1400, int(d * SR)), d) * env(d, 0.005, 0.08)
    d = 0.18
    S["shot_laser"] = 0.25 * (osc("saw", np.linspace(1400, 700, int(d * SR)), d) * exp_decay(d, 0.06))
    # enemy fire
    d = 0.08
    S["enemy_shot"] = 0.3 * osc("square", np.linspace(900, 300, int(d * SR)), d, 0.5) * exp_decay(d, 0.03)
    # enemy took damage
    d = 0.035
    S["hit"] = 0.35 * highpass(osc("noise", 0, d), 2000) * exp_decay(d, 0.01)
    # explosions
    d = 0.35
    n = osc("noise", 0, d)
    S["explode_small"] = 0.8 * lowpass(n, 2500) * exp_decay(d, 0.08) + 0.4 * osc("sine", np.linspace(200, 50, int(d * SR)), d) * exp_decay(d, 0.06)
    d = 1.1
    n = osc("noise", 0, d)
    S["explode_big"] = soft_clip(1.4 * (lowpass(n, 1200) * exp_decay(d, 0.3) + 0.8 * osc("sine", np.linspace(120, 30, int(d * SR)), d) * exp_decay(d, 0.25)))
    # player hurt
    d = 0.3
    S["player_hit"] = 0.5 * osc("square", np.linspace(600, 120, int(d * SR)), d, 0.5) * exp_decay(d, 0.1) + 0.3 * lowpass(osc("noise", 0, d), 3000) * exp_decay(d, 0.05)
    d = 1.4
    S["player_die"] = soft_clip(1.5 * (lowpass(osc("noise", 0, d), 900) * exp_decay(d, 0.4) + 0.6 * osc("saw", np.linspace(400, 40, int(d * SR)), d) * exp_decay(d, 0.5)))
    # pickups
    def arp(notes, step, wave="square", tail=0.12):
        total = step * len(notes) + tail
        buf = np.zeros(int(total * SR))
        for i, m in enumerate(notes):
            dd = step + tail
            add(buf, 0.3 * osc(wave, midi_hz(m), dd, 0.25) * exp_decay(dd, 0.06), i * step)
        return buf
    S["pickup"] = arp([76, 81, 88], 0.045)
    S["powerup"] = arp([69, 73, 76, 81, 85, 88, 93], 0.04)
    S["extend"] = arp([72, 76, 79, 84, 79, 84, 88], 0.07, "tri", 0.3)
    S["menu"] = arp([84], 0.03)
    S["menu_back"] = arp([79, 72], 0.04)
    # bomb: rising whoosh into a sub boom
    d = 1.6
    t = t_axis(d)
    whoosh = highpass(osc("noise", 0, d), 600) * np.clip(t / 0.25, 0, 1) * np.exp(-np.maximum(t - 0.25, 0) / 0.35)
    boom = osc("sine", 40 + 120 * np.exp(-t / 0.15), d) * np.exp(-t / 0.6)
    S["bomb"] = soft_clip(1.3 * (0.7 * whoosh + boom))
    # chain lost: descending minor sting
    S["chain_lost"] = arp([76, 72, 69, 64], 0.06, "saw", 0.25) * 0.8
    # warning siren (one cycle; the game plays it a few times)
    d = 1.0
    f = 520 + 260 * (np.sin(2 * np.pi * t_axis(d) * 1.0 - np.pi / 2) * 0.5 + 0.5)
    S["warning"] = 0.4 * (osc("saw", f, d) + osc("square", f * 1.005, d, 0.5)) * env(d, 0.02, 0.0, 1.0, 0.05)
    # boss part destroyed
    d = 0.7
    S["part_break"] = soft_clip(1.2 * (lowpass(osc("noise", 0, d), 1800) * exp_decay(d, 0.15) + osc("square", np.linspace(300, 60, int(d * SR)), d) * exp_decay(d, 0.2) * 0.4))
    S["telegraph"] = 0.25 * osc("sine", np.linspace(1200, 1800, int(0.5 * SR)), 0.5) * env(0.5, 0.05, 0.0, 1.0, 0.1)
    S["beam"] = 0.5 * lowpass(osc("saw", 55, 1.0) + osc("noise", 0, 1.0) * 0.5, 2500) * env(1.0, 0.02, 0.0, 1.0, 0.2)

    for name, x in S.items():
        write_wav(os.path.join(OUT, name + ".wav"), normalize(x, 0.8) * (0.55 if name.startswith("shot_") else 1.0))


# ---------------------------------------------------------------- music instruments

def kick(amp=1.0):
    d = 0.4
    t = t_axis(d)
    body = osc("sine", 45 + 110 * np.exp(-t / 0.03), d) * np.exp(-t / 0.18)
    click = highpass(osc("noise", 0, 0.01), 3000) * 0.3
    body[: len(click)] += click
    return amp * body


def snare(amp=1.0):
    # gated-reverb 80s snare: a crack plus a flat noise tail that is chopped off
    d = 0.32
    t = t_axis(d)
    n = highpass(osc("noise", 0, d), 900)
    crack = n * np.exp(-t / 0.04) + 0.5 * osc("tri", 190, d) * np.exp(-t / 0.05)
    gate = np.where(t < 0.24, 0.35, 0.0) * np.exp(-t / 0.5)
    return amp * (crack + lowpass(n, 6000) * gate)


def hat(amp=1.0, open_=False):
    d = 0.18 if open_ else 0.05
    return amp * highpass(osc("noise", 0, d), 6000) * exp_decay(d, 0.06 if open_ else 0.012)


def bass_note(m, dur, cutoff=900):
    x = osc("saw", midi_hz(m), dur) + 0.5 * osc("square", midi_hz(m - 12), dur)
    x = lowpass(x, cutoff)
    return 0.5 * x * env(dur, 0.003, dur * 0.6, 0.5, 0.02)


def pluck(m, dur, duty=0.25):
    return 0.22 * osc("square", midi_hz(m), dur, duty) * exp_decay(dur, 0.07)


def pad_chord(notes, dur):
    x = np.zeros(int(dur * SR))
    for m in notes:
        for det in (-0.12, 0.0, 0.12):
            x += osc("saw", midi_hz(m + det), dur)
    x = lowpass(x, 1400)
    return 0.07 * x * env(dur, 0.4, 0.0, 1.0, 0.4)


def lead_note(m, dur):
    t = t_axis(dur)
    vib = 1 + 0.006 * np.sin(2 * np.pi * 5.5 * t) * np.clip((t - 0.15) / 0.2, 0, 1)
    f = midi_hz(m) * vib
    x = osc("saw", f, dur) + 0.6 * osc("square", f * 1.003, dur, 0.5)
    x = lowpass(x, 3500)
    return 0.16 * x * env(dur, 0.01, 0.15, 0.7, 0.08)


# ---------------------------------------------------------------- songs

def render_song(name, bpm, bars, chords, bass_pattern, arp_pattern, drums, lead=None, lead_from_bar=0,
                pad=True, bass_cut=900, arp_octave=12, arp_div=4):
    beat = 60.0 / bpm
    bar = beat * 4
    L = bars * bar
    tail = 2.0
    music = np.zeros(int((L + tail) * SR))
    arp_bus = np.zeros_like(music)

    for b in range(bars):
        chord = chords[b % len(chords)]
        t0 = b * bar
        root = chord[0]
        if pad:
            add(music, pad_chord([n + 12 for n in chord], bar), t0)
        # bass in 8ths or 16ths
        steps = len(bass_pattern)
        sd = bar / steps
        for i, off in enumerate(bass_pattern):
            if off is None:
                continue
            add(music, bass_note(root - 12 + off, sd * 0.95, bass_cut), t0 + i * sd)
        # arpeggio
        if arp_pattern:
            steps = 4 * arp_div
            sd = bar / steps
            tones = [chord[0], chord[1], chord[2], chord[0] + 12]
            for i in range(steps):
                idx = arp_pattern[i % len(arp_pattern)]
                if idx is None:
                    continue
                add(arp_bus, pluck(tones[idx] + arp_octave, sd * 1.8), t0 + i * sd)
        # drums (pattern strings over 16 steps: K kick, S snare, h hat, o open hat)
        for i in range(16):
            ts = t0 + i * bar / 16
            for ch in drums[i]:
                if ch == "K":
                    add(music, kick(0.9), ts)
                elif ch == "S":
                    add(music, snare(0.55), ts)
                elif ch == "h":
                    add(music, hat(0.18), ts)
                elif ch == "o":
                    add(music, hat(0.2, True), ts)

    if lead:
        t = lead_from_bar * bar
        for m, beats in lead:
            if m is not None:
                add(music, lead_note(m, beats * beat * 0.95), t)
            t += beats * beat
            if t >= L:
                break

    music += delay(arp_bus, beat * 0.75, 0.45, 5, 0.5) + arp_bus
    # wrap the tail around so the loop point is seamless
    n = int(L * SR)
    out = music[:n].copy()
    out[: len(music) - n] += music[n:]
    out = soft_clip(normalize(out, 0.95) * 1.2) * 0.85
    wav = os.path.join(OUT, name + ".wav")
    write_wav(wav, out)
    ogg = os.path.join(OUT, name + ".ogg")
    subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", wav, "-c:a", "libvorbis", "-q:a", "4", ogg], check=True)
    os.remove(wav)
    print("rendered", name, "%.1fs" % L)


DRUMS_DRIVE = ["Kh", "h", "Kh", "h", "KSh", "h", "Kh", "h", "Kh", "h", "Kh", "h", "KSh", "h", "Kh", "o"]
DRUMS_BOSS = ["Kh", "h", "Kh", "Kh", "KSh", "h", "Kh", "h", "Kh", "h", "Kh", "Kh", "KSh", "h", "KSh", "S"]
DRUMS_TITLE = ["K", "", "h", "", "S", "", "h", "", "K", "", "h", "K", "S", "", "h", "o"]

Am, F, Cmaj, G = [57, 60, 64], [53, 57, 60], [48, 52, 55], [55, 59, 62]
Dm, Bb, Cb, A = [50, 53, 57], [46, 50, 53], [48, 52, 55], [45, 49, 52]


def songs():
    lead_drive = [
        (76, 1), (74, 1), (72, 1), (74, 1), (76, 3), (79, 1),
        (77, 1), (76, 1), (74, 1), (72, 1), (69, 4),
        (76, 1), (79, 1), (84, 1), (83, 1), (79, 3), (76, 1),
        (74, 1), (76, 1), (79, 1), (83, 1), (81, 4),
        (76, 1), (74, 1), (72, 1), (74, 1), (76, 2), (79, 2),
        (81, 2), (79, 1), (77, 1), (76, 4),
        (72, 1), (74, 1), (76, 1), (79, 1), (84, 3), (83, 1),
        (79, 2), (74, 2), (76, 4),
    ]
    render_song("neon_drive", 110, 16, [Am, Am, F, F, Cmaj, Cmaj, G, G],
                [0, 12, 0, 12, 0, 12, 0, 12], [0, 1, 2, 3, 2, 1, 0, 2], DRUMS_DRIVE,
                lead=lead_drive, lead_from_bar=8)
    lead_boss = [
        (74, 0.5), (77, 0.5), (81, 1), (79, 0.5), (77, 0.5), (76, 1), (77, 2), (None, 2),
        (70, 0.5), (74, 0.5), (77, 1), (76, 0.5), (74, 0.5), (72, 1), (74, 2), (None, 2),
        (72, 0.5), (76, 0.5), (79, 1), (77, 0.5), (76, 0.5), (74, 1), (76, 2), (None, 2),
        (73, 1), (76, 1), (79, 1), (81, 1), (85, 2), (81, 2),
    ]
    render_song("helios", 124, 16, [Dm, Dm, Bb, Bb, Cb, Cb, A, A],
                [0, 0, 12, 0, 0, 12, 0, 12, 0, 0, 12, 0, 0, 12, 0, 12], [0, 2, 1, 3, 0, 2, 1, 3], DRUMS_BOSS,
                lead=lead_boss + lead_boss, lead_from_bar=4, bass_cut=1300)
    render_song("title", 96, 8, [Am, F, Cmaj, G], [0, None, 12, None, 0, None, 12, 0],
                [0, 1, 2, 3, 2, 1, 2, 3], DRUMS_TITLE, lead=None)


Em, Cmj, Gmj, Dmj = [52, 55, 59], [48, 52, 55], [55, 59, 62], [50, 54, 57]
Cm, Ab, Bbm, Gm7 = [48, 51, 55], [44, 48, 51], [46, 50, 53], [43, 47, 50]


def sea_songs():
    lead_tide = [
        (71, 1), (74, 1), (76, 2), (74, 1), (71, 1), (69, 2),
        (67, 1), (69, 1), (71, 2), (74, 2), (76, 2),
        (79, 1), (78, 1), (76, 2), (74, 1), (71, 1), (69, 2),
        (71, 2), (74, 2), (78, 4),
        (76, 1), (74, 1), (71, 2), (67, 2), (69, 2),
        (71, 1), (72, 1), (74, 2), (76, 4),
        (79, 2), (78, 2), (76, 2), (74, 2),
        (71, 2), (69, 2), (71, 4),
    ]
    render_song("neon_tide", 104, 16, [Em, Em, Cmj, Cmj, Gmj, Gmj, Dmj, Dmj],
                [0, None, 12, 0, None, 12, 0, 7], [0, 2, 1, 3, 1, 2, 0, 3], DRUMS_DRIVE,
                lead=lead_tide, lead_from_bar=8, bass_cut=800)
    lead_lev = [
        (72, 0.5), (75, 0.5), (79, 1), (77, 0.5), (75, 0.5), (74, 1), (75, 2), (None, 2),
        (68, 0.5), (72, 0.5), (75, 1), (74, 0.5), (72, 0.5), (70, 1), (72, 2), (None, 2),
        (70, 0.5), (74, 0.5), (77, 1), (75, 0.5), (74, 0.5), (72, 1), (74, 2), (None, 2),
        (71, 1), (74, 1), (77, 1), (79, 1), (83, 2), (79, 2),
    ]
    render_song("leviathan", 128, 16, [Cm, Cm, Ab, Ab, Bbm, Bbm, Gm7, Gm7],
                [0, 0, 12, 0, 0, 12, 0, 12, 0, 0, 12, 0, 7, 12, 0, 12], [0, 2, 1, 3, 2, 0, 3, 1], DRUMS_BOSS,
                lead=lead_lev + lead_lev, lead_from_bar=4, bass_cut=1200)


def sea_sfx():
    S = {}
    d = 0.9
    t = t_axis(d)
    ping = osc("sine", 1350, d) * np.exp(-t / 0.18)
    S["sonar"] = 0.5 * delay(ping, 0.22, 0.45, 3, 0.5)
    S["mine_arm"] = np.concatenate([0.4 * osc("square", 1600, 0.06, 0.5) * exp_decay(0.06, 0.03), np.zeros(int(0.06 * SR)),
                                    0.4 * osc("square", 1600, 0.06, 0.5) * exp_decay(0.06, 0.03)])
    d = 0.45
    S["splash"] = 0.7 * lowpass(osc("noise", 0, d), 3000) * env(d, 0.01, 0.1, 0.4, 0.3)
    d = 0.35
    whoosh = highpass(osc("noise", 0, d), 1500) * np.exp(-t_axis(d) / 0.12)
    clank = osc("square", 520, d, 0.3) * np.exp(-t_axis(d) / 0.05)
    S["harpoon"] = 0.5 * whoosh + 0.3 * clank
    d = 0.6
    bub = lowpass(osc("noise", 0, d), 700) * (0.5 + 0.5 * np.sin(2 * np.pi * 18 * t_axis(d)))
    S["torpedo"] = 0.8 * bub * env(d, 0.02, 0.2, 0.5, 0.3)
    d = 1.8
    t = t_axis(d)
    f = 70 + 40 * np.sin(np.pi * t / d) + 3 * np.sin(2 * np.pi * 6 * t)
    S["whale"] = soft_clip(1.4 * lowpass(osc("saw", f, d) + 0.5 * osc("square", f * 1.5, d), 900) * env(d, 0.3, 0.0, 1.0, 0.6))
    d = 0.8
    S["geyser"] = 0.7 * lowpass(osc("noise", 0, d), 2200) * env(d, 0.05, 0.2, 0.6, 0.4)
    for name, x in S.items():
        write_wav(os.path.join(OUT, name + ".wav"), normalize(x, 0.8))


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    sfx()
    songs()
    sea_songs()
    sea_sfx()
    print("audio written to", OUT)

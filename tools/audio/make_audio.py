"""Generates ROGUEFORCE's original NES-style soundtrack, ambience and sound
effects as WAV files. Pure Python (standard library only).

    python3 tools/audio/make_audio.py assets/audio

Instruments follow the classic 8-bit arcade setup: two pulse-wave leads,
a 4-bit triangle bass and LFSR noise drums. All music here is original.
"""
import math, os, random, struct, sys, wave

SR = 32000
OUT = sys.argv[1] if len(sys.argv) > 1 else "assets/audio"
random.seed(7)


def midi_hz(n):
    return 440.0 * 2 ** ((n - 69) / 12.0)


def save(path, samples, sr=SR):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    peak = max(1e-9, max(abs(s) for s in samples))
    g = 0.89 / peak
    with wave.open(path, "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(sr)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s * g)) * 32767)) for s in samples))


# --- NES-flavoured oscillators ----------------------------------------------

class Noise:
    """15-bit LFSR noise like the NES noise channel; short=True gives metallic tone."""
    def __init__(self, short=False):
        self.reg = 1; self.short = short; self.val = 1.0; self.acc = 0.0
    def step(self, rate_hz):
        self.acc += rate_hz / SR
        while self.acc >= 1.0:
            self.acc -= 1.0
            tap = 6 if self.short else 1
            fb = (self.reg ^ (self.reg >> tap)) & 1
            self.reg = (self.reg >> 1) | (fb << 14)
            self.val = 1.0 if self.reg & 1 else -1.0
        return self.val


def pulse(phase, duty):
    return 1.0 if (phase % 1.0) < duty else -1.0


def tri4(phase):
    """4-bit stepped triangle: the gritty NES bass."""
    p = phase % 1.0
    v = 4 * p - 1 if p < 0.5 else 3 - 4 * p
    return round(v * 7.5) / 7.5


class OnePole:
    def __init__(self, cutoff):
        self.y = 0.0; self.set(cutoff)
    def set(self, cutoff):
        self.a = 1 - math.exp(-2 * math.pi * cutoff / SR)
    def __call__(self, x):
        self.y += self.a * (x - self.y); return self.y


# --- Sequencer -----------------------------------------------------------------

def render_song(bpm, bars, intro_bars=0, swing=0.0):
    """bars: list of dicts with keys lead, harm, bass, chord, drums (8 steps each)."""
    step = 60.0 / bpm / 2.0                      # eighth note
    n = int(len(bars) * 8 * step * SR) + SR // 2
    lead = [0.0] * n; harm = [0.0] * n; bass = [0.0] * n; drum = [0.0] * n

    def note_events(track):
        ev = []
        for b, bar in enumerate(bars):
            seq = bar.get(track)
            if not seq: continue
            for i, s in enumerate(seq):
                t = (b * 8 + i)
                if s == "-":
                    if ev: ev[-1][2] += 1
                elif s == ".":
                    continue
                else:
                    ev.append([t, s, 1])
        return ev

    # Lead: 25% pulse, vibrato, echo.
    for t, nt, dur in note_events("lead"):
        start = int(t * step * SR); length = int(dur * step * SR)
        f = midi_hz(nt); ph = 0.0
        for k in range(length + int(0.04 * SR)):
            i = start + k
            if i >= n: break
            tt = k / SR
            vib = 1 + (0.006 * math.sin(2 * math.pi * 5.5 * tt) if tt > 0.12 else 0)
            ph += f * vib / SR
            env = min(1, tt / 0.004) * (0.75 + 0.25 * math.exp(-tt * 8))
            if k > length: env *= max(0, 1 - (k - length) / (0.04 * SR))
            lead[i] += pulse(ph, 0.25) * env
    # Harmony: 12.5% pulse arpeggio in sixteenths over the chord.
    for b, bar in enumerate(bars):
        ch = bar.get("chord")
        if not ch: continue
        for s16 in range(16):
            nt = ch[[0, 1, 2, 1][s16 % 4]]
            start = int((b * 8 + s16 / 2) * step * SR); length = int(step / 2 * SR)
            f = midi_hz(nt); ph = 0.0
            for k in range(length):
                i = start + k
                if i >= n: break
                ph += f / SR
                env = math.exp(-k / SR * 18)
                harm[i] += pulse(ph, 0.125) * env
    # Bass: triangle, short gap between notes for drive.
    for t, nt, dur in note_events("bass"):
        start = int(t * step * SR); length = int((dur * step - 0.018) * SR)
        f = midi_hz(nt); ph = 0.0
        for k in range(max(0, length)):
            i = start + k
            if i >= n: break
            ph += f / SR
            bass[i] += tri4(ph)
    # Drums.
    nz = Noise(); nzs = Noise(short=True)
    for b, bar in enumerate(bars):
        for i, hit in enumerate(bar.get("drums", "")):
            if hit == ".": continue
            start = int((b * 8 + i) * step * SR)
            hits = [hit] if hit != "R" else ["s", "S"]       # R = 16th snare roll
            for h_i, h in enumerate(hits):
                st = start + int(h_i * step / 2 * SR)
                if h in "kK":                                 # kick: pitch-dropping triangle + click
                    ph = 0.0
                    for k in range(int(0.16 * SR)):
                        j = st + k
                        if j >= n: break
                        tt = k / SR
                        f = 45 + 160 * math.exp(-tt * 38)
                        ph += f / SR
                        drum[j] += (tri4(ph) * 1.1 * math.exp(-tt * 14) + nz.step(4000) * 0.35 * math.exp(-tt * 120))
                if h in "sS":                                 # snare: noise burst + body
                    amp = 1.0 if h == "S" else 0.6
                    ph = 0.0
                    for k in range(int(0.2 * SR)):
                        j = st + k
                        if j >= n: break
                        tt = k / SR
                        ph += 190 / SR
                        drum[j] += amp * (nz.step(11000) * 0.75 * math.exp(-tt * 16) + tri4(ph) * 0.35 * math.exp(-tt * 30))
                if h in "hk":                                 # closed hat on every h, and with soft kicks
                    for k in range(int(0.035 * SR)):
                        j = st + k
                        if j >= n: break
                        drum[j] += nzs.step(28000) * 0.22 * math.exp(-k / SR * 90)
                if h == "c":                                  # crash
                    for k in range(int(0.9 * SR)):
                        j = st + k
                        if j >= n: break
                        drum[j] += nz.step(24000) * 0.4 * math.exp(-k / SR * 4)
    # Echo on the lead (dotted-eighth delay) and gentle tone shaping.
    d = int(step * 1.5 * SR)
    for i in range(d, n):
        lead[i] += lead[i - d] * 0.28
    lp = OnePole(7000); lpb = OnePole(1800)
    out = []
    for i in range(n):
        x = 0.24 * lead[i] + 0.10 * harm[i] + 0.36 * lpb(bass[i]) + 0.42 * drum[i]
        out.append(math.tanh(lp(x) * 0.85))
    loop_start = intro_bars * 8 * step
    return out, loop_start, len(bars) * 8 * step


def bass_line(root, pattern):
    """pattern of offsets in semitones (None = hold) over 8 eighths."""
    return [root + p if p is not None else "-" for p in pattern]


GALLOP = [0, 0, 12, 0, 0, 12, 7, 12]
DRIVE = [0, 0, 0, 0, 0, 0, 0, 0]

# --- Jungle theme: A minor, 152 bpm ---------------------------------------

def jungle():
    A, F, G, D, E, C = 45, 41, 43, 38, 40, 48
    Am, Fm, Gm, Dm, Em, Em_, Cm = [57, 60, 64], [53, 57, 60], [55, 59, 62], [57, 62, 65], [56, 59, 64], [55, 59, 64], [55, 60, 64]
    beat_a = ["k", "h", "S", "h", "k", "k", "S", "h"]
    beat_b = ["k", "h", "S", "k", "k", "h", "S", "k"]
    fill = ["k", "h", "S", "h", "R", "R", "R", "R"]
    bars = []
    # intro: 2 bars of bass + drums
    bars.append({"bass": bass_line(A, GALLOP), "drums": ["k", "h", "h", "h", "k", "h", "h", "h"]})
    bars.append({"bass": bass_line(A, GALLOP), "drums": fill, "chord": Am})
    A_sec = [
        (A, Am, [76, "-", 69, "-", 72, 74, 76, "-"]),
        (A, Am, [79, "-", 76, "-", 74, 72, 74, "-"]),
        (F, Fm, [77, "-", 72, "-", 69, 72, 77, "-"]),
        (G, Gm, [79, "-", 74, "-", 71, 74, 79, 81]),
        (A, Am, [81, "-", "-", "-", 79, 76, 72, "-"]),
        (A, Am, [76, "-", 74, 72, 74, "-", 76, "-"]),
        (D, Dm, [77, "-", 74, "-", 77, "-", 81, "-"]),
        (E, Em, [80, "-", "-", "-", 76, "-", 71, 68]),
    ]
    B_sec = [
        (F, Fm, [84, "-", 81, "-", 77, "-", 81, 84]),
        (G, Gm, [86, "-", 83, "-", 79, "-", 83, 86]),
        (E, Em_, [83, "-", 79, "-", 76, "-", 79, 83]),
        (A, Am, [81, "-", "-", "-", 76, "-", 72, "-"]),
        (F, Fm, [77, 79, 81, "-", 84, "-", 81, "-"]),
        (G, Gm, [79, 81, 83, "-", 86, "-", 83, "-"]),
        (E, Em, [80, "-", 83, "-", 88, "-", 86, "-"]),
        (E, Em, [83, "-", 80, "-", 76, "-", 71, "-"]),
    ]
    for i, (r, ch, ld) in enumerate(A_sec):
        bars.append({"bass": bass_line(r, GALLOP), "chord": ch, "lead": ld, "drums": fill if i == 7 else beat_a})
    for i, (r, ch, ld) in enumerate(B_sec):
        d = ["c", "h", "S", "k", "k", "h", "S", "k"] if i == 0 else (fill if i == 7 else beat_b)
        bars.append({"bass": bass_line(r, GALLOP), "chord": ch, "lead": ld, "drums": d})
    return render_song(152, bars, intro_bars=2)


# --- Boss theme: E minor, 168 bpm, menacing --------------------------------

def boss():
    E, F, C, B = 40, 41, 36, 35
    Em, Fm, Cm, Bm = [55, 59, 64], [57, 60, 65], [55, 60, 64], [54, 59, 63]
    menace = [0, 0, 0, 1, 0, 0, 3, 2]
    beat = ["k", "h", "S", "k", "k", "k", "S", "h"]
    bars = [{"bass": bass_line(E, menace), "drums": ["R", "R", "R", "R", "R", "R", "R", "R"]}]
    sec = [
        (E, Em, [76, "-", "-", 75, 76, "-", 79, "-"]),
        (E, Em, [78, "-", 76, "-", 75, "-", 71, "-"]),
        (F, Fm, [77, "-", "-", 76, 77, "-", 81, "-"]),
        (F, Fm, [80, "-", 77, "-", 76, "-", 72, "-"]),
        (E, Em, [83, "-", 82, "-", 79, "-", 76, "-"]),
        (E, Em, [78, "-", 79, "-", 81, "-", 83, "-"]),
        (C, Cm, [84, "-", 83, "-", 79, "-", 76, "-"]),
        (B, Bm, [75, "-", 78, "-", 81, "-", 83, "-"]),
    ]
    for rep in range(2):
        for i, (r, ch, ld) in enumerate(sec):
            lead = ld if rep == 0 else [x + 12 if isinstance(x, int) and x < 80 else x for x in ld]
            d = ["c", "h", "S", "k", "k", "k", "S", "h"] if i == 0 else (["k", "h", "S", "h", "R", "R", "R", "R"] if i == 7 else beat)
            bars.append({"bass": bass_line(r, menace), "chord": ch, "lead": lead, "drums": d})
    return render_song(168, bars, intro_bars=1)


# --- Desert theme: D harmonic minor, 144 bpm ---------------------------------

def desert():
    D, Bb, A, G = 38, 46 - 12, 45, 43
    Dm, Bbm, Am, Gm = [57, 62, 65], [58, 62, 65], [57, 61, 64], [55, 58, 62]
    trot = [0, 12, 0, 12, 0, 12, 7, 12]
    beat = ["k", "h", "S", "h", "k", "h", "S", "k"]
    bars = [{"bass": bass_line(D, trot), "drums": ["k", "h", "h", "k", "k", "h", "R", "R"], "chord": Dm}]
    sec = [
        (D, Dm, [74, "-", 76, 77, 76, "-", 74, "-"]),
        (D, Dm, [73, "-", 74, "-", 77, "-", 81, "-"]),
        (Bb, Bbm, [82, "-", 81, "-", 77, "-", 74, "-"]),
        (A, Am, [81, "-", "-", "-", 79, 77, 76, 73]),
        (D, Dm, [74, "-", 77, "-", 81, "-", 86, "-"]),
        (G, Gm, [86, "-", 82, "-", 79, "-", 74, "-"]),
        (Bb, Bbm, [82, "-", 81, "-", 77, "-", 82, "-"]),
        (A, Am, [81, "-", 79, "-", 77, "-", 73, "-"]),
    ]
    for rep in range(2):
        for i, (r, ch, ld) in enumerate(sec):
            d = ["c", "h", "S", "h", "k", "h", "S", "k"] if (i == 0 and rep == 1) else (["k", "h", "S", "h", "R", "R", "R", "R"] if i == 7 else beat)
            bars.append({"bass": bass_line(r, trot), "chord": ch, "lead": ld, "drums": d})
    return render_song(144, bars, intro_bars=1)


def victory():
    C = 36
    bars = [
        {"lead": [67, 72, 76, 79, "-", "-", 76, 79], "bass": bass_line(C, [0, 0, 12, 0, 0, 12, 7, 12]), "chord": [60, 64, 67], "drums": ["k", "h", "S", "h", "R", "R", "R", "R"]},
        {"lead": [84, "-", "-", "-", "-", "-", "-", "-"], "bass": [C + 12, "-", "-", "-", "-", "-", "-", "-"], "chord": [60, 64, 67], "drums": ["c", ".", ".", ".", ".", ".", ".", "."]},
    ]
    return render_song(140, bars)


# --- Sound effects -------------------------------------------------------------

def env_exp(t, rate):
    return math.exp(-t * rate)


def sfx_shot():
    out = []; nz = Noise(); lp = OnePole(9000); ph = 0
    for k in range(int(0.11 * SR)):
        t = k / SR
        lp.set(9000 * math.exp(-t * 22) + 600)
        ph += (180 * math.exp(-t * 30) + 60) / SR
        out.append(lp(nz.step(30000)) * env_exp(t, 30) * 1.2 + tri4(ph) * env_exp(t, 40) * 0.9)
    return out


def sfx_enemy_shot():
    out = []; ph = 0; nz = Noise()
    for k in range(int(0.09 * SR)):
        t = k / SR
        ph += (1100 * math.exp(-t * 25) + 250) / SR
        out.append(pulse(ph, 0.5) * env_exp(t, 28) * 0.6 + nz.step(20000) * env_exp(t, 60) * 0.3)
    return out


def sfx_laser():
    out = []; ph = 0
    for k in range(int(0.22 * SR)):
        t = k / SR
        f = 2400 * math.exp(-t * 14) + 200 + 60 * math.sin(t * 2 * math.pi * 40)
        ph += f / SR
        out.append(pulse(ph, 0.25) * env_exp(t, 9) * 0.8)
    return out


def sfx_explosion(length=1.1, boom=1.0):
    out = []; nz = Noise(); lp = OnePole(4000); ph = 0
    for k in range(int(length * SR)):
        t = k / SR
        lp.set(3500 * math.exp(-t * 4) + 120)
        ph += (75 * math.exp(-t * 3) + 28) / SR
        crackle = nz.step(6000 * math.exp(-t * 2) + 800)
        x = lp(crackle) * env_exp(t, 3.2) * 1.4 + math.sin(2 * math.pi * ph) * env_exp(t, 4.5) * boom
        out.append(math.tanh(x * 1.8))
    return out


def sfx_hit():
    out = []; nz = Noise(short=True); ph = 0
    for k in range(int(0.07 * SR)):
        t = k / SR
        ph += 160 / SR
        out.append(nz.step(16000) * env_exp(t, 45) * 0.8 + tri4(ph) * env_exp(t, 50))
    return out


def sfx_ping():
    out = []
    for k in range(int(0.22 * SR)):
        t = k / SR
        out.append((math.sin(2 * math.pi * 2350 * t) + 0.7 * math.sin(2 * math.pi * 3710 * t) + 0.4 * math.sin(2 * math.pi * 5230 * t)) * env_exp(t, 22) * (1 if t > 0.001 else 0))
    return out


def sfx_hurt():
    out = []; ph = 0; nz = Noise()
    for k in range(int(0.35 * SR)):
        t = k / SR
        ph += (600 * math.exp(-t * 6) + 90) / SR
        out.append(pulse(ph, 0.5) * env_exp(t, 7) * 0.7 + nz.step(9000) * env_exp(t, 25) * 0.4)
    return out


def sfx_death():
    out = []
    notes = [76, 72, 69, 64, 60, 57, 52]
    for i, n in enumerate(notes):
        ph = 0
        for k in range(int(0.09 * SR)):
            t = k / SR
            ph += midi_hz(n) / SR
            out.append(pulse(ph, 0.5) * env_exp(t, 10) * 0.8)
    return out + sfx_explosion(0.6, 0.6)


def sfx_pickup():
    out = []
    for n in [72, 76, 79, 84, 88, 91]:
        ph = 0
        for k in range(int(0.055 * SR)):
            ph += midi_hz(n) / SR
            out.append(pulse(ph, 0.25) * 0.7 * env_exp(k / SR, 6))
    return out


def sfx_checkpoint():
    out = []
    for n, d in [(79, 0.09), (84, 0.25)]:
        ph = 0
        for k in range(int(d * SR)):
            ph += midi_hz(n) / SR
            out.append(pulse(ph, 0.25) * 0.7 * env_exp(k / SR, 5))
    return out


def sfx_jump():
    out = []; ph = 0
    for k in range(int(0.09 * SR)):
        t = k / SR
        ph += (220 + 900 * t / 0.09) / SR
        out.append(pulse(ph, 0.5) * env_exp(t, 18) * 0.35)
    return out


def sfx_boss_warning():
    out = []; ph = 0
    for k in range(int(2.2 * SR)):
        t = k / SR
        f = 620 + 260 * (1 if (t * 3) % 1 < 0.5 else 0)
        ph += f / SR
        gate = 1.0 if (t * 3) % 0.5 < 0.42 else 0.0
        out.append((pulse(ph, 0.5) * 0.6 + pulse(ph * 1.005, 0.25) * 0.4) * gate * min(1, t * 20) * (1 - t / 2.4))
    return out


# --- Ambience (seamless loops) ---------------------------------------------------

def crossfade_loop(x, fade):
    n = len(x) - fade
    return [x[i] * (1 if i >= fade else i / fade) + (x[n + i] * (1 - i / fade) if i < fade else 0) for i in range(n)]


def amb_rain(seconds=8):
    nz = Noise(); lp = OnePole(5000); hp_prev = 0.0; out = []
    drops = set(random.randrange(int(seconds * SR)) for _ in range(int(seconds * 30)))
    drop_t = -1
    for k in range(int((seconds + 1) * SR)):
        x = lp(nz.step(SR * 0.9))
        y = x - hp_prev * 0.97; hp_prev = x
        if k in drops: drop_t = 0
        d = 0.0
        if drop_t >= 0:
            d = math.sin(2 * math.pi * 1800 * drop_t / SR) * math.exp(-drop_t / SR * 120) * 0.6
            drop_t += 1
            if drop_t > SR * 0.05: drop_t = -1
        out.append(y * 0.5 + d)
    return crossfade_loop(out, SR)


def amb_wind(seconds=8):
    nz = Noise(); lp = OnePole(400); out = []
    for k in range(int((seconds + 1) * SR)):
        t = k / SR
        lp.set(250 + 350 * (0.5 + 0.5 * math.sin(2 * math.pi * t / (seconds + 1) * 2)))
        out.append(lp(nz.step(SR * 0.9)) * (0.6 + 0.4 * math.sin(2 * math.pi * t / 3.1)))
    return crossfade_loop(out, SR)


if __name__ == "__main__":
    loops = {}
    for name, fn in [("jungle", jungle), ("boss", boss), ("desert", desert), ("victory", victory)]:
        samples, loop_start, _ = fn()
        save(os.path.join(OUT, "music", name + ".wav"), samples)
        loops[name] = round(loop_start, 4)
        print("music", name, round(len(samples) / SR, 1), "s, loop from", loops[name])
    for name, fn in [("shot", sfx_shot), ("enemy_shot", sfx_enemy_shot), ("laser", sfx_laser), ("explosion", sfx_explosion),
                     ("hit", sfx_hit), ("ping", sfx_ping), ("hurt", sfx_hurt), ("death", sfx_death), ("pickup", sfx_pickup),
                     ("checkpoint", sfx_checkpoint), ("jump", sfx_jump), ("boss_warning", sfx_boss_warning)]:
        save(os.path.join(OUT, "sfx", name + ".wav"), fn())
    save(os.path.join(OUT, "ambience", "jungle_rain.wav"), amb_rain())
    save(os.path.join(OUT, "ambience", "desert_wind.wav"), amb_wind())
    print("loops", loops)

// Everything you hear is synthesized on the fly with WebAudio: no audio files.
const NOTE = (n) => 440 * Math.pow(2, (n - 69) / 12);

export class GameAudio {
  constructor() {
    this.ctx = null; this.ready = false;
    this.muted = false; this.volume = 0.8;
    this.loops = {};
    this.musicMode = 'off'; this.wantMusic = 'off';
    this.step = 0; this.nextTime = 0; this.timer = null;
    this.last = {};
  }

  /** Must be called from a user gesture. */
  init() {
    if (this.ctx) { if (this.ctx.state === 'suspended') this.ctx.resume(); return; }
    const AC = window.AudioContext || window.webkitAudioContext;
    if (!AC) return;
    try {
      const ctx = this.ctx = new AC();
      this.master = ctx.createGain(); this.master.gain.value = this.muted ? 0 : this.volume;
      const comp = ctx.createDynamicsCompressor();
      comp.threshold.value = -14; comp.knee.value = 18; comp.ratio.value = 5; comp.attack.value = 0.004; comp.release.value = 0.2;
      this.master.connect(comp); comp.connect(ctx.destination);
      this.sfx = ctx.createGain(); this.sfx.gain.value = 0.9; this.sfx.connect(this.master);
      this.mus = ctx.createGain(); this.mus.gain.value = 0.42; this.mus.connect(this.master);
      // small synthetic hall
      const len = Math.floor(ctx.sampleRate * 1.6), ir = ctx.createBuffer(2, len, ctx.sampleRate);
      for (let c = 0; c < 2; c++) { const d = ir.getChannelData(c); for (let i = 0; i < len; i++) d[i] = (Math.random() * 2 - 1) * Math.pow(1 - i / len, 2.6); }
      this.verb = ctx.createConvolver(); this.verb.buffer = ir;
      const vg = ctx.createGain(); vg.gain.value = 0.22; this.verb.connect(vg); vg.connect(this.master);
      this.send = ctx.createGain(); this.send.gain.value = 1; this.send.connect(this.verb);
      const nl = ctx.sampleRate * 2; this.noiseBuf = ctx.createBuffer(1, nl, ctx.sampleRate);
      const nd = this.noiseBuf.getChannelData(0); for (let i = 0; i < nl; i++) nd[i] = Math.random() * 2 - 1;
      // crowd bed
      const crowd = ctx.createBufferSource(); crowd.buffer = this.noiseBuf; crowd.loop = true;
      const cf = ctx.createBiquadFilter(); cf.type = 'bandpass'; cf.frequency.value = 900; cf.Q.value = 0.45;
      this.crowdGain = ctx.createGain(); this.crowdGain.gain.value = 0;
      crowd.connect(cf); cf.connect(this.crowdGain); this.crowdGain.connect(this.master); crowd.start();
      this.crowdFilter = cf;
      this.ready = true;
      this.timer = setInterval(() => this._schedule(), 40);
      this.music(this.wantMusic);
    } catch (e) { this.ready = false; }
  }

  setMuted(m) { this.muted = m; if (this.master) this.master.gain.setTargetAtTime(m ? 0 : this.volume, this.ctx.currentTime, 0.05); }
  suspend(on) { if (this.ctx) { if (on) this.ctx.suspend(); else this.ctx.resume(); } }

  crowd(level) { if (this.ready) this.crowdGain.gain.setTargetAtTime(level * 0.05, this.ctx.currentTime, 0.6); }
  cheer(amount = 1) {
    if (!this.ready) return;
    const t = this.ctx.currentTime, g = this.crowdGain.gain, base = Math.max(0.0001, g.value);
    g.cancelScheduledValues(t); g.setValueAtTime(base, t); g.linearRampToValueAtTime(Math.min(0.22, base + 0.1 * amount), t + 0.25); g.setTargetAtTime(0.05, t + 0.5, 0.9);
    this.crowdFilter.frequency.setValueAtTime(1500, t); this.crowdFilter.frequency.setTargetAtTime(900, t + 0.4, 0.8);
  }

  // ---- primitives
  _tone(type, f0, f1, dur, vol, { at = 0, attack = 0.004, dest = null, wet = 0, curve = 'exp' } = {}) {
    const ctx = this.ctx, t = ctx.currentTime + at;
    const o = ctx.createOscillator(), g = ctx.createGain();
    o.type = type; o.frequency.setValueAtTime(Math.max(1, f0), t);
    if (f1 !== f0) { if (curve === 'exp') o.frequency.exponentialRampToValueAtTime(Math.max(1, f1), t + dur); else o.frequency.linearRampToValueAtTime(f1, t + dur); }
    g.gain.setValueAtTime(0.0001, t); g.gain.linearRampToValueAtTime(vol, t + attack); g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
    o.connect(g); g.connect(dest || this.sfx);
    if (wet) { const w = ctx.createGain(); w.gain.value = wet; g.connect(w); w.connect(this.send); }
    o.start(t); o.stop(t + dur + 0.02);
    return g;
  }

  _noise(ftype, f0, f1, dur, vol, { at = 0, q = 1, attack = 0.004, dest = null, wet = 0 } = {}) {
    const ctx = this.ctx, t = ctx.currentTime + at;
    const s = ctx.createBufferSource(); s.buffer = this.noiseBuf; s.loop = true;
    const f = ctx.createBiquadFilter(); f.type = ftype; f.Q.value = q;
    f.frequency.setValueAtTime(Math.max(20, f0), t); if (f1 !== f0) f.frequency.exponentialRampToValueAtTime(Math.max(20, f1), t + dur);
    const g = ctx.createGain();
    g.gain.setValueAtTime(0.0001, t); g.gain.linearRampToValueAtTime(vol, t + attack); g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
    s.connect(f); f.connect(g); g.connect(dest || this.sfx);
    if (wet) { const w = ctx.createGain(); w.gain.value = wet; g.connect(w); w.connect(this.send); }
    s.start(t, Math.random() * 1.5); s.stop(t + dur + 0.02);
  }

  play(name, opts = {}) {
    if (!this.ready || this.muted) return;
    const now = this.ctx.currentTime;
    if (this.last[name] && now - this.last[name] < 0.025) return;   // don't stack identical hits in one frame
    this.last[name] = now;
    const T = (...a) => this._tone(...a), N = (...a) => this._noise(...a), r = (a, b) => a + Math.random() * (b - a);
    switch (name) {
      case 'swing': N('bandpass', r(700, 1000), r(2400, 3200), 0.14, 0.26, { q: 1.4 }); break;
      case 'swingHeavy': N('bandpass', 260, 1300, 0.28, 0.4, { q: 1.1 }); T('sine', 110, 60, 0.25, 0.25); break;
      case 'hit': N('lowpass', 3800, 500, 0.12, 0.55); T('sine', r(170, 200), 70, 0.12, 0.6); T('square', 1300, 600, 0.03, 0.12); break;
      case 'hitHeavy': N('lowpass', 5200, 260, 0.26, 0.8, { wet: 0.4 }); T('sine', 150, 38, 0.32, 0.9); T('sawtooth', 320, 80, 0.12, 0.25); break;
      case 'block': T('triangle', r(1700, 2000), 1400, 0.08, 0.3); T('square', 2700, 2300, 0.05, 0.1); N('highpass', 4200, 4200, 0.05, 0.2); break;
      case 'parry': T('sine', 2350, 2350, 0.55, 0.32, { wet: 0.7 }); T('sine', 3520, 3520, 0.4, 0.2, { wet: 0.7 }); N('highpass', 5000, 5000, 0.08, 0.3); T('sine', 220, 90, 0.2, 0.4); break;
      case 'shot': T('sawtooth', r(1300, 1500), 300, 0.11, 0.2); N('bandpass', 2600, 1200, 0.06, 0.22, { q: 0.8 }); break;
      case 'dash': N('bandpass', 500, 3600, 0.18, 0.24, { q: 0.9 }); break;
      case 'whoosh': N('bandpass', 300, 2600, 0.45, 0.3, { q: 0.8, attack: 0.1 }); break;
      case 'step': N('lowpass', 800, 400, 0.045, 0.07); break;
      case 'land': T('sine', 120, 48, 0.16, 0.5); N('lowpass', 700, 200, 0.14, 0.3); break;
      case 'guardUp': T('triangle', 520, 760, 0.05, 0.08); break;
      case 'special': T('sawtooth', 280, 920, 0.2, 0.2, { wet: 0.4 }); T('sine', 620, 1240, 0.22, 0.25, { wet: 0.4 }); break;
      case 'charge': T('sawtooth', 110, 880, 0.9, 0.16, { attack: 0.3, wet: 0.5 }); T('sine', 220, 1760, 0.9, 0.18, { attack: 0.3, wet: 0.5 }); N('bandpass', 400, 5000, 0.9, 0.18, { attack: 0.4, q: 2 }); break;
      case 'explosion': N('lowpass', opts.big ? 6000 : 4200, 70, opts.big ? 1.4 : 0.9, 0.95, { wet: 0.6 }); T('sine', 95, 26, opts.big ? 1.1 : 0.8, 1.0); T('sawtooth', 180, 40, 0.3, 0.3); break;
      case 'strike': N('lowpass', 6500, 200, 0.3, 0.6, { wet: 0.4 }); T('sine', 210, 48, 0.3, 0.7); T('sine', 1800, 900, 0.1, 0.12); break;
      case 'telegraph': T('sine', 900, 900, 0.07, 0.09); break;
      case 'quake': T('sine', 72, 32, 0.45, 0.8); N('lowpass', 320, 90, 0.4, 0.5); break;
      case 'barrier': T('triangle', 340, 190, 0.22, 0.3, { wet: 0.5 }); N('bandpass', 1900, 900, 0.2, 0.2, { q: 3 }); break;
      case 'ko': T('sine', 320, 36, 1.3, 0.8, { wet: 0.6 }); N('lowpass', 3000, 90, 1.2, 0.5, { wet: 0.6 }); break;
      case 'shatter': for (let i = 0; i < 12; i++) T('sine', r(1800, 6200), r(1500, 5000), r(0.15, 0.5), 0.09, { at: r(0, 0.25), wet: 0.8 }); N('highpass', 5200, 3000, 0.35, 0.3); break;
      case 'uiMove': T('triangle', 720, 720, 0.04, 0.08); break;
      case 'uiOk': T('triangle', 880, 880, 0.07, 0.12); T('triangle', 1320, 1320, 0.1, 0.12, { at: 0.06 }); break;
      case 'uiBack': T('triangle', 520, 360, 0.1, 0.1); break;
      case 'text': T('square', r(880, 980), 880, 0.018, 0.025); break;
      case 'deny': T('square', 180, 150, 0.14, 0.1); break;
      case 'levelUp': [72, 76, 79, 84].forEach((n, i) => T('triangle', NOTE(n), NOTE(n), 0.3, 0.16, { at: i * 0.09, wet: 0.6 })); break;
      case 'rankUp': [67, 72, 76, 79, 84, 88].forEach((n, i) => { T('sawtooth', NOTE(n), NOTE(n), 0.5, 0.07, { at: i * 0.11, wet: 0.7 }); T('triangle', NOTE(n + 12), NOTE(n + 12), 0.5, 0.1, { at: i * 0.11, wet: 0.7 }); }); break;
      case 'round': T('sine', 196, 196, 1.4, 0.4, { wet: 0.8 }); T('sine', 293.7, 293.7, 1.1, 0.25, { wet: 0.8 }); T('sine', 494, 494, 0.7, 0.12, { wet: 0.8 }); N('bandpass', 2400, 1800, 0.3, 0.12, { q: 4 }); break;
      case 'fight': [50, 57, 62, 65].forEach((n) => T('sawtooth', NOTE(n), NOTE(n), 0.45, 0.11, { wet: 0.5 })); N('highpass', 3000, 6000, 0.2, 0.2); T('sine', 140, 50, 0.3, 0.6); break;
      case 'win': [62, 66, 69, 74, 78].forEach((n, i) => T('triangle', NOTE(n), NOTE(n), 0.7, 0.13, { at: i * 0.12, wet: 0.7 })); break;
      case 'lose': [62, 60, 57, 53].forEach((n, i) => T('triangle', NOTE(n), NOTE(n), 0.7, 0.12, { at: i * 0.2, wet: 0.7 })); break;
      default: break;
    }
  }

  startLoop(name) {
    if (!this.ready || this.loops[name]) return;
    const ctx = this.ctx, t = ctx.currentTime, g = ctx.createGain();
    g.gain.setValueAtTime(0.0001, t); g.gain.linearRampToValueAtTime(0.3, t + 0.08);
    const f = ctx.createBiquadFilter(); f.type = 'lowpass'; f.frequency.value = 2400;
    const nodes = [];
    for (const [type, freq] of [['sawtooth', 110], ['sawtooth', 112.4], ['square', 55], ['sawtooth', 331]]) {
      const o = ctx.createOscillator(); o.type = type; o.frequency.value = freq; o.connect(f); o.start(t); nodes.push(o);
    }
    const lfo = ctx.createOscillator(), lg = ctx.createGain(); lfo.frequency.value = 23; lg.gain.value = 700; lfo.connect(lg); lg.connect(f.frequency); lfo.start(t); nodes.push(lfo);
    f.connect(g); g.connect(this.sfx);
    this.loops[name] = { g, nodes };
  }

  stopLoop(name) {
    const l = this.loops[name];
    if (!l) return;
    const t = this.ctx.currentTime;
    l.g.gain.cancelScheduledValues(t); l.g.gain.setTargetAtTime(0.0001, t, 0.05);
    for (const n of l.nodes) n.stop(t + 0.3);
    delete this.loops[name];
  }

  // ---- music: a tiny step sequencer
  music(mode) {
    this.wantMusic = mode;
    if (!this.ready || this.musicMode === mode) return;
    this.musicMode = mode; this.step = 0; this.nextTime = this.ctx.currentTime + 0.08;
    this.mus.gain.setTargetAtTime(mode === 'fight' ? 0.4 : 0.34, this.ctx.currentTime, 0.3);
  }

  _schedule() {
    if (!this.ready || this.musicMode === 'off' || this.muted || this.ctx.state !== 'running') return;
    const song = SONGS[this.musicMode];
    if (!song) return;
    const stepDur = 60 / song.bpm / 4;
    if (this.nextTime < this.ctx.currentTime - 0.5) this.nextTime = this.ctx.currentTime + 0.05;
    while (this.nextTime < this.ctx.currentTime + 0.14) {
      this._playStep(song, this.step, this.nextTime - this.ctx.currentTime, stepDur);
      this.step++; this.nextTime += stepDur;
    }
  }

  _playStep(song, step, at, sd) {
    const s = step % 16, bar = Math.floor(step / 16), chord = song.chords[bar % song.chords.length];
    const D = this.mus, T = (type, n, dur, vol, o = {}) => this._tone(type, NOTE(n), NOTE(n), dur, vol, { at, dest: D, ...o });
    const phrase = Math.floor(bar / song.chords.length) % 4;
    if (song.kick && song.kick[s] === 'x') { this._tone('sine', 150, 42, 0.22, 0.75, { at, dest: D }); }
    if (song.snare && song.snare[s] === 'x') { this._noise('bandpass', 1900, 1500, 0.14, 0.32, { at, dest: D, q: 0.7, wet: 0.3 }); this._tone('triangle', 240, 150, 0.08, 0.22, { at, dest: D }); }
    if (song.hat && song.hat[s] !== '.') this._noise('highpass', 7500, 7500, song.hat[s] === 'o' ? 0.12 : 0.035, song.hat[s] === 'o' ? 0.09 : 0.06, { at, dest: D });
    if (song.bass && song.bass[s] !== '.') {
      const n = chord[0] - 24 + (song.bass[s] === 'o' ? 12 : 0);
      const g = this._tone('sawtooth', NOTE(n), NOTE(n), sd * 1.7, 0.2, { at, dest: D });
      this._tone('sine', NOTE(n), NOTE(n), sd * 1.9, 0.3, { at, dest: D });
      void g;
    }
    if (s === 0) for (const n of chord) { T('sawtooth', n - 12, sd * 15.5, song.pad * 0.5, { attack: sd * 3, wet: 0.5 }); T('triangle', n, sd * 15.5, song.pad, { attack: sd * 3, wet: 0.5 }); }
    if (song.arp && song.arp[s] !== '.' && (phrase > 0 || song.arpAlways)) {
      const idx = '0123456789'.indexOf(song.arp[s]);
      const n = chord[idx % chord.length] + 12 * Math.floor(idx / chord.length) + (song.arpUp || 0);
      T(song.arpWave || 'square', n, sd * 1.4, song.arpVol, { wet: 0.6 });
    }
    if (song.lead && phrase >= 2) {
      const L = song.lead[(bar % song.chords.length)];
      const ch = L[s];
      if (ch && ch !== '.') { const n = chord[0] + 12 + parseInt(ch, 16); T('sawtooth', n, sd * 2.6, 0.06, { wet: 0.7, attack: 0.02 }); T('triangle', n + 12, sd * 2.6, 0.05, { wet: 0.7 }); }
    }
  }
}

// chords as MIDI notes
const SONGS = {
  fight: {
    bpm: 148, chords: [[62, 65, 69, 72], [58, 62, 65, 69], [60, 64, 67, 72], [57, 60, 64, 69]],
    kick: 'x...x...x...x.x.', snare: '....x.......x...', hat: 'x.x.x.x.x.x.x.xo', bass: 'x.xox.x.x.xox.xo',
    arp: '0.1.2.3.2.1.4.2.', arpVol: 0.045, arpWave: 'square', arpAlways: false, pad: 0.035,
    lead: ['0...3...5...7.5.', '7...5...3...2...', '0...4...7...9.7.', '7...5...4...0...'],
  },
  hub: {
    bpm: 92, chords: [[65, 69, 72, 76], [64, 67, 71, 74], [62, 65, 69, 72], [60, 64, 67, 71]],
    hat: '..x...x...x...x.', bass: 'x.......x.....x.', kick: 'x.........x.....',
    arp: '0.2.1.3.2.4.3.1.', arpVol: 0.05, arpWave: 'triangle', arpAlways: true, arpUp: 12, pad: 0.05,
  },
  menu: {
    bpm: 80, chords: [[62, 65, 69, 76], [58, 62, 65, 74], [53, 60, 65, 69], [60, 64, 67, 74]],
    bass: 'x...............', arp: '0...2...3...1...', arpVol: 0.06, arpWave: 'triangle', arpAlways: true, arpUp: 12, pad: 0.06,
  },
  trial: {
    bpm: 160, chords: [[57, 60, 64, 69], [53, 57, 60, 65], [55, 59, 62, 67], [52, 56, 59, 64]],
    kick: 'x..xx...x..xx.x.', snare: '....x.......x..x', hat: 'xxxxxxxxxxxxxxxo', bass: 'xxoxx.xoxxoxx.xo',
    arp: '0312031204130413', arpVol: 0.04, arpWave: 'square', arpAlways: true, pad: 0.035,
    lead: ['0.....3.5...7...', '7.....5.3...0...', '0.....4.7...b...', '9.....7.4...0...'],
  },
};

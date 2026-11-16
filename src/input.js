// Keyboard, mouse, touch and gamepad folded into one small state object.
const KEY_ACTIONS = {
  KeyJ: 'light', KeyK: 'special', Space: 'dash', KeyI: 'ult', KeyQ: 'ult', KeyE: 'interact', Enter: 'confirm',
  Escape: 'pause', KeyP: 'pause', KeyR: 'register', KeyT: 'training',
};
const AXIS_KEYS = { KeyW: [0, 1], ArrowUp: [0, 1], KeyS: [0, -1], ArrowDown: [0, -1], KeyA: [-1, 0], ArrowLeft: [-1, 0], KeyD: [1, 0], ArrowRight: [1, 0] };

export class Input {
  constructor(stage) {
    this.x = 0; this.y = 0; this.guard = false;
    this.lookX = 0;                      // accumulated camera-drag (explore mode)
    this.mode = 'menu';                  // 'duel' | 'explore' | 'menu'
    this.pressed = new Set();
    this.keys = new Set();
    this.touch = { x: 0, y: 0, guard: false, active: false };
    this.pad = { x: 0, y: 0, guard: false, prev: [] };
    this.usingTouch = false;
    this.lastDevice = 'keyboard';
    this.onDevice = null;

    window.addEventListener('keydown', (e) => {
      if (e.repeat) { if (AXIS_KEYS[e.code] || e.code === 'Space') e.preventDefault(); return; }
      this.keys.add(e.code);
      const a = KEY_ACTIONS[e.code];
      if (a) this.pressed.add(a);
      if (e.code === 'Enter' || e.code === 'Space') this.pressed.add('advance');
      if (AXIS_KEYS[e.code] || e.code === 'Space') e.preventDefault();
      this.device('keyboard');
    });
    window.addEventListener('keyup', (e) => this.keys.delete(e.code));
    window.addEventListener('blur', () => { this.keys.clear(); this.touch.guard = false; });

    // mouse: attack buttons in a duel, drag to look around the campus
    let drag = null;
    stage.addEventListener('contextmenu', (e) => e.preventDefault());
    stage.addEventListener('pointerdown', (e) => {
      this.pressed.add('advance');            // tapping the scene also advances dialogue
      if (e.pointerType === 'touch') {
        this.setTouch(true);
        if (this.mode === 'explore' && e.clientX > window.innerWidth * 0.45) drag = { id: e.pointerId, x: e.clientX };
        return;
      }
      this.device('keyboard');
      if (this.mode === 'duel') { if (e.button === 0) this.pressed.add('light'); else if (e.button === 2) this.pressed.add('special'); }
      else if (this.mode === 'explore') drag = { id: e.pointerId, x: e.clientX };
    });
    window.addEventListener('pointermove', (e) => { if (drag && e.pointerId === drag.id) { this.lookX += e.clientX - drag.x; drag.x = e.clientX; } });
    window.addEventListener('pointerup', (e) => { if (drag && e.pointerId === drag.id) drag = null; });
    window.addEventListener('pointercancel', () => { drag = null; });

    this._bindTouch();
    if (window.matchMedia && window.matchMedia('(pointer: coarse)').matches) this.setTouch(true);
  }

  device(d) { if (this.lastDevice !== d) { this.lastDevice = d; if (this.onDevice) this.onDevice(d); } }

  setTouch(on) {
    if (this.usingTouch === on) return;
    this.usingTouch = on;
    document.documentElement.classList.toggle('touch', on);
    if (on) this.device('touch');
  }

  _bindTouch() {
    const zone = document.getElementById('stick'), knob = document.getElementById('stickKnob'), base = document.getElementById('stickBase');
    if (zone) {
      let id = null, ox = 0, oy = 0;
      const R = 52;
      const end = () => { id = null; this.touch.x = this.touch.y = 0; this.touch.active = false; zone.classList.remove('on'); };
      zone.addEventListener('pointerdown', (e) => {
        this.setTouch(true);
        id = e.pointerId; ox = e.clientX; oy = e.clientY;
        zone.setPointerCapture(id);
        const r = zone.getBoundingClientRect();
        base.style.left = `${ox - r.left}px`; base.style.top = `${oy - r.top}px`;
        knob.style.transform = 'translate(-50%, -50%)';
        zone.classList.add('on'); this.touch.active = true;
        e.preventDefault();
      });
      zone.addEventListener('pointermove', (e) => {
        if (e.pointerId !== id) return;
        let dx = e.clientX - ox, dy = e.clientY - oy;
        const l = Math.hypot(dx, dy);
        if (l > R) { dx *= R / l; dy *= R / l; }
        this.touch.x = dx / R; this.touch.y = -dy / R;
        knob.style.transform = `translate(calc(-50% + ${dx}px), calc(-50% + ${dy}px))`;
      });
      zone.addEventListener('pointerup', (e) => { if (e.pointerId === id) end(); });
      zone.addEventListener('pointercancel', end);
    }
    for (const el of document.querySelectorAll('[data-act]')) {
      const act = el.dataset.act;
      el.addEventListener('pointerdown', (e) => {
        e.preventDefault(); this.setTouch(e.pointerType === 'touch' || this.usingTouch);
        el.classList.add('down');
        if (act === 'guard') this.touch.guard = true; else this.pressed.add(act);
      });
      const up = () => { el.classList.remove('down'); if (act === 'guard') this.touch.guard = false; };
      el.addEventListener('pointerup', up); el.addEventListener('pointercancel', up); el.addEventListener('pointerleave', up);
      el.addEventListener('contextmenu', (e) => e.preventDefault());
    }
  }

  /** True once per press. */
  take(name) { if (this.pressed.has(name)) { this.pressed.delete(name); return true; } return false; }
  clear() { this.pressed.clear(); this.lookX = 0; }

  update() {
    let kx = 0, ky = 0;
    for (const code of this.keys) { const a = AXIS_KEYS[code]; if (a) { kx += a[0]; ky += a[1]; } }
    kx = Math.max(-1, Math.min(1, kx)); ky = Math.max(-1, Math.min(1, ky));
    // gamepad
    const p = this.pad; p.x = p.y = 0; p.guard = false;
    const pads = navigator.getGamepads ? navigator.getGamepads() : [];
    for (const g of pads) {
      if (!g || !g.connected) continue;
      const ax = g.axes[0] || 0, ay = g.axes[1] || 0;
      if (Math.hypot(ax, ay) > 0.22) { p.x = ax; p.y = -ay; this.device('gamepad'); }
      const b = (i) => !!(g.buttons[i] && g.buttons[i].pressed);
      if (b(14)) p.x = -1; if (b(15)) p.x = 1; if (b(12)) p.y = 1; if (b(13)) p.y = -1;
      p.guard = b(5) || b(7) || b(4);
      const map = { 2: 'light', 3: 'special', 0: 'dash', 1: 'ult', 9: 'pause' };
      for (const i in map) {
        const now = b(i);
        if (now && !p.prev[i]) { this.pressed.add(map[i]); if (i === '0') { this.pressed.add('interact'); this.pressed.add('advance'); this.pressed.add('confirm'); } this.device('gamepad'); }
        p.prev[i] = now;
      }
      break;
    }
    let x = kx + p.x + this.touch.x, y = ky + p.y + this.touch.y;
    const l = Math.hypot(x, y);
    if (l > 1) { x /= l; y /= l; }
    this.x = x; this.y = y;
    this.guard = this.keys.has('KeyL') || this.keys.has('ShiftLeft') || this.keys.has('ShiftRight') || p.guard || this.touch.guard;
  }
}

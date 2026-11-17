// DOM overlay: duel HUD, campus HUD, menus, panels and dialogue.
const $ = (id) => document.getElementById(id);
export const esc = (s) => String(s).replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));

export class UI {
  constructor(audio) {
    this.audio = audio;
    this.lag = [1, 1]; this.lagDelay = [0, 0]; this.lastHp = [1, 1];
    this.announceT = 0; this.bannerT = 0; this.comboShown = 0; this.comboT = 0;
    this.dlg = null; this.panel = null; this.tagEls = new Map();
    this.device = 'keyboard';
    $('panelClose').addEventListener('click', () => this.closePanel(true));
    $('panelBody').addEventListener('click', (e) => this._panelClick(e));
    $('panelFoot').addEventListener('click', (e) => this._panelClick(e));
    $('dialog').addEventListener('click', () => this.advance());
    document.addEventListener('click', (e) => { if (e.target.closest('button')) this.audio.init(); }, true);
  }

  root(mode) { document.body.dataset.mode = mode; }
  show(id, on = true) { $(id).hidden = !on; }
  setAccent(css) { document.documentElement.style.setProperty('--ac', css); }

  // ---- loading / fade
  loaded() { $('loading').hidden = true; }
  loadError(msg) { $('loading').innerHTML = `<div><b>HALCYON CLASH</b>COULD NOT START<p>${esc(msg)}</p></div>`; }
  fade(on, ms = 350) {
    const el = $('fade');
    el.style.transitionDuration = `${ms}ms`;
    el.classList.toggle('on', on);
    return new Promise((r) => setTimeout(r, ms + 30));
  }

  // ---- title
  title(items) {
    const menu = $('titleMenu');
    menu.innerHTML = items.map((it, i) => `<button type="button" class="btn${it.primary ? ' primary' : ''}" data-i="${i}">${esc(it.label)}${it.sub ? `<small>${esc(it.sub)}</small>` : ''}</button>`).join('');
    menu.onclick = (e) => { const b = e.target.closest('button'); if (!b) return; this.audio.init(); this.audio.play('uiOk'); items[+b.dataset.i].onClick(); };
    this.show('title');
  }

  // ---- fighter select
  select({ kicker, title, fighters, index = 0, goLabel, bio, onChange, onGo, onBack }) {
    $('selTitle').innerHTML = `<small>${esc(kicker)}</small>${esc(title)}`;
    const cards = $('selCards');
    let cur = index;
    const draw = () => {
      const f = fighters[cur];
      cards.innerHTML = fighters.map((x, i) => `<button type="button" class="card${i === cur ? ' on' : ''}" style="--c:${x.css}" data-i="${i}"><b>${esc(x.name)}</b><span>${esc(x.cardSub || x.title)}</span></button>`).join('');
      $('selBio').style.setProperty('--ac', f.css);
      $('selBio').innerHTML = bio(f);
      $('selGo').innerHTML = goLabel(f);
      onChange(f);
    };
    cards.onclick = (e) => { const b = e.target.closest('button'); if (!b) return; cur = +b.dataset.i; this.audio.play('uiMove'); draw(); };
    $('selGo').onclick = () => { this.audio.play('uiOk'); onGo(fighters[cur]); };
    $('selBack').onclick = () => { this.audio.play('uiBack'); onBack(); };
    this.selectStep = (d) => { cur = (cur + d + fighters.length) % fighters.length; this.audio.play('uiMove'); draw(); };
    this.selectGo = () => $('selGo').click();
    draw();
    this.show('select');
  }

  // ---- generic panel
  openPanel({ kicker = '', title, body, buttons = [], onClose = null, closable = true, actions = {}, accent = null }) {
    this.panel = { buttons, onClose, actions, closable };
    $('panelTitle').innerHTML = `${kicker ? `<small>${esc(kicker)}</small>` : ''}${esc(title)}`;
    $('panelBody').innerHTML = body;
    $('panelBody').scrollTop = 0;
    $('panelFoot').innerHTML = buttons.map((b, i) => `<button type="button" class="btn slim${b.primary ? ' primary' : ''}" data-btn="${i}"${b.disabled ? ' disabled' : ''}>${esc(b.label)}</button>`).join('');
    $('panelFoot').hidden = !buttons.length;
    $('panelClose').hidden = !closable;
    $('panel').style.setProperty('--ac', accent || 'var(--gold)');
    if (!accent) $('panel').style.removeProperty('--ac');
    this.show('panelWrap');
  }

  setPanelBody(html) { const b = $('panelBody'), top = b.scrollTop; b.innerHTML = html; b.scrollTop = top; }

  closePanel(userClosed = false) {
    const p = this.panel;
    if (!p) return;
    if (userClosed && !p.closable) return;
    this.panel = null;
    this.show('panelWrap', false);
    if (userClosed) this.audio.play('uiBack');
    if (p.onClose) p.onClose(userClosed);
  }

  _panelClick(e) {
    const p = this.panel;
    if (!p) return;
    const b = e.target.closest('[data-btn]');
    if (b && !b.disabled) { this.audio.play('uiOk'); p.buttons[+b.dataset.btn].onClick(); return; }
    const a = e.target.closest('[data-do]');
    if (a && !a.disabled && p.actions[a.dataset.do]) { this.audio.play('uiMove'); p.actions[a.dataset.do](a.dataset.arg, a); }
  }

  // ---- dialogue
  /** lines: [{ who, css, text }]. Resolves when the player has read them all. */
  say(lines) {
    return new Promise((resolve) => {
      this.dlg = { lines, i: 0, shown: 0, resolve, tick: 0 };
      this._dlgLine();
      this.show('dialog');
    });
  }

  _dlgLine() {
    const d = this.dlg, l = d.lines[d.i];
    d.shown = 0;
    $('dlgWho').textContent = l.who;
    $('dialog').style.setProperty('--c', l.css || 'var(--gold)');
    $('dlgText').textContent = '';
  }

  advance() {
    const d = this.dlg;
    if (!d) return false;
    const l = d.lines[d.i];
    if (d.shown < l.text.length) { d.shown = l.text.length; $('dlgText').textContent = l.text; return true; }
    d.i++;
    if (d.i >= d.lines.length) { this.dlg = null; this.show('dialog', false); d.resolve(); return true; }
    this.audio.play('uiMove');
    this._dlgLine();
    return true;
  }

  /** A line that shows itself for a moment during a cinematic (no input needed). */
  caption(who, text, css, seconds) {
    $('dlgWho').textContent = who; $('dlgText').textContent = text;
    $('dialog').style.setProperty('--c', css || 'var(--gold)');
    this.show('dialog');
    this.captionT = seconds;
  }

  toast(text) {
    const el = document.createElement('div');
    el.textContent = text;
    $('toast').appendChild(el);
    setTimeout(() => el.remove(), 2700);
  }

  // ---- duel HUD
  setupDuel({ p1, p2, need, label }) {
    const st = document.documentElement.style;
    st.setProperty('--p1', p1.css); st.setProperty('--p2', p2.css);
    $('p1Name').textContent = p1.name; $('p2Name').textContent = p2.name;
    $('p1Tag').textContent = p1.tag; $('p2Tag').textContent = p2.tag;
    $('roundTag').textContent = label;
    this.need = need;
    this.setPips(0, 0);
    this.lag = [1, 1]; this.lastHp = [1, 1]; this.lagDelay = [0, 0];
    this.comboShown = 0; this.show('combo', false); this.show('moveBanner', false);
    this.hints(this.device);
  }

  setPips(a, b) {
    const mk = (n) => (this.need > 1 ? Array.from({ length: this.need }, (_, i) => `<span class="${i < n ? 'on' : ''}"></span>`).join('') : '');
    $('p1Pips').innerHTML = mk(a); $('p2Pips').innerHTML = mk(b);
  }

  hints(device) {
    this.device = device;
    const k = (key, label) => `<span><kbd>${key}</kbd>${label}</span>`;
    $('hints').innerHTML = device === 'gamepad'
      ? k('Stick', 'Move') + k('X', 'Attack') + k('Y', 'Skill') + k('RB', 'Guard') + k('A', 'Dash') + k('B', 'Ultimate')
      : k('WASD', 'Move') + k('J', 'Attack') + k('K', 'Skill') + k('L', 'Guard') + k('Space', 'Dash') + k('I', 'Ultimate');
  }

  updateDuel(a, b, timeLeft, dt) {
    const fs = [a, b];
    for (let i = 0; i < 2; i++) {
      const f = fs[i], n = i + 1, r = Math.max(0, f.hp / f.maxHp);
      if (r < this.lastHp[i] - 1e-4) this.lagDelay[i] = 0.45;
      this.lastHp[i] = r;
      if (this.lagDelay[i] > 0) this.lagDelay[i] -= dt; else this.lag[i] += (r - this.lag[i]) * Math.min(1, dt * 5);
      if (this.lag[i] < r) this.lag[i] = r;
      $(`p${n}Hp`).style.transform = `scaleX(${r.toFixed(4)})`;
      $(`p${n}Lag`).style.transform = `scaleX(${this.lag[i].toFixed(4)})`;
      $(`p${n}HpBox`).classList.toggle('low', r < 0.25 && r > 0);
      const e = f.energy / 100;
      $(`p${n}En`).style.transform = `scaleX(${e.toFixed(3)})`;
      $(`p${n}EnBox`).classList.toggle('full', e >= 1);
      $(`p${n}Ult`).classList.toggle('on', e >= 1);
    }
    $('timer').textContent = String(Math.max(0, Math.ceil(timeLeft))).padStart(2, '0');
    $('btnUlt').classList.toggle('ready', a.energy >= 100);
    $('btnSpecial').classList.toggle('off', a.energy < a.def.special.cost);
    // combo counter for the player
    const c = a.combo >= 2 ? a.combo : 0;
    if (c !== this.comboShown) {
      if (c > 0) { $('comboN').textContent = c; this.show('combo'); const el = $('combo'); el.classList.remove('bump'); void el.offsetWidth; el.classList.add('bump'); this.comboT = 1.2; }
      this.comboShown = c;
    }
    if (c === 0 && this.comboT > 0) { this.comboT -= dt; if (this.comboT <= 0) this.show('combo', false); }
  }

  announce(text, sub = '', seconds = 1.2, cls = '') {
    const el = $('announce');
    el.className = cls;
    el.hidden = true; void el.offsetWidth;
    $('announceText').textContent = text; $('announceSub').textContent = sub;
    el.hidden = false;
    this.announceT = seconds;
  }

  moveBanner(text, css, right) {
    const el = $('moveBanner');
    el.hidden = true; void el.offsetWidth;
    el.textContent = text; el.style.setProperty('--c', css); el.classList.toggle('right', !!right);
    el.hidden = false;
    this.bannerT = 1.5;
  }

  cutIn(name, who, css) {
    const el = $('cutin');
    el.hidden = true; void el.offsetWidth;
    $('cutinName').textContent = name; $('cutinWho').textContent = who;
    el.style.setProperty('--c', css);
    el.hidden = false;
  }
  cutInEnd() { this.show('cutin', false); }

  damage(x, y, text, cls = '', css = '#fff') {
    const box = $('dmg');
    if (box.childElementCount > 14) box.firstElementChild.remove();
    const el = document.createElement('span');
    el.textContent = text; el.className = cls; el.style.left = `${x}px`; el.style.top = `${y}px`; el.style.setProperty('--c', css);
    box.appendChild(el);
    setTimeout(() => el.remove(), 820);
  }

  // ---- campus HUD
  idCard({ name, school, seat, level, xp, points }) {
    $('idName').textContent = name; $('idSchool').textContent = school; $('idSeat').textContent = seat; $('idLevel').textContent = level;
    $('idXp').style.transform = `scaleX(${xp.toFixed(3)})`;
    $('idPts').innerHTML = points > 0 ? `<b>${points} SKILL PT${points === 1 ? '' : 'S'}</b>` : '';
    $('navTraining').innerHTML = `${points > 0 ? '<i class="dot"></i>' : ''}<small>T</small>Training`;
  }
  objective(text) { $('objective').textContent = text; }
  prompt(text, key = 'E') {
    const el = $('prompt');
    if (!text) { el.hidden = true; $('btnInteract').classList.add('off'); return; }
    if (el.dataset.t !== text) { el.dataset.t = text; el.innerHTML = `<kbd>${key}</kbd>${esc(text)}`; }
    el.hidden = false; $('btnInteract').classList.remove('off');
  }
  hubNav(handlers) {
    $('navRegister').onclick = () => { this.audio.play('uiOk'); handlers.register(); };
    $('navTraining').onclick = () => { this.audio.play('uiOk'); handlers.training(); };
    $('navTrials').onclick = () => { this.audio.play('uiOk'); handlers.trials(); };
    $('navMenu').onclick = () => { this.audio.play('uiOk'); handlers.menu(); };
    $('pauseBtn').onclick = () => { this.audio.play('uiOk'); handlers.menu(); };
  }

  /** Floating name plates over people on the campus. list: [{ id, x, y, show, seat, name, sub, css }] */
  tags(list) {
    const box = $('tags'), seen = new Set();
    for (const t of list) {
      seen.add(t.id);
      let el = this.tagEls.get(t.id);
      if (!el) {
        el = document.createElement('div');
        el.innerHTML = `${t.seat ? `<b>${esc(t.seat)}</b>` : ''}${esc(t.name)}<small>${esc(t.sub || '')}</small>`;
        el.style.setProperty('--c', t.css);
        box.appendChild(el); this.tagEls.set(t.id, el);
      }
      el.hidden = !t.show;
      if (t.show) { el.style.left = `${t.x.toFixed(1)}px`; el.style.top = `${t.y.toFixed(1)}px`; }
    }
    for (const [id, el] of this.tagEls) if (!seen.has(id)) { el.remove(); this.tagEls.delete(id); }
  }

  update(dt) {
    if (this.announceT > 0) { this.announceT -= dt; if (this.announceT <= 0) this.show('announce', false); }
    if (this.bannerT > 0) { this.bannerT -= dt; if (this.bannerT <= 0) this.show('moveBanner', false); }
    if (this.captionT > 0) { this.captionT -= dt; if (this.captionT <= 0 && !this.dlg) this.show('dialog', false); }
    const d = this.dlg;
    if (d) {
      const l = d.lines[d.i];
      if (d.shown < l.text.length) {
        const before = Math.floor(d.shown);
        d.shown = Math.min(l.text.length, d.shown + dt * 46);
        if (Math.floor(d.shown) !== before) { $('dlgText').textContent = l.text.slice(0, Math.floor(d.shown)); if (Math.floor(d.shown) % 3 === 0) this.audio.play('text'); }
      }
    }
  }
}

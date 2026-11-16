// Halcyon Clash: game flow. Title -> enrolment -> academy campus <-> sanctioned duels -> Crown Trials.
import * as THREE from './three.js';
import { Gfx, QUALITY } from './gfx.js';
import { Arena } from './arena.js';
import { Campus, Explorer } from './campus.js';
import { FX, Trail } from './fx.js';
import { Duel } from './combat.js';
import { PlayerController, AIController } from './control.js';
import { CamRig } from './camera.js';
import { Input } from './input.js';
import { GameAudio } from './audio.js';
import { UI, esc } from './ui.js';
import { Rig } from './character.js';
import { Animator } from './anim.js';
import { FIGHTERS, FIGHTER_BY_ID } from './fighters.js';
import * as RPG from './rpg.js';

const WEAPON_LABEL = { saber: 'Lumen Saber', spear: 'Lumen Lance', pistol: 'Twin Pistols', hammer: 'Lumen Maul' };
const SETTINGS_KEY = 'halcyon-clash-settings-v1';
const _v = new THREE.Vector3();

const PROCTOR = {
  ...FIGHTERS[0], id: 'proctor', name: 'PROCTOR MAREN', short: 'MAREN', title: 'Faculty', accent: 0xffc24a, css: '#ffc24a',
  look: {
    height: 1.8, fem: true, skin: 0xe4c2a4, hair: 0x8c8fa6, hairTip: 0xd5d8ea, hairStyle: 'ponytail', eye: 0x9aa4ff, outfit: 'coat', sleeves: 'long', bootHeight: 0.3,
    jacket: 0x262b40, skirt: 0x262b40, dark: 0x10131f, pants: 0x10131f, boots: 0x0c0e16, glove: 0x10131f, browTilt: 4, blush: 0.04,
  },
};

const TIPS = [
  'Tap Guard just before a hit lands for a Perfect Guard. It staggers them and fills your Lumen.',
  'A dash makes you untouchable for a moment. Dash through an attack rather than away from it.',
  'Your Skill costs a third of the gauge and can be cancelled into from a combo.',
  'A full Lumen gauge means your Ultimate is ready. Ultimates cannot be guarded, only avoided.',
  'Seat-holders above Seat VII guard and punish. Bait a swing, then strike while they recover.',
  'Lost a duel? Spar in the Training Hall. Sparring still earns experience.',
];

function loadSettings() {
  const coarse = window.matchMedia && window.matchMedia('(pointer: coarse)').matches;
  const base = { quality: coarse ? 'medium' : 'high', muted: false };
  try { return { ...base, ...JSON.parse(window.localStorage.getItem(SETTINGS_KEY) || '{}') }; } catch (e) { return base; }
}
function storeSettings(s) { try { window.localStorage.setItem(SETTINGS_KEY, JSON.stringify(s)); } catch (e) { /* storage unavailable */ } }

class Game {
  constructor() {
    this.stage = document.getElementById('stage');
    this.audio = new GameAudio();
    this.ui = new UI(this.audio);
    this.settings = loadSettings();
    this.params = new URLSearchParams(window.location.search);
    if (this.params.get('q')) this.settings.quality = this.params.get('q');
    this.drs = this.params.get('drs') !== '0';
    try {
      this.gfx = new Gfx(document.getElementById('view'), this.stage);
    } catch (e) {
      this.ui.loadError('This device or browser could not create a WebGL 2 context, which the game needs to draw its 3D world.');
      throw e;
    }
    this.gfx.setQuality(this.settings.quality, true);
    this.gfx.resize(true);
    this.audio.muted = this.settings.muted;

    this.scene = new THREE.Scene();
    this.camera = new THREE.PerspectiveCamera(46, this.gfx.width / this.gfx.height, 0.1, 2400);
    this.camera.layers.enable(1);
    this.cam = new CamRig(this.camera);
    this.cam.shakeScale = window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches ? 0.25 : 1;
    this.arena = new Arena(this.scene, this.gfx);
    this.campus = new Campus(this.scene);
    this.fx = new FX(this.scene);
    this.input = new Input(this.stage);
    this.input.onDevice = (d) => this.ui.hints(d);
    this.ctx = { scene: this.scene, fx: this.fx, arena: this.arena, audio: this.audio, cam: this.cam };
    this.warmTrail = new Trail(this.scene, 0xffffff);   // exists only so its shader is compiled at load

    this.save = RPG.loadSave();
    this.timers = []; this.flow = 0;
    this.paused = false; this.timeScale = 1;
    this.duel = null; this.explorer = null; this.showcase = null; this.duelCfg = null;
    this.state = 'boot'; this.time = 0; this.hubLock = 0; this.tip = 0;
    this.letterbox = 0;
    this.frameAvg = 16; this.drsCool = 2;
    this.frames = 0;

    this.ui.hubNav({ register: () => this.openRegister(), training: () => this.openTraining(), trials: () => this.openTrials(), menu: () => this.openMenu() });
    new ResizeObserver(() => this.gfx.resize()).observe(this.stage);
    document.addEventListener('visibilitychange', () => { this.audio.suspend(document.hidden); this.last = performance.now(); });
    const unlock = () => this.audio.init();
    window.addEventListener('pointerdown', unlock); window.addEventListener('keydown', unlock);

    this.last = performance.now();
    this.loop = this.loop.bind(this);
    requestAnimationFrame(this.loop);
    this.boot();
  }

  async boot() {
    const demo = this.params.get('demo');
    if (demo === 'duel') {
      const p1 = FIGHTER_BY_ID[this.params.get('p1') || 'kaito'], p2 = FIGHTER_BY_ID[this.params.get('p2') || 'sera'];
      this.ui.loaded();
      this.duelFlow({ p1, p2, ai: +(this.params.get('ai') || 1), need: 1, kicker: 'EXHIBITION', label: 'DUEL', tags: ['P1', 'CPU'], onEnd: () => this.showTitle() });
    } else if (demo === 'hub') {
      this.save = RPG.newSave(this.params.get('hero') || 'kaito'); this.save.intro = true;
      this.ui.loaded();
      this.enterHub();
    } else {
      await this.showTitle();
      this.ui.loaded();
    }
    this.ready = true;
  }

  wait(sec) { return new Promise((res) => this.timers.push({ t: sec, res })); }

  // ------------------------------------------------------------ world management
  clearWorld() {
    if (this.duel) { this.duel.dispose(); this.duel = null; }
    if (this.explorer) { this.explorer.dispose(); this.explorer = null; }
    this.setShowcase(null);
    this.fx.clear();
    this.timeScale = 1; this.letterbox = 0;
    this.gfx.post.uRadial.value = 0; this.gfx.post.uFlash.value = 0; this.gfx.post.uSaturation.value = 1.08;
    for (const id of ['hud', 'hub', 'title', 'select', 'cutin', 'announce', 'dialog']) this.ui.show(id, false);
    this.ui.tags([]); this.ui.prompt(null);
    this.audio.stopLoop('beam');
  }

  setLocation(where) {
    const arena = where === 'arena';
    this.arena.stage.visible = arena;
    this.campus.group.visible = !arena;
    this.gfx.reflection.enabled = arena && this.gfx.q.reflections;
    this.gfx.reflection.strength.value = this.gfx.reflection.enabled ? 1 : 0;
    this.cam.maxRadius = arena ? 16.6 : 0;
    this.location = where;
  }

  /** Stand one fighter in the ring for the select screen. */
  setShowcase(def) {
    const s = this.showcase;
    if (s) {
      this.scene.remove(s.rig.root);
      s.rig.root.traverse((o) => { if (o.isMesh) { if (!o.geometry.userData.shared) o.geometry.dispose(); if (o.material !== Rig._blob) { if (o.material.map) o.material.map.dispose(); o.material.dispose(); } } });
      this.showcase = null;
    }
    if (!def) return;
    const rig = new Rig(def), anim = new Animator(rig);
    this.scene.add(rig.root);
    this.showcase = { rig, anim, pos: rig.root.position, facing: 0, def, t: 0 };
    anim.play('intro', { blend: 0, force: true, at: 0.3 });
    this.fx.ring(rig.root.position, def.accent, 0.3, 2.6, 0.5);
    this.fx.weaponLights[0].color.set(def.accent);
  }

  project(v) {
    _v.copy(v).project(this.camera);
    return { x: (_v.x * 0.5 + 0.5) * this.gfx.cssW, y: (-_v.y * 0.5 + 0.5) * this.gfx.cssH, front: _v.z < 1 };
  }

  // ------------------------------------------------------------ title
  async showTitle() {
    const token = ++this.flow;
    await this.ui.fade(true);
    if (token !== this.flow) return;
    this.clearWorld();
    this.setLocation('arena');
    this.state = 'title';
    this.ui.root('menu'); this.input.mode = 'menu';
    this.ui.setAccent('#39c9ff');
    this.audio.music('menu'); this.audio.crowd(0.5);
    this.arena.setScreen({ title: 'CROWN TRIALS', left: 'HALCYON', right: 'CLASH', leftColor: '#39c9ff', rightColor: '#ff4f9a' });
    this.startDemo();
    this.cam.set('orbit', { radius: 13.5, height: 3.6, speed: 0.07, lookY: 1.4, angle: 0.6 }, 0);
    this.gfx.warm(this.scene, this.camera);
    const items = [];
    if (this.save) {
      const h = FIGHTER_BY_ID[this.save.hero], seat = RPG.playerSeat(this.save);
      items.push({ label: 'Continue', sub: `${h.name} · ${RPG.ACADEMIES[this.save.academy].short} · ${RPG.seatName(seat)} · LV ${this.save.level}`, primary: true, onClick: () => this.enterHub() });
    }
    items.push({ label: 'New student', sub: 'Enrol at an academy and climb the Register', primary: !this.save, onClick: () => this.pickHero() });
    items.push({ label: 'Quick duel', sub: 'Any two duelists, straight into the ring', onClick: () => this.pickQuick() });
    items.push({ label: 'Controls & settings', onClick: () => this.openMenu() });
    this.ui.title(items);
    await this.ui.fade(false);
  }

  startDemo() {
    if (this.duel) { this.duel.dispose(); this.duel = null; }
    const pool = FIGHTERS.slice().sort(() => Math.random() - 0.5);
    const duel = this.duel = new Duel(this.ctx, pool[0], pool[1]);
    duel.controllers = [new AIController(2), new AIController(2)];
    duel.on((type) => { if (type === 'ko' && this.state === 'title') this.wait(4).then(() => { if (this.state === 'title' && this.duel === duel) this.startDemo(); }); });
    duel.demo = true;
    duel.a.release(); duel.b.release(); duel.fightOn = true;
  }

  bio(f) {
    const ac = RPG.academyOfHero(f.id);
    const bar = (n) => `<span class="pipbar">${[1, 2, 3, 4, 5].map((i) => `<i class="${i <= n ? 'on' : ''}"></i>`).join('')}</span>`;
    return `<div class="sub">${esc(f.title)} · ${esc(ac.name)}</div><h3>${esc(f.name)}</h3><p>${esc(f.blurb)}</p>
      <div class="statbars"><span>Power</span>${bar(f.bars.power)}<span>Speed</span>${bar(f.bars.speed)}<span>Reach</span>${bar(f.bars.range)}<span>Guard</span>${bar(f.bars.defense)}</div>
      <div class="moves"><b>Skill</b> ${esc(f.special.name)} · <b>Ultimate</b> ${esc(f.ultimate.name)}<br>${esc(f.weaponName)} · “${esc(ac.motto)}”</div>`;
  }

  async toSelect(opts) {
    const token = ++this.flow;
    await this.ui.fade(true, 220);
    if (token !== this.flow) return;
    this.clearWorld();
    this.setLocation('arena');
    this.state = 'select';
    this.ui.root('menu'); this.input.mode = 'menu';
    this.ui.select({
      ...opts, fighters: opts.fighters || FIGHTERS, bio: (f) => this.bio(f),
      onChange: (f) => {
        this.setShowcase(f); this.ui.setAccent(f.css);
        this.cam.set('face', { fighter: this.showcase, dist: 4.2, angle: -0.42, height: 1.25, lookY: 1.02, fov: 36, spin: 0.05 }, 0.35);
        this.arena.setScreen({ title: RPG.academyOfHero(f.id).name.toUpperCase(), left: f.short, right: f.title.replace('The ', '').toUpperCase(), leftColor: f.css, rightColor: f.css, center: '·' });
      },
    });
    await this.ui.fade(false, 220);
  }

  pickHero() {
    const begin = () => this.toSelect({
      kicker: 'Enrolment', title: 'Choose your duelist', goLabel: (f) => `Enrol at ${esc(RPG.academyOfHero(f.id).short)}<small>Begin as an unseated first-year</small>`,
      onGo: (f) => { this.save = RPG.newSave(f.id); RPG.storeSave(this.save); this.enterHub(); },
      onBack: () => this.showTitle(),
    });
    if (!this.save) { begin(); return; }
    this.ui.openPanel({
      kicker: 'Enrolment', title: 'Start over?',
      body: '<p class="note">You already have a student on record. Enrolling again replaces that record, including their seat, level and skill points.</p>',
      buttons: [{ label: 'Keep my student', onClick: () => this.ui.closePanel() }, { label: 'Enrol a new student', primary: true, onClick: () => { this.ui.closePanel(); begin(); } }],
    });
  }

  pickQuick() {
    this.toSelect({
      kicker: 'Quick duel', title: 'Your duelist', goLabel: () => 'Next: choose a rival',
      onGo: (me) => this.toSelect({
        kicker: 'Quick duel', title: 'Your rival', goLabel: () => 'Start the duel<small>Best of three rounds</small>',
        onGo: (foe) => this.duelFlow({
          p1: me, p2: { ...foe, id: `${foe.id}-cpu` }, ai: 2, need: 2, kicker: 'EXHIBITION', label: 'ROUND', tags: ['YOU', 'RIVAL'],
          onEnd: (r) => this.resultPanel({ win: r.win, headline: r.win ? 'VICTORY' : 'DEFEATED', text: r.win ? `${foe.name} yields the ring.` : `${foe.name} takes the exhibition.`, gains: [], next: () => this.showTitle(), nextLabel: 'Back to title' }),
        }),
        onBack: () => this.pickQuick(),
      }),
      onBack: () => this.showTitle(),
    });
  }

  // ------------------------------------------------------------ campus hub
  async enterHub() {
    const token = ++this.flow;
    await this.ui.fade(true);
    if (token !== this.flow) return;
    this.clearWorld();
    const save = this.save, academy = RPG.ACADEMIES[save.academy];
    this.setLocation('campus');
    this.campus.setAcademy(academy);
    this.ui.setAccent(academy.css);
    this.explorer = new Explorer(this.scene, this.campus, RPG.playerDef(save));
    this.refreshHub();
    this.gfx.warm(this.scene, this.camera);
    this.state = 'hub';
    this.ui.root('explore'); this.input.mode = 'explore'; this.input.clear();
    this.audio.music('hub'); this.audio.crowd(0);
    this.cam.yaw = Math.PI;
    this.cam.set('follow', { target: this.explorer.pos, yaw: Math.PI }, 0);
    this.ui.show('hub');
    this.hubLock = 0.4;
    RPG.storeSave(save);
    await this.ui.fade(false);
    if (token !== this.flow) return;
    if (!save.intro) {
      save.intro = true; RPG.storeSave(save);
      const h = FIGHTER_BY_ID[save.hero], first = h.name.split(' ')[0];
      await this.talk([
        `Welcome to ${academy.name}, ${first[0]}${first.slice(1).toLowerCase()}. I am Proctor Maren. Classes are the easy part of life here.`,
        'That board is the Register: our twelve strongest duelists, Seat XII up to Seat I. Every seat can be challenged.',
        'Break a seat-holder\'s sigil in a sanctioned duel and their seat is yours. You may challenge up to three seats above your own.',
        'Each seat you take makes you stronger, and some unlock new techniques. Spend your skill points in the Training Hall.',
        'Hold Seat I and the Crown Gate opens. Beyond it, the aces of the other three academies are waiting. Now, go and pick a fight.',
      ]);
    }
  }

  talk(lines, who = 'PROCTOR MAREN', css = '#ffc24a') {
    this.input.clear();
    return this.ui.say(lines.map((text) => ({ who, css, text }))).then(() => { this.input.clear(); this.hubLock = 0.3; });
  }

  refreshHub() {
    const save = this.save, academy = RPG.ACADEMIES[save.academy], h = FIGHTER_BY_ID[save.hero];
    const view = this.view = RPG.ladderView(save), seat = RPG.playerSeat(save);
    this.campus.setBoard(view, academy);
    this.campus.setGate(seat === 0);
    const npcs = [{ id: 'proctor', kind: 'proctor', def: PROCTOR, spot: this.campus.spots.proctor, name: 'PROCTOR MAREN', sub: 'Faculty · talk for advice', css: '#ffc24a', hideWeapon: true }];
    view.filter((v) => v.can).sort((a, b) => b.idx - a.idx).slice(0, 3).forEach((v, i) => npcs.push({
      id: v.id, kind: 'seat', idx: v.idx, def: RPG.studentDef(v.student, academy), spot: this.campus.spots.npc[i],
      name: v.name.toUpperCase(), seat: RPG.ROMAN[v.idx], sub: `${v.epithet} · LV ${v.level}`, css: v.css,
    }));
    this.explorer.setNPCs(npcs);
    this.spots = [
      { ...this.campus.spots.register, id: 'register', label: 'Read the Register' },
      { ...this.campus.spots.training, id: 'training', label: 'Enter the Training Hall' },
      { ...this.campus.spots.gate, id: 'gate', label: seat === 0 ? 'Step through the Crown Gate' : 'Examine the Crown Gate' },
    ];
    this.ui.idCard({ name: h.name, school: `${academy.name} · Day ${save.day}`, seat: seat < 0 ? 'UNSEATED' : `${RPG.seatName(seat).toUpperCase()} · ${RPG.tierName(seat).toUpperCase()}`, level: save.level, xp: save.xp / RPG.xpToNext(save.level), points: save.points });
    this.ui.objective(RPG.nextGoal(save));
    document.getElementById('navTrials').hidden = seat !== 0 && !save.champion;
  }

  updateHub(dt) {
    const ex = this.explorer, ui = this.ui, input = this.input;
    const busy = !!(ui.panel || ui.dlg);
    ex.frozen = busy;
    this.cam.yaw += input.lookX * 0.0055; input.lookX = 0;
    if (!busy && Math.abs(input.x) > 0.2) this.cam.yaw -= input.x * dt * 0.85;
    ex.update(dt, input, this.cam);
    if (this.hubLock > 0) this.hubLock -= dt;
    let near = null;
    if (!busy) {
      near = ex.nearest(this.spots);
      const key = input.lastDevice === 'gamepad' ? 'A' : 'E';
      if (!near) ui.prompt(null);
      else if (near.type === 'npc') ui.prompt(near.npc.kind === 'seat' ? `Challenge ${near.npc.name} · Seat ${near.npc.seat}` : `Talk to ${near.npc.name}`, key);
      else ui.prompt(near.spot.label, key);
      document.getElementById('btnInteract').textContent = near && near.type === 'npc' && near.npc.kind === 'seat' ? 'DUEL' : near && near.type === 'npc' ? 'TALK' : 'USE';
      if (this.hubLock <= 0) {
        if (near && (input.take('interact') || input.take('confirm'))) this.interact(near);
        else if (input.take('register')) this.openRegister();
        else if (input.take('training')) this.openTraining();
        else if (input.take('pause')) this.openMenu();
      }
    } else ui.prompt(null);
    // name plates
    const tags = [];
    for (const n of ex.npcs) {
      _v.copy(n.rig.root.position); _v.y += 1.95 * n.rig.scale;
      const p = this.project(_v);
      tags.push({ id: n.id, x: p.x, y: p.y, show: p.front && n.dist < 16, seat: n.seat, name: n.name, sub: n.sub, css: n.css });
    }
    ui.tags(tags);
  }

  interact(near) {
    this.input.clear();
    if (near.type === 'npc') {
      if (near.npc.kind === 'seat') this.challenge(near.npc.idx);
      else { const tip = TIPS[this.tip++ % TIPS.length]; this.talk([RPG.nextGoal(this.save), tip]); }
      return;
    }
    const id = near.spot.id;
    if (id === 'register') this.openRegister();
    else if (id === 'training') this.openTraining();
    else if (id === 'gate') { if (RPG.playerSeat(this.save) === 0 || this.save.champion) this.openTrials(); else this.talk(['The Crown Gate. It only opens for a Crownbearer: the holder of Seat I.', 'Climb the Register first. The gate will know when you are ready.']); }
  }

  // ---- panels
  openRegister() {
    if (this.state !== 'hub') return;
    const save = this.save, academy = RPG.ACADEMIES[save.academy], view = this.view, seat = RPG.playerSeat(save);
    const rows = view.map((v) => `<div class="seat${v.player ? ' me' : ''}" style="--c:${v.css}"><span class="num">${RPG.ROMAN[v.idx]}</span><i class="bar"></i>
      <div class="nm"><b>${esc(v.name.toUpperCase())}${v.player ? ' · YOU' : ''}</b><span>${esc(v.epithet)} · ${WEAPON_LABEL[v.weapon]}</span></div><span class="lv">LV ${v.level}</span>
      ${v.player ? '<span class="lock">Your seat</span>' : v.can ? `<button type="button" class="go" data-do="challenge" data-arg="${v.idx}">CHALLENGE</button>` : `<span class="lock">${seat >= 0 && v.idx > seat ? 'Below you' : 'Out of reach'}</span>`}</div>`).join('');
    this.ui.openPanel({
      kicker: academy.name, title: 'The Register', accent: academy.css,
      body: `<p class="note">The twelve seats of ${esc(academy.short)}. You may challenge up to three seats above your own${seat < 0 ? ' (unseated students start with Seats X to XII)' : ''}. Winning takes the seat; everyone between slides down one.</p>${rows}`,
      actions: { challenge: (arg) => { this.ui.closePanel(); this.challenge(+arg); } },
      onClose: () => { this.hubLock = 0.3; this.input.clear(); },
    });
  }

  challenge(idx) {
    const save = this.save, v = this.view[idx], s = v.student;
    this.ui.openPanel({
      kicker: `${RPG.seatName(idx)} · ${RPG.tierName(idx)}`, title: s.name, accent: v.css,
      body: `<p class="note" style="font-size:14.5px;color:var(--fg)">“${esc(s.taunt)}”</p>
        <div class="gain"><div><small>Epithet</small><b>${esc(s.epithet)}</b></div><div><small>Weapon</small><b>${WEAPON_LABEL[s.weapon]}</b></div><div><small>Their level</small><b>LV ${s.level}</b></div><div class="hot"><small>Your level</small><b>LV ${save.level}</b></div></div>
        <p class="note" style="margin-top:12px">A sanctioned duel: one round, first sigil to break. Win and ${RPG.seatName(idx)} is yours. Lose and the Register stays as it is.</p>`,
      buttons: [{ label: 'Not yet', onClick: () => this.ui.closePanel() }, { label: 'Challenge', primary: true, onClick: () => { this.ui.closePanel(); this.ladderDuel(idx); } }],
      onClose: () => { this.hubLock = 0.3; this.input.clear(); },
    });
  }

  openTraining() {
    if (this.state !== 'hub') return;
    const save = this.save, academy = RPG.ACADEMIES[save.academy];
    const body = () => {
      const stats = RPG.STATS.map((st) => {
        const n = save.alloc[st.id];
        return `<div class="stat"><div><b>${st.name}</b><span>${st.desc}</span></div><span class="pipbar">${Array.from({ length: st.max }, (_, i) => `<i class="${i < n ? 'on' : ''}"></i>`).join('')}</span>
          <button type="button" class="plus" data-do="add" data-arg="${st.id}" aria-label="Raise ${st.name}"${save.points > 0 && n < st.max ? '' : ' disabled'}>+</button></div>`;
      }).join('');
      const perks = RPG.activePerks(save);
      const pk = RPG.PERKS.map((p) => `<div class="perk${perks[p.id] ? ' on' : ''}"><i>${RPG.seatName(p.seat).toUpperCase()}</i><div><b>${esc(p.name)}</b><span>${esc(p.desc)}</span></div></div>`).join('');
      const d = RPG.playerDef(save), base = FIGHTER_BY_ID[save.hero];
      return `<p class="note">Level ${save.level} · ${save.xp} / ${RPG.xpToNext(save.level)} XP to the next level. Each level grants 2 skill points and a little raw strength.</p>
        <div class="points">${save.points} SKILL POINT${save.points === 1 ? '' : 'S'} TO SPEND</div>${stats}
        <div class="gain"><div><small>Sigil integrity</small><b>${d.stats.hp}</b></div><div><small>Damage</small><b>${Math.round((d.stats.power / base.stats.power) * 100)}%</b></div><div><small>Speed</small><b>${Math.round((d.stats.speed / base.stats.speed) * 100)}%</b></div><div><small>Lumen gain</small><b>${Math.round(d.stats.focus * 100)}%</b></div></div>
        <h4>Seat techniques</h4>${pk}`;
    };
    this.ui.openPanel({
      kicker: academy.name, title: 'Training Hall', accent: academy.css, body: body(),
      actions: { add: (id) => { if (save.points > 0 && save.alloc[id] < 8) { save.alloc[id]++; save.points--; RPG.storeSave(save); this.audio.play('levelUp'); this.ui.setPanelBody(body()); this.refreshCard(); } } },
      buttons: [{ label: 'Spar with a partner', onClick: () => { this.ui.closePanel(); this.sparDuel(); } }, { label: 'Done', primary: true, onClick: () => this.ui.closePanel() }],
      onClose: () => { this.hubLock = 0.3; this.input.clear(); },
    });
  }

  refreshCard() {
    const save = this.save, academy = RPG.ACADEMIES[save.academy], h = FIGHTER_BY_ID[save.hero], seat = RPG.playerSeat(save);
    this.ui.idCard({ name: h.name, school: `${academy.name} · Day ${save.day}`, seat: seat < 0 ? 'UNSEATED' : `${RPG.seatName(seat).toUpperCase()} · ${RPG.tierName(seat).toUpperCase()}`, level: save.level, xp: save.xp / RPG.xpToNext(save.level), points: save.points });
  }

  openTrials() {
    if (this.state !== 'hub') return;
    const save = this.save, order = RPG.trialOrder(save);
    const rows = order.map((id, i) => {
      const f = FIGHTER_BY_ID[id], ac = RPG.academyOfHero(id), done = i < save.trials, next = i === save.trials;
      return `<div class="${done ? 'done' : next ? 'next' : ''}" style="--c:${f.css}"><b>${esc(f.name)}</b><span>${esc(f.title)} · Crownbearer of ${esc(ac.name)} · LV ${RPG.TRIAL_LEVELS[i]}</span><em>${done ? 'DEFEATED' : next ? 'NEXT' : 'LOCKED'}</em></div>`;
    }).join('');
    const all = save.trials >= order.length;
    this.ui.openPanel({
      kicker: 'Beyond the Crown Gate', title: 'The Crown Trials', accent: '#ffc24a',
      body: `<p class="note">${all ? 'You have beaten every rival ace. The Crown of Halcyon is yours. Rematch any of them for the honor of it.' : 'Three rival Crownbearers, best of three rounds each. Beat them all and the Crown of Halcyon is yours.'}</p><div class="bracket">${rows}</div>`,
      buttons: [{ label: 'Not yet', onClick: () => this.ui.closePanel() }, { label: all ? 'Exhibition rematch' : 'Enter the Trial', primary: true, onClick: () => { this.ui.closePanel(); this.trialDuel(all ? Math.floor(Math.random() * order.length) : save.trials, all); } }],
      onClose: () => { this.hubLock = 0.3; this.input.clear(); },
    });
  }

  openMenu() {
    const inDuel = this.state === 'duel', inHub = this.state === 'hub', title = this.state === 'title';
    if (!(inDuel || inHub || title)) return;
    if (this.ui.panel) return;
    if (inDuel) { this.paused = true; this.audio.suspend(true); }
    const body = () => `
      <h4 style="margin-top:0">Controls</h4>
      <div class="keys">
        <kbd>W A S D</kbd><span>Move (left stick, or the on-screen stick)</span>
        <kbd>J</kbd><span>Attack. Press again to chain a combo (left click, X)</span>
        <kbd>K</kbd><span>Skill. Costs a third of the Lumen gauge (right click, Y)</span>
        <kbd>L / Shift</kbd><span>Guard. Tap just before a hit for a Perfect Guard (RB)</span>
        <kbd>Space</kbd><span>Dash. Briefly untouchable (A)</span>
        <kbd>I / Q</kbd><span>Ultimate, when the gauge is full (B)</span>
        <kbd>E</kbd><span>Talk, challenge or use on campus. Drag to look around</span>
      </div>
      <h4>Picture</h4>
      <div class="opt">${Object.keys(QUALITY).map((q) => `<button type="button" data-do="quality" data-arg="${q}" class="${this.settings.quality === q ? 'on' : ''}">${QUALITY[q].label}</button>`).join('')}</div>
      <h4>Sound</h4>
      <div class="opt"><button type="button" data-do="mute" data-arg="0" class="${this.settings.muted ? '' : 'on'}">On</button><button type="button" data-do="mute" data-arg="1" class="${this.settings.muted ? 'on' : ''}">Off</button></div>`;
    const buttons = [];
    if (inDuel && !(this.duelCfg && this.duelCfg.noForfeit)) buttons.push({ label: 'Forfeit the duel', onClick: () => { this.ui.closePanel(); this.forfeit(); } });
    if (inHub) buttons.push({ label: 'Save and quit to title', onClick: () => { this.ui.closePanel(); RPG.storeSave(this.save); this.showTitle(); } });
    buttons.push({ label: inDuel ? 'Resume' : 'Done', primary: true, onClick: () => this.ui.closePanel() });
    this.ui.openPanel({
      kicker: inDuel ? 'Paused' : 'Halcyon Clash', title: inDuel ? 'Duel paused' : 'Controls & settings', body: body(), buttons,
      actions: {
        quality: (q) => { this.settings.quality = q; storeSettings(this.settings); this.gfx.dynScale = 1; this.gfx.setQuality(q); this.setLocation(this.location); this.ui.setPanelBody(body()); },
        mute: (m) => { this.settings.muted = m === '1'; storeSettings(this.settings); this.audio.setMuted(this.settings.muted); this.ui.setPanelBody(body()); },
      },
      onClose: () => { if (inDuel) { this.paused = false; this.audio.suspend(false); this.last = performance.now(); } this.hubLock = 0.3; this.input.clear(); },
    });
  }

  resultPanel({ win, headline, text, gains, quote, next, nextLabel = 'Return to campus' }) {
    const g = gains.length ? `<div class="gain">${gains.map((x) => `<div class="${x.hot ? 'hot' : ''}"><small>${esc(x.label)}</small><b>${esc(x.value)}</b></div>`).join('')}</div>` : '';
    this.ui.openPanel({
      kicker: 'Duel result', title: win ? 'Sigil broken' : 'Your sigil broke', closable: false, accent: win ? '#ffc24a' : '#ff5266',
      body: `<div class="result${win ? '' : ' lost'}"><div class="big">${esc(headline)}</div><p>${esc(text)}</p></div>${g}${quote ? `<p class="note" style="margin-top:12px">${esc(quote)}</p>` : ''}`,
      buttons: [{ label: nextLabel, primary: true, onClick: () => { this.ui.closePanel(); next(); } }],
    });
  }

  // ------------------------------------------------------------ duels with stakes
  ladderDuel(idx) {
    const save = this.save, academy = RPG.ACADEMIES[save.academy], v = this.view[idx], s = v.student;
    const me = RPG.playerDef(save), seat = RPG.playerSeat(save);
    this.duelFlow({
      p1: me, p2: RPG.studentDef(s, academy), ai: s.ai, need: 1, kicker: `${RPG.seatName(idx).toUpperCase()} CHALLENGE`, label: 'DUEL',
      tags: [seat < 0 ? 'UNSEATED' : RPG.seatName(seat).toUpperCase(), RPG.seatName(idx).toUpperCase()], taunt: s.taunt,
      onEnd: (r) => {
        save.day++;
        const xp = RPG.xpReward(s.level, r.win), lv0 = save.level;
        const gains = [];
        let headline, text, quote;
        if (r.win) {
          save.wins++;
          const t = RPG.takeSeat(save, idx);
          headline = idx === 0 ? 'CROWNBEARER' : 'SEAT TAKEN';
          text = `You now hold ${RPG.seatName(idx)} of ${academy.name}. Rank: ${RPG.tierName(idx)}.`;
          gains.push({ label: 'The Register', value: `${RPG.seatName(t.before)} → ${RPG.seatName(idx)}`, hot: true });
          for (const p of t.newPerks) gains.push({ label: 'New technique', value: p.name, hot: true });
          quote = `${s.name}: “${s.lose}”`;
          this.audio.play('rankUp');
        } else {
          save.losses++;
          headline = r.forfeit ? 'FORFEIT' : 'DEFEATED'; text = `${s.name} keeps ${RPG.seatName(idx)}. Train, then try again.`;
          quote = `${s.name}: “${s.win}”`;
        }
        const up = RPG.grantXp(save, xp);
        gains.push({ label: 'Experience', value: `+${xp} XP` });
        if (up) { gains.push({ label: 'Level up', value: `LV ${lv0} → ${save.level}  ·  +${up * 2} skill pts`, hot: true }); this.audio.play('levelUp'); }
        RPG.storeSave(save);
        this.resultPanel({ win: r.win, headline, text, gains, quote, next: () => this.afterDuel(r.win && idx === 0) });
      },
    });
  }

  async afterDuel(crowned) {
    await this.enterHub();
    if (crowned) await this.talk(['Seat I. I have watched students chase that seat for years, and you took it in one term.', 'The Crown Gate at the far end of the plaza is open to you now. Three rival Crownbearers are waiting. Make us proud.']);
  }

  sparDuel() {
    const save = this.save, academy = RPG.ACADEMIES[save.academy], seat = RPG.playerSeat(save);
    const below = save.ladder.slice(seat < 0 ? 11 : Math.min(11, seat + 1)).find((id) => id !== 'player') || save.ladder.find((id) => id !== 'player');
    const s = RPG.STUDENT_BY_ID[below];
    this.duelFlow({
      p1: RPG.playerDef(save), p2: RPG.studentDef(s, academy), ai: Math.max(0, s.ai - 1), need: 1, kicker: 'TRAINING HALL SPAR', label: 'SPAR', tags: ['YOU', 'PARTNER'],
      onEnd: (r) => {
        const xp = Math.round(RPG.xpReward(s.level, r.win) * 0.4), lv0 = save.level, up = RPG.grantXp(save, xp);
        const gains = [{ label: 'Experience', value: `+${xp} XP` }];
        if (up) { gains.push({ label: 'Level up', value: `LV ${lv0} → ${save.level}  ·  +${up * 2} skill pts`, hot: true }); this.audio.play('levelUp'); }
        RPG.storeSave(save);
        this.resultPanel({ win: r.win, headline: r.win ? 'GOOD SPAR' : 'KEEP DRILLING', text: `A practice bout with ${s.name}. Seats are not at stake in the Training Hall.`, gains, next: () => this.enterHub() });
      },
    });
  }

  trialDuel(i, exhibition) {
    const save = this.save, order = RPG.trialOrder(save), id = order[i], foe = RPG.aceDef(id, RPG.TRIAL_LEVELS[i]), ac = RPG.academyOfHero(id);
    this.duelFlow({
      p1: RPG.playerDef(save), p2: foe, ai: 3, need: 2, kicker: exhibition ? 'CROWN EXHIBITION' : `CROWN TRIAL ${RPG.ROMAN[i]}`, label: 'ROUND', music: 'trial',
      tags: ['SEAT I', ac.short.toUpperCase()], taunt: `${ac.name} sends its Crownbearer. ${ac.motto}`,
      onEnd: (r) => {
        save.day++;
        const xp = RPG.xpReward(foe.level, r.win), lv0 = save.level, up = RPG.grantXp(save, xp);
        const gains = [{ label: 'Experience', value: `+${xp} XP` }];
        if (up) gains.push({ label: 'Level up', value: `LV ${lv0} → ${save.level}  ·  +${up * 2} skill pts`, hot: true });
        let headline = r.win ? 'TRIAL WON' : 'DEFEATED', text = r.win ? `${foe.name} of ${ac.name} bows out of the Trials.` : `${foe.name} holds the ring for ${ac.name}.`, final = false;
        if (r.win && !exhibition) {
          save.wins++; save.trials = Math.max(save.trials, i + 1);
          if (save.trials >= order.length) { save.champion = true; final = true; headline = 'CROWN OF HALCYON'; text = 'Every academy\'s ace has fallen to you. The whole sky-city is chanting your name.'; this.audio.play('rankUp'); }
          gains.unshift({ label: 'Crown Trials', value: `${save.trials} / ${order.length} won`, hot: true });
        } else if (!r.win) save.losses++;
        RPG.storeSave(save);
        this.resultPanel({ win: r.win, headline, text, gains, next: async () => { await this.enterHub(); if (final) await this.talk(['The Crown of Halcyon, carried home by one of ours. I do not say this often: well fought.', 'The Register will be full of students aiming at your back now. That is the price of the top seat. Enjoy it.']); } });
      },
    });
  }

  forfeit() {
    const cfg = this.duelCfg;
    this.flow++;
    this.paused = false; this.audio.suspend(false);
    this.state = 'transition';
    if (cfg) cfg.onEnd({ win: false, forfeit: true });
  }

  // ------------------------------------------------------------ the duel itself
  async duelFlow(cfg) {
    const token = ++this.flow, alive = () => token === this.flow;
    const { ui, audio, arena, cam, input } = this;
    this.state = 'transition';
    await ui.fade(true);
    if (!alive()) return;
    this.clearWorld();
    this.setLocation('arena');
    const duel = this.duel = new Duel(this.ctx, cfg.p1, cfg.p2);
    duel.controllers = [new PlayerController(input, cam), new AIController(cfg.ai)];
    duel.on((type, d) => this.onDuelEvent(type, d));
    const a = duel.a, b = duel.b;
    this.duelCfg = cfg; this.roundTime = 99; this.wins = [0, 0];
    arena.setScreen({ title: cfg.kicker, left: cfg.p1.short, right: cfg.p2.short, leftColor: cfg.p1.css, rightColor: cfg.p2.css });
    ui.setupDuel({ p1: { name: cfg.p1.name, css: cfg.p1.css, tag: cfg.tags[0] }, p2: { name: cfg.p2.name, css: cfg.p2.css, tag: cfg.tags[1] }, need: cfg.need, label: cfg.label });
    ui.setAccent(cfg.p1.css);
    ui.root('menu'); input.mode = 'menu';
    audio.music(cfg.music || 'fight'); audio.crowd(1);
    a.hold('relax', 0); b.hold('relax', 0); a.rig.setIgnite(0); b.rig.setIgnite(0);
    this.gfx.warm(this.scene, this.camera);
    cam.set('sweep', { a0: 2.1, a1: 3.45, r0: 20, r1: 11.5, h0: 9, h1: 3.4, dur: 2.7, lookY: 1.4 }, 0);
    this.state = 'duel-intro';
    await ui.fade(false);
    if (!alive()) return;
    ui.announce(cfg.kicker, `${cfg.p1.short}  vs  ${cfg.p2.short}`, 2.2, 'cool'); audio.play('round');
    await this.wait(2.4); if (!alive()) return;

    cam.set('face', { fighter: b, dist: 3.2, angle: -0.5, height: 1.5, lookY: 1.32, fov: 34, push: 2.5, pushBy: 0.5 }, 0);
    b.anim.play('intro', { blend: 0.1, force: true }); this.ignite(b, 0.7);
    ui.moveBanner(`${cfg.p2.name} · ${cfg.p2.title}`, cfg.p2.css, true);
    if (cfg.taunt) ui.caption(cfg.p2.name, cfg.taunt, cfg.p2.css, 3.0);
    await this.wait(cfg.taunt ? 3.1 : 1.7); if (!alive()) return;
    cam.set('face', { fighter: a, dist: 3.2, angle: 0.5, height: 1.5, lookY: 1.32, fov: 34, push: 2, pushBy: 0.5 }, 0);
    a.anim.play('intro', { blend: 0.1, force: true }); this.ignite(a, 0.7);
    ui.moveBanner(`${cfg.p1.name} · ${cfg.p1.title}`, cfg.p1.css, false);
    await this.wait(1.6); if (!alive()) return;
    ui.show('hud');

    let round = 0;
    for (;;) {
      round++;
      if (round > 1) {
        await ui.fade(true, 200); if (!alive()) return;
        const ea = a.energy, eb = b.energy;
        duel.place(); this.fx.clear(); a.energy = ea; b.energy = eb;
        a.hold('idle', 0); b.hold('idle', 0);
        cam.set('duel', { player: a, enemy: b }, 0);
        await ui.fade(false, 200); if (!alive()) return;
      } else { a.hold('idle', 0.3); b.hold('idle', 0.3); cam.set('duel', { player: a, enemy: b }, 0.8); }
      if (cfg.p1.perks && cfg.p1.perks.over) a.energy = Math.max(a.energy, 50);
      this.roundTime = 99;
      ui.root('duel'); input.mode = 'duel'; input.clear();
      ui.announce(cfg.need > 1 ? `ROUND ${round}` : cfg.label, 'Break their sigil', 1.2, 'cool'); audio.play('round');
      await this.wait(1.35); if (!alive()) return;
      ui.announce('FIGHT!', '', 0.7); audio.play('fight');
      a.release(); b.release(); duel.fightOn = true; this.state = 'duel';
      const out = await new Promise((res) => { this.roundResolve = res; });
      if (!alive()) return;
      this.state = 'duel-ko';
      const won = out.winner === a;
      if (out.timeUp) {
        ui.announce('TIME UP', `${out.winner.def.short} holds more of their sigil`, 2.4, won ? '' : 'bad');
        out.loser.hold('hit2', 0.2); out.winner.celebrate();
        cam.set('face', { fighter: out.winner, dist: 3.5, angle: won ? 0.5 : -0.5, height: 1.25, lookY: 1.25, fov: 36, spin: 0.1 }, 0.6);
        await this.wait(2.6); if (!alive()) return;
      } else {
        this.timeScale = 0.2; this.gfx.post.uFlash.value = 0.3;
        cam.set('ko', { loser: out.loser, winner: out.winner }, 0.25);
        ui.announce('SIGIL BREAK', `${out.winner.def.name} wins`, 2.8, won ? '' : 'bad');
        await this.wait(1.3); if (!alive()) return;
        this.timeScale = 1;
        await this.wait(0.8); if (!alive()) return;
        out.winner.celebrate();
        cam.set('face', { fighter: out.winner, dist: 3.5, angle: won ? 0.5 : -0.5, height: 1.25, lookY: 1.25, fov: 36, spin: 0.1 }, 0.6);
        await this.wait(2.0); if (!alive()) return;
      }
      this.wins[won ? 0 : 1]++;
      ui.setPips(this.wins[0], this.wins[1]);
      if (this.wins[0] >= cfg.need || this.wins[1] >= cfg.need) break;
    }
    ui.root('menu'); input.mode = 'menu';
    const win = this.wins[0] >= cfg.need;
    audio.play(win ? 'win' : 'lose'); audio.crowd(0.5);
    this.state = 'duel-end';
    await this.wait(0.5); if (!alive()) return;
    cfg.onEnd({ win });
  }

  ignite(f, delay) { this.wait(delay).then(() => { if (this.duel && this.duel.fighters.includes(f)) { f.rig.setIgnite(1); this.audio.play('special'); this.fx.flare(f.rig.weapon.muzzle.getWorldPosition(_v), f.def.accent, 2.2, 0.25, 3); } }); }

  onDuelEvent(type, d) {
    const duel = this.duel, ui = this.ui;
    if (!duel || duel.demo) { if (type === 'cutin') this.letterbox = 0.1; if (type === 'cutinEnd') this.letterbox = 0; return; }
    const a = duel.a;
    if (type === 'hit') {
      const p = this.project(d.pos);
      if (p.front) {
        ui.damage(p.x + (Math.random() - 0.5) * 30, p.y, String(Math.round(d.dmg)), d.heavy ? 'big' : '', d.attacker.def.css);
        if (d.broke) ui.damage(p.x, p.y - 34, 'GUARD BREAK', 'note', '#ff5266');
        if (d.armor) ui.damage(p.x, p.y - 30, 'ARMOR', 'note', d.target.def.css);
      }
      if (d.heavy) this.gfx.post.uFlash.value = Math.max(this.gfx.post.uFlash.value, 0.12);
      if (d.heavy) this.audio.cheer(0.6);
    } else if (type === 'guard') {
      const p = this.project(d.fighter.chest(_v));
      if (p.front && d.fighter === a) ui.damage(p.x, p.y - 20, 'GUARD', 'note', '#bfe6ff');
    } else if (type === 'parry') {
      const p = this.project(d.fighter.chest(_v));
      if (p.front) ui.damage(p.x, p.y - 30, 'PERFECT GUARD', 'big', '#ffffff');
      this.audio.cheer(0.8);
    } else if (type === 'special') {
      ui.moveBanner(d.name, d.fighter.def.css, d.fighter !== a);
    } else if (type === 'cutin') {
      const f = d.fighter;
      ui.cutIn(d.name, `${f.def.name} · ULTIMATE`, f.def.css);
      this.cam.set('face', { fighter: f, dist: 2.9, angle: f === a ? 1.2 : -1.2, height: 1.45, lookY: 1.38, fov: 32, push: 0.9, pushBy: 0.5 }, 0.1);
      this.letterbox = 0.12;
      this.gfx.post.uSaturation.value = 1.25;
      this.audio.cheer(1);
    } else if (type === 'cutinEnd') {
      ui.cutInEnd();
      this.cam.set('duel', { player: duel.a, enemy: duel.b }, 0.35);
      this.letterbox = 0; this.gfx.post.uSaturation.value = 1.08;
      this.gfx.post.uFlash.value = 0.35;
    } else if (type === 'wind') {
      ui.toast('SECOND WIND');
    } else if (type === 'ko') {
      this.audio.cheer(1.6);
      if (this.roundResolve) { const r = this.roundResolve; this.roundResolve = null; r({ winner: d.winner, loser: d.loser }); }
    }
  }

  // ------------------------------------------------------------ frame
  loop(now) {
    requestAnimationFrame(this.loop);
    const raw = Math.min(0.05, Math.max(0, (now - this.last) / 1000));
    this.last = now;
    if (this.manual) return;            // test harness drives step()/draw() itself
    this.step(raw);
    this.draw(raw);
  }

  /** Advance the game by `raw` seconds (no rendering). */
  step(raw) {
    const { input, ui, gfx, cam } = this;
    input.update();

    // dialogue / panel / select shortcuts
    if (ui.dlg) { if (input.take('advance') || input.take('interact') || input.take('confirm')) ui.advance(); }
    else if (ui.panel) { if (input.take('pause')) ui.closePanel(true); }
    else if (this.state === 'select') {
      if (this.selAxis === undefined) this.selAxis = 0;
      const ax = Math.abs(input.x) > 0.6 ? Math.sign(input.x) : 0;
      if (ax !== this.selAxis) { this.selAxis = ax; if (ax) ui.selectStep(ax); }
      if (input.take('confirm')) ui.selectGo();
    } else if (this.state === 'duel' && input.take('pause')) this.openMenu();

    if (!this.paused) {
      this.time += raw;
      for (let i = this.timers.length - 1; i >= 0; i--) { const t = this.timers[i]; t.t -= raw; if (t.t <= 0) { this.timers.splice(i, 1); t.res(); } }
      let simDt = raw * this.timeScale, fxDt = simDt;
      const duel = this.duel;
      if (duel) {
        const used = duel.update(simDt);
        fxDt = used > 0 ? used : raw * 0.12;
        if (duel.fightOn && !duel.cutIn && used > 0 && !duel.demo) {
          this.roundTime -= used;
          if (this.roundTime <= 0 && this.roundResolve) {
            duel.fightOn = false;
            const a = duel.a, b = duel.b, aw = a.hp / a.maxHp >= b.hp / b.maxHp;
            const r = this.roundResolve; this.roundResolve = null;
            r({ winner: aw ? a : b, loser: aw ? b : a, timeUp: true });
          }
        }
        if (!duel.demo && this.state.startsWith('duel')) ui.updateDuel(duel.a, duel.b, this.roundTime, raw);
      }
      if (this.explorer && this.state === 'hub') this.updateHub(raw);
      const sc = this.showcase;
      if (sc) {
        sc.t += raw;
        if (sc.anim.done) sc.anim.play('idle', { blend: 0.25 });
        sc.anim.update(raw); sc.rig.updateSecondary(raw, _v.set(0, 0, 0), 0, this.time);
        const l = this.fx.weaponLights[0]; sc.rig.weapon.muzzle.getWorldPosition(l.position); l.intensity = 16;
      }
      this.fx.update(fxDt, this.camera, gfx.height);
      cam.update(raw, gfx.width / gfx.height);
      this.arena.update(raw, gfx.height, this.camera.fov);
      if (this.campus.group.visible) this.campus.update(raw, gfx.height, this.camera.fov);
      ui.update(raw);
      // post-processing that eases back to rest
      const post = gfx.post;
      post.uLetterbox.value += (this.letterbox - post.uLetterbox.value) * Math.min(1, raw * 10);
      post.uFlash.value = Math.max(0, post.uFlash.value - raw * 2.8);
      post.uAberration.value = 0.006 + cam.trauma * 0.04;
      post.uVignette.value = 0.75 + (this.timeScale < 1 ? 0.2 : 0);
    }
  }

  draw(raw) {
    const gfx = this.gfx;
    gfx.render(this.scene, this.camera, this.time);
    this.frames++;

    // dynamic resolution keeps the frame rate up on slower GPUs
    if (this.drs && !this.paused) {
      this.frameAvg += (raw * 1000 - this.frameAvg) * 0.05;
      this.drsCool -= raw;
      if (this.drsCool <= 0) {
        if (this.frameAvg > 23 && gfx.dynScale > 0.56) { gfx.dynScale = Math.max(0.55, gfx.dynScale - 0.12); gfx.resize(true); this.drsCool = 1.5; }
        else if (this.frameAvg > 30 && gfx.dynScale <= 0.56 && gfx.qualityName !== 'low') {
          this.settings.quality = gfx.qualityName === 'high' ? 'medium' : 'low';
          gfx.dynScale = 0.8; gfx.setQuality(this.settings.quality); this.setLocation(this.location);
          this.ui.toast(`Picture set to ${QUALITY[this.settings.quality].label} to keep the fight smooth`);
          this.drsCool = 3; this.frameAvg = 16;
        }
        else if (this.frameAvg < 12.5 && gfx.dynScale < 1) { gfx.dynScale = Math.min(1, gfx.dynScale + 0.06); gfx.resize(true); this.drsCool = 2.5; }
      }
    }
  }
}

function start() {
  try { window.__game = new Game(); } catch (e) { console.error(e); }
}
if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', start); else start();

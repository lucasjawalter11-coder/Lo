// Rendering pipeline: HDR scene target -> planar floor reflection -> multi-level bloom
// -> filmic tone mapping, grading, vignette and grain.
import * as THREE from './three.js';

const FS_VERT = /* glsl */ `
varying vec2 vUv;
void main() { vUv = uv; gl_Position = vec4(position.xy, 0.0, 1.0); }
`;

const PREFILTER_FRAG = /* glsl */ `
precision highp float;
varying vec2 vUv;
uniform sampler2D tSrc;
uniform vec2 uTexel;
uniform float uThreshold;
uniform float uKnee;
vec3 pre(vec3 c) {
  c = min(c, vec3(40.0));
  float br = max(c.r, max(c.g, c.b));
  float soft = clamp(br - uThreshold + uKnee, 0.0, 2.0 * uKnee);
  soft = soft * soft / (4.0 * uKnee + 1e-4);
  float contrib = max(soft, br - uThreshold) / max(br, 1e-4);
  return c * contrib;
}
void main() {
  vec3 a = pre(texture2D(tSrc, vUv + uTexel * vec2(-1.0, -1.0)).rgb);
  vec3 b = pre(texture2D(tSrc, vUv + uTexel * vec2( 1.0, -1.0)).rgb);
  vec3 c = pre(texture2D(tSrc, vUv + uTexel * vec2(-1.0,  1.0)).rgb);
  vec3 d = pre(texture2D(tSrc, vUv + uTexel * vec2( 1.0,  1.0)).rgb);
  // Karis average tames single-pixel fireflies
  float wa = 1.0 / (1.0 + max(a.r, max(a.g, a.b)));
  float wb = 1.0 / (1.0 + max(b.r, max(b.g, b.b)));
  float wc = 1.0 / (1.0 + max(c.r, max(c.g, c.b)));
  float wd = 1.0 / (1.0 + max(d.r, max(d.g, d.b)));
  gl_FragColor = vec4((a * wa + b * wb + c * wc + d * wd) / (wa + wb + wc + wd), 1.0);
}
`;

const DOWN_FRAG = /* glsl */ `
precision highp float;
varying vec2 vUv;
uniform sampler2D tSrc;
uniform vec2 uTexel;
void main() {
  vec2 px = uTexel;
  vec3 a = texture2D(tSrc, vUv + px * vec2(-2.0,  2.0)).rgb;
  vec3 b = texture2D(tSrc, vUv + px * vec2( 0.0,  2.0)).rgb;
  vec3 c = texture2D(tSrc, vUv + px * vec2( 2.0,  2.0)).rgb;
  vec3 d = texture2D(tSrc, vUv + px * vec2(-2.0,  0.0)).rgb;
  vec3 e = texture2D(tSrc, vUv).rgb;
  vec3 f = texture2D(tSrc, vUv + px * vec2( 2.0,  0.0)).rgb;
  vec3 g = texture2D(tSrc, vUv + px * vec2(-2.0, -2.0)).rgb;
  vec3 h = texture2D(tSrc, vUv + px * vec2( 0.0, -2.0)).rgb;
  vec3 i = texture2D(tSrc, vUv + px * vec2( 2.0, -2.0)).rgb;
  vec3 j = texture2D(tSrc, vUv + px * vec2(-1.0,  1.0)).rgb;
  vec3 k = texture2D(tSrc, vUv + px * vec2( 1.0,  1.0)).rgb;
  vec3 l = texture2D(tSrc, vUv + px * vec2(-1.0, -1.0)).rgb;
  vec3 m = texture2D(tSrc, vUv + px * vec2( 1.0, -1.0)).rgb;
  vec3 col = e * 0.125 + (a + c + g + i) * 0.03125 + (b + d + f + h) * 0.0625 + (j + k + l + m) * 0.125;
  gl_FragColor = vec4(col, 1.0);
}
`;

const UP_FRAG = /* glsl */ `
precision highp float;
varying vec2 vUv;
uniform sampler2D tSrc;
uniform vec2 uTexel;
uniform float uWeight;
void main() {
  vec2 px = uTexel;
  vec3 col = texture2D(tSrc, vUv).rgb * 4.0;
  col += texture2D(tSrc, vUv + px * vec2(-1.0, 0.0)).rgb * 2.0;
  col += texture2D(tSrc, vUv + px * vec2( 1.0, 0.0)).rgb * 2.0;
  col += texture2D(tSrc, vUv + px * vec2( 0.0,-1.0)).rgb * 2.0;
  col += texture2D(tSrc, vUv + px * vec2( 0.0, 1.0)).rgb * 2.0;
  col += texture2D(tSrc, vUv + px * vec2(-1.0,-1.0)).rgb;
  col += texture2D(tSrc, vUv + px * vec2( 1.0,-1.0)).rgb;
  col += texture2D(tSrc, vUv + px * vec2(-1.0, 1.0)).rgb;
  col += texture2D(tSrc, vUv + px * vec2( 1.0, 1.0)).rgb;
  gl_FragColor = vec4(col / 16.0 * uWeight, 1.0);
}
`;

const COMPOSITE_FRAG = /* glsl */ `
precision highp float;
varying vec2 vUv;
uniform sampler2D tScene;
uniform sampler2D tBloom;
uniform float uBloom;
uniform float uExposure;
uniform float uTime;
uniform float uVignette;
uniform float uGrain;
uniform float uAberration;
uniform float uRadial;
uniform vec2 uRadialCenter;
uniform float uSaturation;
uniform float uFlash;
uniform vec3 uFlashColor;
uniform float uFade;
uniform float uLetterbox;
uniform float uAspect;

float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }

vec3 RRTAndODTFit(vec3 v) {
  vec3 a = v * (v + 0.0245786) - 0.000090537;
  vec3 b = v * (0.983729 * v + 0.4329510) + 0.238081;
  return a / b;
}
vec3 aces(vec3 color) {
  const mat3 inM = mat3(0.59719, 0.07600, 0.02840, 0.35458, 0.90834, 0.13383, 0.04823, 0.01566, 0.83777);
  const mat3 outM = mat3(1.60475, -0.10208, -0.00327, -0.53108, 1.10813, -0.07276, -0.07367, -0.00605, 1.07602);
  color = inM * color;
  color = RRTAndODTFit(color);
  color = outM * color;
  return clamp(color, 0.0, 1.0);
}
vec3 toSRGB(vec3 c) {
  return mix(c * 12.92, 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, step(0.0031308, c));
}
vec3 sampleScene(vec2 uv) {
  return texture2D(tScene, uv).rgb + texture2D(tBloom, uv).rgb * uBloom;
}
void main() {
  vec2 uv = vUv;
  vec2 fromCenter = uv - 0.5;
  float r2 = dot(fromCenter, fromCenter);
  vec3 col;
  if (uRadial > 0.001) {
    vec2 dir = (uv - uRadialCenter) * uRadial;
    float jitter = hash(uv * 913.0 + uTime) * 0.12;
    col = vec3(0.0);
    for (int i = 0; i < 8; i++) {
      float t = (float(i) + jitter) / 8.0;
      col += sampleScene(uv - dir * t);
    }
    col /= 8.0;
  } else {
    vec2 ca = fromCenter * r2 * uAberration;
    col.r = sampleScene(uv + ca).r;
    col.g = sampleScene(uv).g;
    col.b = sampleScene(uv - ca).b;
  }
  col += uFlashColor * uFlash;
  col = aces(col * uExposure / 0.6);
  // grade: gentle teal shadows / warm highlights, then saturation
  float luma = dot(col, vec3(0.2126, 0.7152, 0.0722));
  col = mix(col, col * vec3(0.94, 1.0, 1.08), (1.0 - luma) * 0.45);
  col = mix(col, col * vec3(1.05, 1.0, 0.95), luma * 0.35);
  col = mix(vec3(luma), col, uSaturation);
  // vignette
  float vig = smoothstep(0.85, 0.2, r2 * 2.2);
  col *= mix(1.0, vig, uVignette);
  col = toSRGB(col);
  col += (hash(uv * vec2(1920.0, 1080.0) + fract(uTime) * 61.0) - 0.5) * uGrain;
  // cinematic bars
  float bar = step(uLetterbox * 0.5, uv.y) * step(uv.y, 1.0 - uLetterbox * 0.5);
  col *= bar;
  col *= uFade;
  gl_FragColor = vec4(col, 1.0);
}
`;

export const QUALITY = {
  low:    { label: 'Performance', maxPR: 1.0,  msaa: 0, shadows: false, shadowSize: 1024, reflections: false, bloomLevels: 4 },
  medium: { label: 'Balanced',    maxPR: 1.25, msaa: 2, shadows: true,  shadowSize: 1024, reflections: true,  bloomLevels: 5 },
  high:   { label: 'Cinematic',   maxPR: 2.0,  msaa: 4, shadows: true,  shadowSize: 2048, reflections: true,  bloomLevels: 6 },
};

export class Gfx {
  constructor(canvas, container) {
    this.canvas = canvas;
    this.container = container;
    const renderer = new THREE.WebGLRenderer({
      canvas, antialias: false, alpha: false, stencil: false, depth: true, powerPreference: 'high-performance',
    });
    this.renderer = renderer;
    renderer.autoClear = true;
    renderer.setClearColor(0x05060d, 1);
    renderer.toneMapping = THREE.NoToneMapping;
    renderer.outputColorSpace = THREE.SRGBColorSpace;
    renderer.shadowMap.enabled = true;
    renderer.shadowMap.type = THREE.PCFSoftShadowMap;
    renderer.shadowMap.autoUpdate = false;
    renderer.info.autoReset = false;

    const gl = renderer.getContext();
    this.isWebGL2 = typeof WebGL2RenderingContext !== 'undefined' && gl instanceof WebGL2RenderingContext;
    this.hdr = this.isWebGL2 && (renderer.extensions.has('EXT_color_buffer_float') || renderer.extensions.has('EXT_color_buffer_half_float'));
    this.texType = this.hdr ? THREE.HalfFloatType : THREE.UnsignedByteType;

    this.qualityName = 'high';
    this.q = QUALITY.high;
    this.dynScale = 1.0;       // dynamic resolution multiplier (0.55..1)
    this.width = 2; this.height = 2;

    // fullscreen pass plumbing
    const tri = new THREE.BufferGeometry();
    tri.setAttribute('position', new THREE.BufferAttribute(new Float32Array([-1, -1, 0, 3, -1, 0, -1, 3, 0]), 3));
    tri.setAttribute('uv', new THREE.BufferAttribute(new Float32Array([0, 0, 2, 0, 0, 2]), 2));
    this.fsCam = new THREE.OrthographicCamera(-1, 1, 1, -1, 0, 1);
    this.fsMesh = new THREE.Mesh(tri, null);
    this.fsMesh.frustumCulled = false;
    this.fsScene = new THREE.Scene();
    this.fsScene.add(this.fsMesh);

    const mk = (frag, uniforms, extra = {}) => new THREE.ShaderMaterial({
      vertexShader: FS_VERT, fragmentShader: frag, uniforms, depthTest: false, depthWrite: false, ...extra,
    });
    this.matPrefilter = mk(PREFILTER_FRAG, {
      tSrc: { value: null }, uTexel: { value: new THREE.Vector2() }, uThreshold: { value: 1.0 }, uKnee: { value: 0.6 },
    });
    this.matDown = mk(DOWN_FRAG, { tSrc: { value: null }, uTexel: { value: new THREE.Vector2() } });
    this.matUp = mk(UP_FRAG, { tSrc: { value: null }, uTexel: { value: new THREE.Vector2() }, uWeight: { value: 1.0 } },
      { blending: THREE.AdditiveBlending, transparent: true });
    this.matComposite = mk(COMPOSITE_FRAG, {
      tScene: { value: null }, tBloom: { value: null },
      uBloom: { value: 0.22 }, uExposure: { value: 1.0 }, uTime: { value: 0 },
      uVignette: { value: 0.75 }, uGrain: { value: 0.035 }, uAberration: { value: 0.012 },
      uRadial: { value: 0 }, uRadialCenter: { value: new THREE.Vector2(0.5, 0.5) },
      uSaturation: { value: 1.08 }, uFlash: { value: 0 }, uFlashColor: { value: new THREE.Color(1, 1, 1) },
      uFade: { value: 1 }, uLetterbox: { value: 0 }, uAspect: { value: 1 },
    });
    this.post = this.matComposite.uniforms;

    // planar reflection
    this.reflection = {
      enabled: true,
      texture: { value: null },
      blurTexture: { value: null },
      matrix: { value: new THREE.Matrix4() },
      strength: { value: 1.0 },
    };
    this.virtCam = new THREE.PerspectiveCamera();
    this.virtCam.layers.set(0);
    this._v = { camPos: new THREE.Vector3(), look: new THREE.Vector3(), rot: new THREE.Matrix4(), up: new THREE.Vector3() };

    this.sceneRT = null; this.reflRT = null; this.reflBlurA = null; this.reflBlurB = null; this.mips = [];
    this.shadowLight = null;
    this.setQuality(this.qualityName, true);
  }

  setQuality(name, skipResize) {
    this.qualityName = name;
    this.q = QUALITY[name] || QUALITY.high;
    this.reflection.enabled = this.q.reflections;
    this.reflection.strength.value = this.q.reflections ? 1.0 : 0.0;
    if (this.shadowLight) this._applyShadowQuality();
    if (!skipResize) this.resize(true);
  }

  registerShadowLight(light) { this.shadowLight = light; this._applyShadowQuality(); }

  _applyShadowQuality() {
    const l = this.shadowLight;
    l.castShadow = this.q.shadows;
    if (l.shadow.mapSize.x !== this.q.shadowSize) {
      l.shadow.mapSize.set(this.q.shadowSize, this.q.shadowSize);
      if (l.shadow.map) { l.shadow.map.dispose(); l.shadow.map = null; }
    }
  }

  get pixelRatio() {
    return Math.min(window.devicePixelRatio || 1, this.q.maxPR) * this.dynScale;
  }

  resize(force) {
    const cw = Math.max(2, this.container.clientWidth), ch = Math.max(2, this.container.clientHeight);
    const pr = this.pixelRatio;
    const w = Math.max(2, Math.round(cw * pr)), h = Math.max(2, Math.round(ch * pr));
    if (!force && w === this.width && h === this.height) return false;
    this.width = w; this.height = h; this.cssW = cw; this.cssH = ch;
    this.renderer.setPixelRatio(1);
    this.renderer.setSize(w, h, false);
    this._buildTargets();
    return true;
  }

  _buildTargets() {
    const { width: w, height: h } = this;
    const dispose = (t) => t && t.dispose();
    dispose(this.sceneRT); dispose(this.reflRT); dispose(this.reflBlurA); dispose(this.reflBlurB); this.mips.forEach(dispose);
    this.sceneRT = new THREE.WebGLRenderTarget(w, h, {
      type: this.texType, samples: this.isWebGL2 ? this.q.msaa : 0, depthBuffer: true,
      minFilter: THREE.LinearFilter, magFilter: THREE.LinearFilter,
    });
    const rw = Math.max(2, w >> 1), rh = Math.max(2, h >> 1);
    this.reflRT = new THREE.WebGLRenderTarget(rw, rh, {
      type: this.texType, depthBuffer: true, minFilter: THREE.LinearFilter, magFilter: THREE.LinearFilter,
    });
    const blurOpts = { type: this.texType, depthBuffer: false, minFilter: THREE.LinearFilter, magFilter: THREE.LinearFilter };
    this.reflBlurA = new THREE.WebGLRenderTarget(Math.max(2, rw >> 1), Math.max(2, rh >> 1), blurOpts);
    this.reflBlurB = new THREE.WebGLRenderTarget(Math.max(2, rw >> 2), Math.max(2, rh >> 2), blurOpts);
    this.reflection.texture.value = this.reflRT.texture;
    this.reflection.blurTexture.value = this.reflBlurB.texture;
    this.mips = [];
    let mw = w, mh = h;
    for (let i = 0; i < this.q.bloomLevels; i++) {
      mw = Math.max(2, mw >> 1); mh = Math.max(2, mh >> 1);
      this.mips.push(new THREE.WebGLRenderTarget(mw, mh, {
        type: this.texType, depthBuffer: false, minFilter: THREE.LinearFilter, magFilter: THREE.LinearFilter,
      }));
    }
    this.post.uAspect.value = w / h;
  }

  _pass(material, target) {
    this.fsMesh.material = material;
    this.renderer.setRenderTarget(target);
    this.renderer.render(this.fsScene, this.fsCam);
  }

  _updateVirtualCamera(camera) {
    // mirror the camera through the floor plane y = 0
    const v = this._v, vc = this.virtCam;
    v.camPos.setFromMatrixPosition(camera.matrixWorld);
    v.rot.extractRotation(camera.matrixWorld);
    v.look.set(0, 0, -1).applyMatrix4(v.rot).add(v.camPos);
    v.up.set(0, 1, 0).applyMatrix4(v.rot);
    vc.position.set(v.camPos.x, -v.camPos.y, v.camPos.z);
    vc.up.set(v.up.x, -v.up.y, v.up.z);
    vc.lookAt(v.look.x, -v.look.y, v.look.z);
    vc.near = camera.near; vc.far = camera.far;
    vc.updateMatrixWorld();
    vc.projectionMatrix.copy(camera.projectionMatrix);
    vc.projectionMatrixInverse.copy(camera.projectionMatrixInverse);
    const m = this.reflection.matrix.value;
    m.set(0.5, 0, 0, 0.5, 0, 0.5, 0, 0.5, 0, 0, 0.5, 0.5, 0, 0, 0, 1);
    m.multiply(vc.projectionMatrix);
    m.multiply(vc.matrixWorldInverse);
  }

  render(scene, camera, time) {
    const r = this.renderer;
    r.info.reset();
    r.shadowMap.needsUpdate = this.q.shadows;

    if (this.reflection.enabled && camera.position.y > 0.05) {
      this._updateVirtualCamera(camera);
      this.reflection.texture.value = null; // never sample the targets while drawing into them
      this.reflection.blurTexture.value = null;
      r.setRenderTarget(this.reflRT);
      r.render(scene, this.virtCam);
      this.matDown.uniforms.tSrc.value = this.reflRT.texture;
      this.matDown.uniforms.uTexel.value.set(1 / this.reflRT.width, 1 / this.reflRT.height);
      this._pass(this.matDown, this.reflBlurA);
      this.matDown.uniforms.tSrc.value = this.reflBlurA.texture;
      this.matDown.uniforms.uTexel.value.set(1 / this.reflBlurA.width, 1 / this.reflBlurA.height);
      this._pass(this.matDown, this.reflBlurB);
      this.reflection.texture.value = this.reflRT.texture;
      this.reflection.blurTexture.value = this.reflBlurB.texture;
    }

    r.setRenderTarget(this.sceneRT);
    r.render(scene, camera);

    // bloom: threshold + downsample chain, then additive tent upsample back up
    const mips = this.mips;
    this.matPrefilter.uniforms.tSrc.value = this.sceneRT.texture;
    this.matPrefilter.uniforms.uTexel.value.set(1 / this.width, 1 / this.height);
    this._pass(this.matPrefilter, mips[0]);
    for (let i = 1; i < mips.length; i++) {
      this.matDown.uniforms.tSrc.value = mips[i - 1].texture;
      this.matDown.uniforms.uTexel.value.set(1 / mips[i - 1].width, 1 / mips[i - 1].height);
      this._pass(this.matDown, mips[i]);
    }
    r.autoClear = false;
    for (let i = mips.length - 1; i > 0; i--) {
      this.matUp.uniforms.tSrc.value = mips[i].texture;
      this.matUp.uniforms.uTexel.value.set(1 / mips[i].width, 1 / mips[i].height);
      this._pass(this.matUp, mips[i - 1]);
    }
    r.autoClear = true;

    this.post.tScene.value = this.sceneRT.texture;
    this.post.tBloom.value = mips[0].texture;
    this.post.uTime.value = time;
    this._pass(this.matComposite, null);
  }
}

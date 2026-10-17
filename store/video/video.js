'use strict';
/*
 * Macro Lens – Store-Video (1080x1920, vertikal).
 *
 * Alles ist eine reine Funktion des virtuellen Takts t (Sekunden): render(t).
 * Kein Date.now(), kein Math.random() -> jeder Frame reproduzierbar.
 * Die App-Oberflaeche ist nach src/screens/live.gd, src/ui/ui.gd, src/ui/anim.gd
 * und den Widgets nachgebaut (gleiche Masse, Farben, Tween-Dauern, Wischlogik).
 *
 * Init: await init(lang)  -> laedt out/vo_<lang>.json + out/words_<lang>.json
 * Danach: render(t), plan() (Audio-Plan fuer mix.py), DURATION
 */

// ---------------------------------------------------------------------------
// Grundlagen
// ---------------------------------------------------------------------------
const W = 1080, H = 1920;
const C = {
  bg: '#0F1113', surface: '#17191C', surface2: '#1F2227', line: '#2A2E34', text: '#ECEEF0',
  muted: '#8B9199', faint: '#5B6068', accent: '#F0A020', on_accent: '#141514',
  good: '#4CC38A', bad: '#E5484D', warn: '#E8B931', protein: '#4C8DF6', carbs: '#F0A020', fat: '#E5684D',
};
const clamp = (x, a = 0, b = 1) => Math.min(b, Math.max(a, x));
const lerp = (a, b, t) => a + (b - a) * t;
const E = {
  lin: t => t,
  cubicIO: t => t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2,
  cubicOut: t => 1 - Math.pow(1 - t, 3),
  cubicIn: t => t * t * t,
  quartOut: t => 1 - Math.pow(1 - t, 4),
  quadOut: t => 1 - (1 - t) * (1 - t),
  sineIO: t => -(Math.cos(Math.PI * t) - 1) / 2,
  backOut: t => { const c1 = 1.70158, c3 = c1 + 1; return 1 + c3 * Math.pow(t - 1, 3) + c1 * Math.pow(t - 1, 2); },
};
/** Fortschritt eines Tweens: Start s, Dauer d. */
const P = (t, s, d, e = E.cubicIO) => e(clamp((t - s) / d));
const hex2rgb = h => [1, 3, 5].map(i => parseInt(h.slice(i, i + 2), 16));
const rgb2hex = c => '#' + c.map(v => Math.round(clamp(v, 0, 255)).toString(16).padStart(2, '0')).join('');
const mixHex = (a, b, t) => { const A = hex2rgb(a), B = hex2rgb(b); return rgb2hex(A.map((v, i) => lerp(v, B[i], t))); };
const esc = s => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;');

/** Deterministischer PRNG (fuer Regal-Layout etc.). */
function mulberry32(a) {
  return function () {
    a |= 0; a = a + 0x6D2B79F5 | 0;
    let t = Math.imul(a ^ a >>> 15, 1 | a);
    t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t;
    return ((t ^ t >>> 14) >>> 0) / 4294967296;
  };
}

// ---------------------------------------------------------------------------
// Texte
// ---------------------------------------------------------------------------
let LANG = 'de';
const TX = {
  scan_hint: ['Barcode scannen', 'Scan barcode'],
  attribution: ['Daten: Open Food Facts (ODbL) · Generika: USDA FoodData Central', 'Data: Open Food Facts (ODbL) · Basics: USDA FoodData Central'],
  loading: ['Lade Produkt …', 'Loading product …'],
  search: ['SUCHEN', 'SEARCH'], history: ['VERLAUF', 'HISTORY'], settings: ['EINSTELLUNGEN', 'SETTINGS'],
  unpackaged: ['UNVERPACKT', 'UNPACKAGED'],
  unpackaged_hint: ['Grundnahrungsmittel durchsuchen …', 'Search basic foods …'],
  barcode: ['Barcode', 'Barcode'],
  lbl_macros: ['MAKROS', 'MACROS'], lbl_density: ['DICHTE', 'DENSITY'], lbl_protein: ['EIWEISS', 'PROTEIN'], lbl_satiety: ['SÄTTIGUNG', 'SATIETY'],
  protein_short: ['Eiweiß', 'Protein'], carbs_short: ['KH', 'Carbs'], fat_short: ['Fett', 'Fat'],
  kcal_100g: ['kcal/100 g', 'kcal/100 g'], unit_g_100kcal: ['g/100 kcal', 'g/100 kcal'], of_100: ['von 100', 'of 100'],
  best: ['BEST', 'BEST'], swipe_pin: ['PINNEN', 'PIN'], swipe_out: ['ENTFERNEN', 'REMOVE'],
  hint_pin: ['nach unten wischen = pinnen', 'swipe down = pin'], hint_out: ['nach oben wischen = entfernen', 'swipe up = remove'],
  // Video
  cap_problem: ['Regal voll.\nEtikett klein.\nZeit knapp.', 'Shelves full.\nLabels tiny.\nNo time.'],
  cap_scan: ['Ein Scan.\nVier Grafiken.', 'One scan.\nFour charts.'],
  cap_q1: ['Woraus kommen\ndie Kalorien?', 'Where do the\ncalories come from?'],
  cap_q2: ['Wie viel\nEnergie?', 'How much\nenergy?'],
  cap_q3: ['Wie viel\nEiweiß?', 'How much\nprotein?'],
  cap_q4: ['Wie\nsättigend?', 'How\nfilling?'],
  cap_pin: ['Nach unten wischen\n= pinnen.', 'Swipe down\nto pin.'],
  cap_compare: ['Bis zu vier\nvergleichen.', 'Compare\nup to four.'],
  cap_remove: ['Nach oben wischen\n= entfernen.', 'Swipe up\nto remove.'],
  cap_grade: ['Andere geben\ndir eine Note.', 'Others give\nyou a grade.'],
  cap_numbers: ['Macro Lens gibt\ndir die Zahlen.', 'Macro Lens gives\nyou the numbers.'],
  m_problem: ['Supermarkt', 'Supermarket'], m_scan: ['Dauerscan', 'Live scan'], m_charts: ['Die vier Grafiken', 'The four charts'],
  m_pin: ['Geste', 'Gesture'], m_compare: ['Vergleich', 'Compare'], m_grade: ['Kein Notensystem', 'No grades'],
  grade_title: ['NOTE', 'GRADE'], grade_sub: ['Knusper-Müsli Nuss', 'Knusper-Müsli Nuss'],
  end_1: ['Kein Konto · Keine Werbung · Kein Tracking', 'No account · No ads · No tracking'],
  end_2: ['Ein Messgerät, kein Tagebuch.', 'A measuring device, not a diary.'],
  end_3: ['Android · Open Source', 'Android · Open Source'],
  gesund: ['GESUND!', 'HEALTHY!'],
  table: [['Nährwerte pro 100 g', 'Energie 1682 kJ / 402 kcal', 'Fett 11 g', 'davon gesättigte Fettsäuren 2,1 g', 'Kohlenhydrate 58 g', 'davon Zucker 19 g', 'Ballaststoffe 7,5 g', 'Eiweiß 9,2 g', 'Salz 0,4 g'],
          ['Nutrition per 100 g', 'Energy 1682 kJ / 402 kcal', 'Fat 11 g', 'of which saturates 2.1 g', 'Carbohydrate 58 g', 'of which sugars 19 g', 'Fibre 7.5 g', 'Protein 9.2 g', 'Salt 0.4 g']],
};
const tr = k => TX[k][LANG === 'en' ? 1 : 0];
const br = s => esc(s).replace(/\n/g, '<br>');

// ---------------------------------------------------------------------------
// Produkte + Rechenlogik (Port von src/metrics.gd)
// ---------------------------------------------------------------------------
const FOODS = {
  muesli: { key: 'muesli', name: 'Knusper-Müsli Nuss', sub: 'DEMO', kcal: 402, p: 9.2, c: 58, f: 11, fib: 7.5 },
  banana: { key: 'banana', name: ['Banane', 'Banana'], sub: 'OBST', kcal: 89, p: 1.1, c: 22.8, f: 0.3, fib: 2.6 },
  skyr: { key: 'skyr', name: 'Skyr', sub: 'DEMO', kcal: 63, p: 11.0, c: 4.0, f: 0.2, fib: 0.0 },
  peanut: { key: 'peanut', name: ['Erdnüsse', 'Peanuts'], sub: 'DEMO', kcal: 567, p: 25.8, c: 16.1, f: 49.2, fib: 8.5 },
};
const fname = f => Array.isArray(f.name) ? f.name[LANG === 'en' ? 1 : 0] : f.name;

function evaluate(f) {
  const ep = f.p * 4, ec = f.c * 4, ef = f.f * 9, tot = ep + ec + ef;
  const split = { protein: ep / tot, carbs: ec / tot, fat: ef / tot };
  let ff = 41.7 / Math.pow(f.kcal, 0.7) + 0.05 * f.p + 6.17e-4 * Math.pow(f.fib, 3) - 7.25e-6 * Math.pow(f.f, 3) + 0.617;
  ff = clamp(ff, 0, 5);
  return { split, density: f.kcal, pd: f.p / (f.kcal / 100), sat: Math.round(ff / 5 * 100) };
}
function fmtNum(v, dec) {
  if (v < 0) return '–';
  if (dec === 0) return String(Math.round(v));
  let s = v.toFixed(dec);
  if (s.includes('.')) s = s.replace(/0+$/, '').replace(/\.$/, '');
  return s;
}
function scaleColor(t) {
  t = clamp(t);
  return t < 0.5 ? mixHex('#4CC38A', '#E8B931', t / 0.5) : mixHex('#E8B931', '#E5484D', (t - 0.5) / 0.5);
}
const densityT = k => clamp(k / 500), proteinT = pd => 1 - clamp(pd / 20), satietyT = s => 1 - clamp(s / 100);
function bestIdx(vals, lower) {
  let idx = -1, ref = lower ? Infinity : -Infinity;
  vals.forEach((v, i) => { if (lower ? v < ref : v > ref) { ref = v; idx = i; } });
  return idx;
}

// ---------------------------------------------------------------------------
// Anim.gd-Nachbau (pop_in, sweep, count_up, pulse)
// ---------------------------------------------------------------------------
const POP = 0.26, BUILD = 0.50, STAGGER = 0.045;
function popIn(t, start, from = 0.93, dur = POP) {
  const s = start + 0.016;
  if (t < s) return { o: 0, s: from };
  const k = clamp((t - s) / dur);
  return { o: E.quartOut(k), s: lerp(from, 1, E.backOut(k)) };
}
const sweep = (t, start, dur = BUILD) => t < start ? 0 : E.cubicIO(clamp((t - start) / dur));
/** pulse(): Skala 1.07 -> 1 (back out 0.38), Toenung (0.75,1,0.82) -> weiss (0.45). */
function pulseFx(t, at) {
  if (at == null || t < at + 0.016) return null;
  const s = at + 0.016;
  const ks = clamp((t - s) / 0.38), kc = E.cubicOut(clamp((t - s) / 0.45));
  return { s: lerp(1.07, 1, E.backOut(ks)), tint: [lerp(0.75, 1, kc), 1, lerp(0.82, 1, kc)] };
}

// ---------------------------------------------------------------------------
// Zeitplan
// ---------------------------------------------------------------------------
let VO = {}, WORDS = {};
const SCENES = [
  { id: 'problem', min: 7.4, lead: 0.5, tail: 0.5 },
  { id: 'scan', min: 7.0, lead: 0.5, tail: 0.5 },
  { id: 'charts', min: 6.6, lead: 0.2, tail: 0.6 },
  { id: 'pin', min: 4.2, lead: 0.3, tail: 0.5 },
  { id: 'compare', min: 9.6, lead: 0.2, tail: 0.6 },
  { id: 'remove', min: 2.8, lead: 0.2, tail: 0.6 },
  { id: 'grade', min: 7.2, lead: 0.5, tail: 0.6 },
  { id: 'end', min: 7.0, lead: 0.8, tail: 2.2 },
];
const S = {};       // id -> {t0, len, voAt}
let DURATION = 0;

function buildTimeline() {
  let t = 0;
  for (const sc of SCENES) {
    const vo = VO[sc.id] || 0;
    const len = Math.max(sc.min, sc.lead + vo + sc.tail);
    S[sc.id] = { t0: t, len, voAt: t + sc.lead, vo };
    t += len;
  }
  DURATION = Math.round(t * 30) / 30;
}
const norm = w => w.toLowerCase().replace(/[^a-z0-9äöüß]/g, '');
/** Absolute Zeit eines Worts in der Sprecherzeile (Anfang), sonst Rueckfall. */
function word(id, cands, fallbackRel, which = 'start') {
  const list = WORDS[id] || [];
  for (const w of list) {
    const n = norm(w[0]);
    if (cands.some(c => n.startsWith(norm(c)))) return S[id].voAt + (which === 'end' ? w[2] : w[1]);
  }
  return S[id].voAt + fallbackRel;
}
const L = (de, en) => LANG === 'en' ? en : de;

// ---------------------------------------------------------------------------
// App-Zustand (Ereignisse -> Zustand bei t)
// ---------------------------------------------------------------------------
let EV = [];        // App-Ereignisse
let CAM = [];       // Kamera: [{at, prod, seen, confirm}]
let TOUCH = [];     // Fingerspuren
let GEST = [];      // Wischgesten
const SWIPE_COMMIT = 170;

function buildEvents() {
  EV = []; CAM = []; TOUCH = []; GEST = [];
  const sc = S.scan.t0, ch = S.charts.t0, pi = S.pin.t0, co = S.compare.t0, re = S.remove.t0, gr = S.grade.t0;

  // --- Szene Scan: Muesli
  const build1 = Math.max(sc + 2.0, word('scan', L(['Grafiken'], ['charts']), 2.0) - 0.15);
  CAM.push({ at: sc - 0.2, prod: 'muesli', seen: build1 - 1.0, confirm: build1 - 0.45 });
  EV.push({ at: build1 - 0.4, type: 'loading' });
  EV.push({ at: build1, type: 'current', food: 'muesli' });

  // --- Szene Pin: Muesli nach unten wischen
  const rel1 = Math.max(pi + 1.4, word('pin', L(['gepinnt'], ['pinned']), 1.2) + 0.05);
  GEST.push({ key: 'muesli', down: rel1 - 1.15, rel: rel1, dy: 250, py: 1150 });
  EV.push({ at: rel1, type: 'pin' });
  CAM.push({ at: rel1 + 0.9, prod: null });

  // --- Szene Vergleich
  const tapU = co + 0.35;
  TOUCH.push({ down: tapU - 0.25, up: tapU, x: 540, y: 1844 });
  EV.push({ at: tapU, type: 'screen', name: 'generics' });
  const tapB = Math.max(tapU + 1.0, word('compare', L(['Unverpackt', 'Liste'], ['unpackaged', 'list']), 1.6) + 0.2);
  TOUCH.push({ down: tapB - 0.3, up: tapB, x: 330, y: 488 });
  EV.push({ at: tapB, type: 'screen', name: 'live' });
  EV.push({ at: tapB, type: 'addpinned', food: 'banana' });
  const sk = tapB + 0.75;
  CAM.push({ at: sk, prod: 'skyr', seen: sk + 0.45, confirm: sk + 0.85 });
  EV.push({ at: sk + 0.9, type: 'current', food: 'skyr' });
  const rel2 = sk + 2.15;
  GEST.push({ key: 'skyr', down: rel2 - 0.75, rel: rel2, dy: 230, py: 1150 });
  EV.push({ at: rel2, type: 'pin' });
  const pe = rel2 + 0.35;
  CAM.push({ at: pe, prod: 'peanut', seen: pe + 0.4, confirm: pe + 0.8 });
  EV.push({ at: pe + 0.85, type: 'current', food: 'peanut' });
  S.compare.sticker = Math.max(pe + 1.6, word('compare', L(['erklären'], ['explaining']), 8.5) - 0.2);

  // --- Szene Entfernen: Erdnuesse nach oben
  const rel3 = Math.max(re + 0.9, word('remove', L(['weg'], ['gone']), 0.9));
  GEST.push({ key: 'peanut', down: rel3 - 0.7, rel: rel3, dy: -240, py: 1250 });
  EV.push({ at: rel3 + 0.17, type: 'dismiss' });
  CAM.push({ at: rel3 + 0.2, prod: null });

  // --- Szene Note
  S.grade.circle = word('grade', L(['Note'], ['grade']), 1.0) + 0.1;
  S.grade.wipe = Math.max(S.grade.circle + 1.6, word('grade', L(['Macro', 'Makro'], ['Macro']), 3.0) - 0.2);
  S.end.mark = S.end.t0 + 0.2;
  EV.sort((a, b) => a.at - b.at);
}

/** Wiederholt die Ereignisse bis t und liefert den Zustand des Live-Screens. */
function appState(t) {
  const st = {
    screen: 'live', screenAt: -9, tray: [], current: null, status: 'empty',
    built: {}, pinnedAt: {}, pulse: {}, settle: {}, learnedPin: false, learnedUnpin: false, prevScreen: null, firstBuild: true,
  };
  for (const e of EV) {
    if (e.at > t) break;
    switch (e.type) {
      case 'loading': st.status = 'loading'; break;
      case 'current':
        st.current = e.food; st.status = '';
        if (!(e.food in st.built)) st.built[e.food] = e.at;
        break;
      case 'pin': {
        const k = st.current; if (!k) break;
        st.tray.push(k); st.current = null; st.learnedPin = true;
        st.pulse[k] = e.at; st.settle[k] = e.at;
        break;
      }
      case 'addpinned':
        st.tray.push(e.food); st.status = '';
        st.built[e.food] = e.at; st.pinnedAt[e.food] = e.at;
        break;
      case 'dismiss':
        st.current = null; st.learnedUnpin = true; break;
      case 'screen':
        st.prevScreen = st.screen; st.screen = e.name; st.screenAt = e.at; break;
    }
  }
  return st;
}
function columns(st) {
  const cols = st.tray.map(k => ({ key: k, pinned: true }));
  if (st.current && st.tray.length < 4 && !st.tray.includes(st.current)) cols.push({ key: st.current, pinned: false });
  return cols;
}

/** Wischgeste bei t: {key, dy, active, phase} */
function gestureAt(t) {
  for (const g of GEST) {
    if (t < g.down - 0.12 || t > g.rel + 0.6) continue;
    const moveStart = g.down + 0.1;
    const k = E.sineIO(clamp((t - moveStart) / (g.rel - moveStart - 0.05)));
    const dy = g.dy * k;
    return { g, dy, active: t >= moveStart && t < g.rel, pressed: t >= g.down && t < g.rel, released: t >= g.rel };
  }
  return null;
}

// ---------------------------------------------------------------------------
// Bausteine (HTML-Strings)
// ---------------------------------------------------------------------------
function chevron(size, down, color) {
  const w = size, h = size, y0 = h * 0.30, y1 = h * 0.72, sw = Math.max(2, w * 0.13);
  const pts = down ? `${w * .15},${y0} ${w * .5},${y1} ${w * .85},${y0}` : `${w * .15},${y1} ${w * .5},${y0} ${w * .85},${y1}`;
  return `<svg width="${w}" height="${h}" style="flex:none"><polyline points="${pts}" fill="none" stroke="${color}" stroke-width="${sw}" stroke-linejoin="round" stroke-linecap="round"/></svg>`;
}
function arc(cx, cy, r, a0, a1, col, wid) {
  if (a1 - a0 >= Math.PI * 2 - 1e-4) a1 = a0 + Math.PI * 2 - 1e-4;
  const x0 = cx + r * Math.cos(a0), y0 = cy + r * Math.sin(a0), x1 = cx + r * Math.cos(a1), y1 = cy + r * Math.sin(a1);
  const large = (a1 - a0) > Math.PI ? 1 : 0;
  return `<path d="M${x0.toFixed(2)} ${y0.toFixed(2)} A${r} ${r} 0 ${large} 1 ${x1.toFixed(2)} ${y1.toFixed(2)}" fill="none" stroke="${col}" stroke-width="${wid}"/>`;
}
/** MacroDonut._draw() */
function donut(h, split, prog, center) {
  const ring = h * 0.16, r = h / 2 - ring / 2 - 4, c = h / 2, gap = 0.10;
  let s = `<svg width="${h}" height="${h}" style="flex:none;overflow:visible">`;
  s += `<circle cx="${c}" cy="${c}" r="${r}" fill="none" stroke="${C.surface2}" stroke-width="${ring}"/>`;
  let ang = -Math.PI / 2;
  for (const [frac, col] of [[split.protein, C.protein], [split.carbs, C.carbs], [split.fat, C.fat]]) {
    if (frac <= 0.001) continue;
    const span = frac * Math.PI * 2 * prog;
    const a0 = ang + gap / 2, a1 = ang + span - gap / 2;
    if (a1 > a0) s += arc(c, c, r, a0, a1, col, ring);
    ang += span;
  }
  if (center) {
    const fsBig = Math.floor(h * 0.27), fsSm = Math.floor(h * 0.13);
    const txt = Math.round(split.protein * 100) + '%';
    const nm = tr('protein_short').toUpperCase().replace('SS', 'ß').replace('EIWEISS', 'EIWEIß');
    s += `<text x="${c}" y="${c + fsBig * 0.30}" text-anchor="middle" font-family="OS" font-weight="700" font-size="${fsBig}" fill="${C.text}" fill-opacity="${prog}">${txt}</text>`;
    s += `<text x="${c}" y="${c + fsBig * 0.30 + fsSm * 1.35}" text-anchor="middle" font-family="OS" font-weight="600" font-size="${fsSm}" fill="${C.muted}" fill-opacity="${prog}">${esc(nm)}</text>`;
  }
  return s + '</svg>';
}

/** Zelle einer Spalte: Inhalt mit pop_in, Slide-Versatz und Toenung. */
function cellWrap(inner, col, row, opts) {
  const { t, ci, anim, delay, off, alpha, filt, scaleExtra, dim, gridCol, gridRow, align } = opts;
  let o = 1, sc = 1;
  if (anim != null) { const p = popIn(t, anim + delay); o = p.o; sc = p.s; }
  sc *= scaleExtra;
  return `<div style="grid-column:${gridCol};grid-row:${gridRow};min-width:0;${align || ''};transform:translateY(${off.toFixed(2)}px);opacity:${(alpha * dim).toFixed(3)};${filt}">
    <div style="transform:scale(${sc.toFixed(4)});opacity:${o.toFixed(3)};transform-origin:50% 50%">${inner}</div></div>`;
}

// ---------------------------------------------------------------------------
// Live-Screen
// ---------------------------------------------------------------------------
/**
 * Baut die Matrix (live.gd _build_rows) fuer den Zustand bei t.
 * hl: Zeilen-Hervorhebung (Szene "charts"): {row: 1..4, k: 0..1} -> andere dimmen.
 */
function matrixHTML(t, st, cols, hl, gest) {
  const n = cols.length;
  const numSize = [96, 92, 78, 64][n - 1], donutH = [200, 142, 144, 128][n - 1];
  const nameSize = n <= 2 ? 30 : 26, legend = n <= 2, showBest = n >= 2;
  const evs = cols.map(c => evaluate(FOODS[c.key]));
  const bK = bestIdx(evs.map(e => e.density), true), bP = bestIdx(evs.map(e => e.pd), false), bS = bestIdx(evs.map(e => e.sat), false);

  // Neue Spalten (Aufbau) + Rang fuer den Versatz
  const anim = cols.map(c => {
    const at = st.built[c.key];
    return (at != null && t - at < 2.5) ? at : null;
  });
  const delayOf = (ci, row) => {
    let rank = 0;
    for (let j = 0; j < ci; j++) if (anim[j] != null && anim[j] === anim[ci]) rank++;
    return row * STAGGER + rank * STAGGER * 0.6;
  };

  // Wisch-/Einrast-Versatz je Spalte
  const offs = cols.map(() => 0), alphas = cols.map(() => 1), tints = cols.map(() => [1, 1, 1]), scales = cols.map(() => 1);
  let hint = null;
  cols.forEach((c, i) => {
    // Einrasten nach dem Pinnen (back out 0.42) + Puls
    const sAt = st.settle[c.key];
    if (sAt != null && t >= sAt && t < sAt + 0.6) {
      const g = GEST.find(x => x.key === c.key && Math.abs(x.rel - sAt) < 1e-6);
      const from = g ? pinOffset(g.dy) : 0;
      offs[i] = lerp(from, 0, E.backOut(clamp((t - sAt) / 0.42)));
    }
    const pf = pulseFx(t, st.pulse[c.key]);
    if (pf) { scales[i] = pf.s; tints[i] = pf.tint; }
  });
  if (gest) {
    const i = cols.findIndex(c => c.key === gest.g.key);
    if (i >= 0) {
      const col = cols[i], dy = gest.dy;
      if (!gest.released) {
        const mode = dy < 0 ? 'out' : (col.pinned ? '' : 'pin');
        let prog = 0;
        if (mode === 'pin') { prog = clamp(dy / SWIPE_COMMIT); offs[i] = pinOffset(dy); tints[i] = [lerp(1, 0.80, prog), 1, lerp(1, 0.86, prog)]; }
        else if (mode === 'out') { prog = clamp(-dy / SWIPE_COMMIT); offs[i] = dy; alphas[i] = 1 - 0.6 * prog; }
        if (mode && gest.active) {
          const armed = prog >= 1;
          const key = armed ? (mode === 'pin' ? C.good : C.bad) : C.muted;
          // Puls beim Scharfschalten
          let hs = 1;
          const armT = armTime(gest.g);
          if (armed && armT != null) hs = lerp(1.07, 1, E.backOut(clamp((t - armT - 0.016) / 0.38)));
          hint = { i, mode, alpha: clamp(prog * 1.6), color: key, s: hs };
        }
      } else if (gest.g.dy < 0) {
        // Wegfliegen: offset -> from-260 (0.17 cubic in), alpha -> 0 (0.15)
        const k = clamp((t - gest.g.rel) / 0.17);
        offs[i] = lerp(gest.g.dy, gest.g.dy - 260, E.cubicIn(k));
        alphas[i] = (1 - 0.6) * (1 - clamp((t - gest.g.rel) / 0.15));
      }
    }
  }

  const tmpl = `150px repeat(${n}, minmax(0,1fr))`;
  let h = `<div class="grid" style="grid-template-columns:${tmpl};position:relative;row-gap:${n === 2 ? 5 : 8}px">`;
  const dimOf = row => (hl ? lerp(1, row === hl.row ? 1 : 0.32, hl.k) : 1);
  const opts = (i, row, gridRow) => ({
    t, ci: i, anim: anim[i], delay: delayOf(i, row), off: offs[i], alpha: alphas[i],
    filt: tints[i][0] < 0.999 || tints[i][2] < 0.999 ? `filter:url(#tint${i})` : '', scaleExtra: scales[i], dim: dimOf(row),
    gridCol: i + 2, gridRow,
  });
  cols.forEach((c, i) => setTint(i, tints[i]));

  // Zeile 1: Namen
  h += `<div style="grid-column:1;grid-row:1"></div>`;
  cols.forEach((c, i) => {
    const f = FOODS[c.key];
    let lineW = 0;
    if (c.pinned) {
      const sAt = st.settle[c.key];
      const prog = (sAt != null && t < sAt + 0.6) ? E.cubicOut(clamp((t - sAt - 0.12) / 0.32)) : 1;
      lineW = 42 * prog;
    }
    const nm = fname(f).length > 20 ? fname(f).slice(0, 19).trim() + '…' : fname(f);
    let inner = `<div style="display:flex;flex-direction:column;gap:4px">
      <div style="height:5px"><div style="height:5px;width:${lineW}%;background:${C.accent}"></div></div>
      <div class="ell" style="font-size:${nameSize}px;font-weight:700;min-height:44px;line-height:44px">${esc(nm)}</div>
      <div style="display:flex;gap:8px;align-items:center;min-height:36px">
        <div class="micro ell" style="flex:1;min-width:0">${esc(f.sub)}</div>
        ${c.pinned ? '' : `<div style="display:flex;gap:6px;align-items:center;border:2px solid ${C.accent};border-radius:3px;padding:4px 12px 4px 10px;flex:none">${chevron(22, true, C.accent)}<span style="font-size:26px;font-weight:700;color:${C.accent}">PIN</span></div>`}
      </div></div>`;
    h += cellWrap(inner, c, 0, opts(i, 0, 1));
  });

  // Zeile 2: Donut
  h += `<div class="rowlbl" style="grid-column:1;grid-row:2;opacity:${dimOf(1)}">${tr('lbl_macros')}</div>`;
  cols.forEach((c, i) => {
    const ev = evs[i];
    const prog = anim[i] != null ? sweep(t, anim[i] + delayOf(i, 1) + 0.05) : 1;
    let inner = `<div style="display:flex;align-items:center;${legend ? 'justify-content:center;gap:18px' : ''}">${donut(donutH, ev.split, prog, !legend)}`;
    if (legend) {
      inner += `<div style="display:flex;flex-direction:column;gap:12px">`;
      for (const k of ['protein', 'carbs', 'fat']) {
        inner += `<div style="display:flex;gap:10px;align-items:center"><div style="width:20px;height:20px;background:${C[k]}"></div>
          <div style="min-width:92px;font-size:26px;font-weight:600;color:${C.muted}">${esc(tr(k + '_short'))}</div>
          <div style="font-size:36px;font-weight:700;min-width:84px;text-align:right">${Math.round(ev.split[k] * 100)} %</div></div>`;
      }
      inner += `</div>`;
    }
    inner += `</div>`;
    h += cellWrap(inner, c, 1, opts(i, 1, 2));
  });
  h += `<div class="hl" style="grid-row:3;opacity:${dimOf(-1)}"></div>`;

  // Zeilen 3-5: Balken
  const bars = [
    { row: 2, lbl: 'lbl_density', val: e => e.density, dec: 0, unit: 'kcal_100g', max: 500, col: e => scaleColor(densityT(e.density)), best: bK, gr: 4 },
    { row: 3, lbl: 'lbl_protein', val: e => e.pd, dec: 1, unit: 'unit_g_100kcal', max: 25, col: e => scaleColor(proteinT(e.pd)), best: bP, gr: 6 },
    { row: 4, lbl: 'lbl_satiety', val: e => e.sat, dec: 0, unit: 'of_100', max: 100, col: e => scaleColor(satietyT(e.sat)), best: bS, gr: 8 },
  ];
  bars.forEach((b, bi) => {
    h += `<div class="rowlbl" style="grid-column:1;grid-row:${b.gr};opacity:${dimOf(b.row)}">${tr(b.lbl)}</div>`;
    cols.forEach((c, i) => {
      const ev = evs[i], raw = b.val(ev), col = b.col(ev);
      let shown = raw, frac = clamp(raw / b.max), bestPop = null;
      if (anim[i] != null) {
        const d = anim[i] + delayOf(i, b.row) + 0.05;
        const k = sweep(t, d);
        shown = raw * k; frac *= k;
        bestPop = d + BUILD * 0.8;
      }
      const isBest = showBest && i === b.best;
      let chip = '';
      if (isBest) {
        let po = 1, ps = 1;
        if (bestPop != null) { const p = popIn(t, bestPop, 0.6); po = p.o; ps = p.s; }
        chip = `<div style="display:flex"><div class="chip" style="opacity:${po};transform:scale(${ps});transform-origin:50% 50%">${tr('best')}</div></div>`;
      }
      const inner = `<div style="display:flex;flex-direction:column;gap:6px">
        <div style="font-size:${numSize}px;font-weight:700;color:${col};line-height:1.362">${fmtNum(shown, b.dec)}</div>
        <div class="micro">${esc(tr(b.unit))}</div>
        <div class="track"><div class="fill" style="left:1px;top:1px;bottom:1px;width:calc(${(frac * 100).toFixed(3)}% - 2px);background:${col};display:${frac * 100 > 0.1 ? 'block' : 'none'}"></div></div>
        ${chip}</div>`;
      h += cellWrap(inner, c, b.row, Object.assign(opts(i, b.row, b.gr), { align: 'align-self:start' }));
    });
    if (bi < 2) h += `<div class="hl" style="grid-row:${b.gr + 1};opacity:${dimOf(-1)}"></div>`;
  });

  // Hinweis waehrend des Wischens (in der Luecke der Spalte)
  if (hint) {
    const txt = tr(hint.mode === 'pin' ? 'swipe_pin' : 'swipe_out');
    h += `<div style="grid-column:${hint.i + 2};grid-row:1 / 9;align-self:${hint.mode === 'pin' ? 'start' : 'end'};height:48px;margin:${hint.mode === 'pin' ? '-8px 0 0 0' : '0 0 8px 0'};
      display:flex;gap:8px;align-items:center;justify-content:center;opacity:${hint.alpha};transform:scale(${hint.s});z-index:3">
      ${chevron(28, hint.mode === 'pin', hint.color)}<span style="font-size:30px;font-weight:700;color:${hint.color}">${txt}</span></div>`;
  }

  // Gesten-Hinweiszeile (bis die Gesten gelernt sind)
  const parts = [];
  const hasNew = cols.some(c => !c.pinned);
  if (hasNew && !st.learnedPin) parts.push([true, tr('hint_pin')]);
  if (!st.learnedUnpin && (st.learnedPin || !hasNew)) parts.push([false, tr('hint_out')]);
  if (parts.length) {
    h += `<div style="grid-column:1 / -1;grid-row:9;display:flex;justify-content:center;gap:26px;margin-top:14px;opacity:${dimOf(-1)}">` +
      parts.map(p => `<div style="display:flex;gap:8px;align-items:center">${chevron(20, p[0], C.faint)}<span style="font-size:26px;font-weight:600;color:${C.faint}">${esc(p[1])}</span></div>`).join('') + `</div>`;
  }
  return h + '</div>';
}
const pinOffset = dy => dy < SWIPE_COMMIT ? dy : SWIPE_COMMIT + (dy - SWIPE_COMMIT) * 0.25;
function armTime(g) {
  // Zeitpunkt, an dem |dy| die Schwelle ueberschreitet (fuer Puls + Haptik)
  const moveStart = g.down + 0.1, dur = g.rel - moveStart - 0.05;
  const target = SWIPE_COMMIT / Math.abs(g.dy);
  if (target > 1) return null;
  // sineIO invertieren
  const k = Math.acos(1 - 2 * target) / Math.PI;
  return moveStart + k * dur;
}
function setTint(i, rgb) {
  const el = document.getElementById('tm' + i);
  if (el) el.setAttribute('values', `${rgb[0]} 0 0 0 0 0 ${rgb[1]} 0 0 0 0 0 ${rgb[2]} 0 0 0 0 0 1 0`);
}

function emptyCard(title, body) {
  return `<div style="background:${C.surface};border:1px solid ${C.line};border-radius:4px;padding:38px;display:flex;flex-direction:column;gap:16px">
    <div style="font-size:52px;font-weight:600">${esc(title)}</div>
    ${body ? `<div style="font-size:30px;color:${C.muted}">${esc(body)}</div>` : ''}</div>`;
}

function liveScreen(t, st, hl) {
  const cols = columns(st);
  const gest = gestureAt(t);
  let mid;
  if (cols.length === 0) {
    const p = popIn(t, st.status === 'loading' ? EV.find(e => e.type === 'loading').at : -9, 0.97);
    mid = `<div style="opacity:${p.o};transform:scale(${p.s})">${st.status === 'loading' ? emptyCard(tr('loading'), '') : emptyCard(tr('scan_hint'), tr('attribution'))}</div>`;
  } else {
    mid = matrixHTML(t, st, cols, hl, gest);
  }
  const mini = s => `<div class="btn" style="height:76px;font-size:26px">${s}</div>`;
  return `
  <div class="abs" style="left:0;top:0;width:1080px;height:576px;background:${C.surface2};overflow:hidden">${cameraSVG(t)}</div>
  <div class="abs" style="left:0;top:576px;width:1080px;height:1344px;display:flex;flex-direction:column">
    <div style="height:3px;background:${C.accent};flex:none"></div>
    <div style="padding:8px 44px 6px;display:flex;gap:10px;align-items:center;flex:none">
      <div style="font-size:32px;font-weight:700;white-space:nowrap">MACRO<span style="color:${C.accent}"> LENS</span></div>
      <div style="flex:1"></div>${mini(tr('search'))}${mini(tr('history'))}${mini(tr('settings'))}
    </div>
    <div style="flex:1;overflow:hidden;display:flex;flex-direction:column;justify-content:center;padding:4px 44px">${mid}</div>
    <div style="height:1px;background:${C.line};flex:none"></div>
    <div style="padding:12px 44px 22px;flex:none"><div class="btn" style="height:108px;font-size:30px">+&nbsp;&nbsp;${tr('unpackaged')}</div></div>
  </div>`;
}

function genericsScreen(t) {
  const rows = [['Banane', 'Banana', 89], ['Apfel', 'Apple', 52], ['Birne', 'Pear', 57], ['Orange', 'Orange', 47], ['Erdbeere', 'Strawberry', 32],
    ['Weintrauben', 'Grapes', 69], ['Heidelbeere', 'Blueberry', 57]];
  const rows2 = [['Tomate', 'Tomato', 18], ['Gurke', 'Cucumber', 15], ['Karotte', 'Carrot', 41], ['Paprika rot', 'Red pepper', 31], ['Brokkoli', 'Broccoli', 34], ['Blumenkohl', 'Cauliflower', 25], ['Zucchini', 'Zucchini', 17]];
  const r = (x, i) => {
    // Tipp-Feedback auf der Bananen-Zeile
    const tb = TOUCH[1];
    const pressed = i === 0 && tb && t >= tb.down && t < tb.up + 0.05;
    return `<div style="display:flex;gap:10px;height:82px">
      <div style="flex:1;background:${pressed ? C.surface2 : C.surface};border:1px solid ${C.line};border-radius:4px;display:flex;align-items:center;padding:0 26px">
        <div style="flex:1;font-size:30px;font-weight:600">${esc(L(x[0], x[1]))}</div><div style="font-size:36px">${x[2]} kcal</div></div>
      <div class="btn" style="width:88px;font-size:40px;font-weight:600">+</div></div>`;
  };
  return `<div class="abs" style="inset:0;padding:46px 44px 0;display:flex;flex-direction:column;gap:0">
    <div style="display:flex;align-items:center;gap:26px;height:100px">
      <div class="btn" style="width:100px;height:100px;padding:0">${chevronLeft()}</div>
      <div style="font-size:40px;font-weight:600">${tr('unpackaged')}</div></div>
    <div style="height:1px;background:${C.line};margin:10px 0 26px"></div>
    <div style="height:92px;border:1px solid ${C.line};border-radius:4px;background:${C.surface};display:flex;align-items:center;padding:0 24px;font-size:36px;color:${C.faint}">${esc(tr('unpackaged_hint'))}</div>
    <div class="btn" style="height:74px;font-size:26px;margin-top:26px">${tr('barcode')}&nbsp;&nbsp;…</div>
    <div class="micro" style="margin:26px 0 10px">${L('OBST', 'OBST')}</div>
    <div style="display:flex;flex-direction:column;gap:10px">${rows.map(r).join('')}</div>
    <div class="micro" style="margin:26px 0 10px">${L('GEMÜSE', 'GEMÜSE')}</div>
    <div style="display:flex;flex-direction:column;gap:10px">${rows2.map((x, i) => r(x, i + 10)).join('')}</div>
  </div>`;
}
const chevronLeft = () => `<svg width="34" height="34"><polyline points="22,6 10,17 22,28" fill="none" stroke="${C.text}" stroke-width="5" stroke-linejoin="round" stroke-linecap="round"/></svg>`;

// ---------------------------------------------------------------------------
// Kamera (graustufige Vorschau + Tracking-Viereck aus BarcodeOverlay.kt)
// ---------------------------------------------------------------------------
const BAR = (() => { // deterministisches Strichmuster
  const r = mulberry32(42), out = []; let x = 0;
  while (x < 100) { const w = 1 + Math.floor(r() * 3), g = 1 + Math.floor(r() * 2.4); out.push([x, w]); x += w + g; }
  return out;
})();
function barcode(x, y, w, h) {
  let s = `<rect x="${x - 6}" y="${y - 6}" width="${w + 12}" height="${h + 22}" fill="#f4f4f0" rx="2"/>`;
  for (const [bx, bw] of BAR) if (bx + bw <= 100) s += `<rect x="${x + bx / 100 * w}" y="${y}" width="${bw / 100 * w}" height="${h}" fill="#111"/>`;
  s += `<text x="${x + w / 2}" y="${y + h + 13}" font-family="OS" font-size="12" text-anchor="middle" fill="#111">4 012345 678901</text>`;
  return s;
}
/** Produktgrafiken (in Farbe gezeichnet, Vorschau macht sie grau). bc = Barcode-Rechteck lokal. */
const PRODUCTS = {
  muesli: {
    bc: [40, 120, 110, 56],
    svg: () => `<rect x="-130" y="-190" width="260" height="380" rx="6" fill="#d39433"/>
      <rect x="-130" y="-190" width="260" height="90" fill="#7a3d1c"/>
      <text x="0" y="-150" font-family="OS" font-weight="700" font-size="40" text-anchor="middle" fill="#fff">KNUSPER</text>
      <text x="0" y="-110" font-family="OS" font-weight="700" font-size="30" text-anchor="middle" fill="#ffd27a">MÜSLI · NUSS</text>
      <ellipse cx="-20" cy="10" rx="80" ry="55" fill="#f3e2c0"/><ellipse cx="-40" cy="0" rx="22" ry="14" fill="#9a5a2a"/><ellipse cx="5" cy="20" rx="20" ry="13" fill="#b06b30"/><ellipse cx="-10" cy="-15" rx="16" ry="11" fill="#8a4a20"/>
      ${starburst(78, -40, 58, 12, '#3fae5a')}<text x="78" y="-33" font-family="OS" font-weight="700" font-size="${21 * (LANG === 'en' ? 0.85 : 1)}" text-anchor="middle" fill="#fff" transform="rotate(-12 78 -40)">${tr('gesund')}</text>
      ${barcode(40, 120, 110, 56)}`,
  },
  skyr: {
    bc: [-55, 40, 110, 50],
    svg: () => `<path d="M-120 -150 L120 -150 L95 170 L-95 170 Z" fill="#f2f4f7"/>
      <rect x="-130" y="-175" width="260" height="34" rx="6" fill="#3a6fb5"/>
      <text x="0" y="-60" font-family="OS" font-weight="700" font-size="70" text-anchor="middle" fill="#3a6fb5">SKYR</text>
      <text x="0" y="-20" font-family="OS" font-weight="600" font-size="24" text-anchor="middle" fill="#6b7b90">NATUR</text>
      ${barcode(-55, 40, 110, 50)}`,
  },
  peanut: {
    bc: [-70, 70, 120, 52],
    svg: () => `<path d="M-125 -170 Q0 -195 125 -170 L135 180 Q0 200 -135 180 Z" fill="#b9431f"/>
      <rect x="-125" y="-178" width="250" height="22" fill="#7d2a12"/>
      <text x="0" y="-95" font-family="OS" font-weight="700" font-size="44" text-anchor="middle" fill="#ffe2a6">${L('ERDNÜSSE', 'PEANUTS')}</text>
      <g transform="translate(0,-20) rotate(-20)"><ellipse cx="-18" cy="0" rx="30" ry="22" fill="#e2b46a"/><ellipse cx="22" cy="0" rx="28" ry="20" fill="#e2b46a"/></g>
      ${barcode(-70, 70, 120, 52)}`,
  },
};
function starburst(cx, cy, r, n, col) {
  let d = '';
  for (let i = 0; i < n * 2; i++) {
    const a = i / (n * 2) * Math.PI * 2, rr = i % 2 ? r * 0.82 : r;
    d += (i ? 'L' : 'M') + (cx + rr * Math.cos(a)).toFixed(1) + ' ' + (cy + rr * Math.sin(a)).toFixed(1);
  }
  return `<path d="${d}Z" fill="${col}"/>`;
}
function camShelf(t) {
  // Unscharfer Regal-Hintergrund (Kamera fokussiert auf das Produkt)
  const r = mulberry32(7);
  let s = `<rect width="1080" height="576" fill="#7d7d7d"/>`;
  for (let row = 0; row < 3; row++) {
    for (let i = 0; i < 9; i++) {
      const x = i * 130 - 40 + r() * 30, hh = 140 + r() * 80, y = 30 + row * 200 + (180 - hh);
      const v = 70 + Math.floor(r() * 120);
      s += `<rect x="${x}" y="${y}" width="${100 + r() * 30}" height="${hh}" fill="rgb(${v},${v},${v})"/>`;
    }
    s += `<rect x="0" y="${210 + row * 200}" width="1080" height="18" fill="#3c3c3c"/>`;
  }
  return `<g filter="url(#soft)" transform="translate(${(-18 * Math.sin(t * 0.7)).toFixed(1)},0)">${s}</g>`;
}
/** Kamera-Bild bei t: aktuelles Produkt mit Handwackeln, Ein-/Ausfahren. */
function cameraSVG(t) {
  let s = `<svg width="1080" height="576" viewBox="0 0 1080 576"><g style="filter:grayscale(1) contrast(1.08) brightness(0.92)">${camShelf(t)}`;
  let quad = '';
  for (let i = 0; i < CAM.length; i++) {
    const c = CAM[i], next = CAM[i + 1];
    if (!c.prod || t < c.at - 0.6) continue;
    if (next && t > next.at + 0.6) continue;
    const kin = E.cubicOut(clamp((t - c.at) / 0.55));
    const kout = next ? E.cubicIn(clamp((t - next.at) / 0.45)) : 0;
    const x = 540 + lerp(700, 0, kin) - 760 * kout + 9 * Math.sin(t * 1.3) + 4 * Math.sin(t * 3.1 + 1);
    const y = 318 + 6 * Math.sin(t * 1.7 + 1) + 3 * Math.sin(t * 4.3);
    const rot = 1.4 * Math.sin(t * 0.9) + lerp(8, 0, kin);
    const sc = 0.92;
    const P0 = PRODUCTS[c.prod];
    s += `<g transform="translate(${x.toFixed(2)},${y.toFixed(2)}) rotate(${rot.toFixed(3)}) scale(${sc})">${P0.svg()}</g>`;
    if (c.seen != null && t >= c.seen && !(next && t > next.at)) quad = trackQuad(t, c, x, y, rot, sc, P0.bc);
  }
  s += `</g>${quad}</svg>`;
  return s;
}
function trackQuad(t, c, x, y, rot, sc, bc) {
  const [bx, by, bw, bh] = [bc[0] - 6, bc[1] - 6, bc[2] + 12, bc[3] + 22];
  const cx0 = bx + bw / 2, cy0 = by + bh / 2;
  const a = rot * Math.PI / 180, ca = Math.cos(a), sa = Math.sin(a);
  const vis = 1 - Math.exp(-18 * (t - c.seen));
  const mix = t >= c.confirm ? 1 - Math.exp(-14 * (t - c.confirm)) : 0;
  const pulse = t >= c.confirm ? Math.exp(-7 * (t - c.confirm)) : 0;
  const ps = 1 + 0.10 * pulse;
  const pts = [[bx, by], [bx + bw, by], [bx + bw, by + bh], [bx, by + bh]].map(([px, py]) => {
    const lx = cx0 + (px - cx0) * 1.14 * ps, ly = cy0 + (py - cy0) * 1.14 * ps;
    return [x + (lx * ca - ly * sa) * sc, y + (lx * sa + ly * ca) * sc];
  });
  const col = mixHex('#F0A020', '#4CC38A', mix);
  const d = pts.map(p => p.map(v => v.toFixed(1)).join(',')).join(' ');
  return `<polygon points="${d}" fill="${col}" fill-opacity="${(vis * 64 / 255).toFixed(3)}" stroke="${col}" stroke-opacity="${(vis * 245 / 255).toFixed(3)}" stroke-width="10" stroke-linejoin="round"/>`;
}

// ---------------------------------------------------------------------------
// Szene 1: Regal
// ---------------------------------------------------------------------------
let SHELF = null;
function buildShelf() {
  const r = mulberry32(2026);
  const boxes = [];
  const palette = ['#3b4a5c', '#5c4436', '#4a5a3c', '#5a3b4e', '#6b5a2e', '#2f4f55', '#58403a', '#44445c'];
  const shelfY = [860, 1200, 1540, 1880];
  shelfY.forEach((sy, row) => {
    let x = -30 + r() * 40;
    while (x < 1100) {
      const w = 120 + r() * 60, h = 220 + r() * 90;
      boxes.push({ x, y: sy - h, w, h, col: palette[Math.floor(r() * palette.length)], row, st: r(), rot: -14 + r() * 28 });
      x += w + 8 + r() * 10;
    }
  });
  // Ziel-Box (das Muesli): Reihe 1, mittig
  const target = boxes.filter(b => b.row === 1).sort((a, b) => Math.abs(a.x + a.w / 2 - 560) - Math.abs(b.x + b.w / 2 - 560))[0];
  target.col = '#8a5a22'; target.target = true;
  // Reihenfolge der GESUND-Sticker: zufaellig, aber fest
  const order = boxes.map((b, i) => [r(), i]).sort((a, b) => a[0] - b[0]).map(x => x[1]);
  order.forEach((bi, k) => { boxes[bi].k = k; });
  SHELF = { boxes, shelfY, target };
}
function sceneProblem(t) {
  const sc = S.problem, rt = t - sc.t0;
  if (rt < -0.1 || rt > sc.len + 0.6) return '';
  const { boxes, shelfY, target } = SHELF;
  const tS = word('problem', L(['Müslis', '200'], ['cereals']), 1.4) - sc.t0;
  const tG = word('problem', L(['gesund'], ['healthy']), 3.6) - sc.t0;
  const tZ = word('problem', L(['Nährwert'], ['nutrition']), 4.4) - sc.t0 - 0.3;
  const tA = word('problem', L(['Ameise'], ['ant']), 6.0) - sc.t0;
  // Zoom auf die Naehrwerttabelle der Ziel-Box
  const lx = target.x + target.w * 0.5, ly = target.y + target.h * 0.62;
  const z = lerp(1, 14, E.cubicIO(clamp((rt - tZ) / 1.3)));
  const drift = 1 + 0.03 * clamp(rt / 5);
  const fx = lerp(540, lx, E.cubicIO(clamp((rt - tZ) / 1.3))), fy = lerp(1100, ly, E.cubicIO(clamp((rt - tZ) / 1.3)));
  const tf = `translate(540,1150) scale(${(z * drift).toFixed(4)}) translate(${-fx},${-fy})`;
  let s = `<svg class="abs" style="left:0;top:0" width="1080" height="1920"><g transform="${tf}">`;
  shelfY.forEach(sy => { s += `<rect x="-200" y="${sy}" width="1480" height="26" fill="${C.surface2}"/><rect x="-200" y="${sy + 26}" width="1480" height="2" fill="${C.line}"/>`; });
  const nSt = boxes.length;
  for (const b of boxes) {
    s += `<rect x="${b.x}" y="${b.y}" width="${b.w}" height="${b.h}" rx="3" fill="${b.col}"/>`;
    s += `<rect x="${b.x}" y="${b.y}" width="${b.w}" height="${b.h * 0.22}" fill="rgba(0,0,0,0.22)"/>`;
    s += `<rect x="${b.x + 14}" y="${b.y + b.h * 0.07}" width="${b.w * 0.6}" height="9" fill="rgba(255,255,255,0.55)"/>`;
    s += `<rect x="${b.x + 14}" y="${b.y + b.h * 0.13}" width="${b.w * 0.35}" height="6" fill="rgba(255,255,255,0.35)"/>`;
    // Mini-Naehrwerttabelle
    const tx = b.x + b.w * 0.5 - 16, ty = b.y + b.h * 0.62 - 9;
    if (b.target) {
      s += `<rect x="${tx}" y="${ty}" width="32" height="20" fill="#f4f1e8"/>`;
      tr('table').forEach((ln, i) => {
        s += `<text x="${tx + 1.2}" y="${ty + 2.4 + i * 2}" font-family="OS" font-size="1.55" font-weight="${i === 0 ? 700 : 400}" fill="#222">${esc(ln)}</text>`;
        if (i) s += `<rect x="${tx + 1}" y="${ty + 2.85 + i * 2 - 2}" width="30" height="0.08" fill="#999"/>`;
      });
    } else {
      s += `<rect x="${tx}" y="${ty}" width="32" height="20" fill="rgba(240,236,225,0.75)"/>`;
    }
  }
  // GESUND-Sticker: beschleunigt, ab "Muesli" bis kurz nach "gesund"
  for (const b of boxes) {
    if (b.target) continue;
    const k = b.k / nSt;
    const at = tS + (tG + 0.3 - tS) * Math.pow(k, 0.62);
    const p = popIn(rt, at, 0.2, 0.22);
    if (p.o <= 0) continue;
    const cx = b.x + b.w * (0.3 + 0.4 * b.st), cy = b.y + b.h * 0.36;
    s += `<g transform="translate(${cx},${cy}) rotate(${b.rot}) scale(${p.s * 1.45})" opacity="${p.o}">${starburst(0, 0, 36, 12, '#3fae5a')}
      <text x="0" y="5" font-family="OS" font-weight="700" font-size="${14 * (LANG === 'en' ? 0.85 : 1)}" text-anchor="middle" fill="#fff">${tr('gesund')}</text></g>`;
  }
  // Ameise auf dem Etikett (laeuft von rechts herein)
  const ak = E.cubicOut(clamp((rt - (tA - 1.2)) / 1.2));
  const ax = lerp(target.x + target.w + 30, lx + 9, ak), ay = ly + 4.2;
  s += ant(ax, ay, 0.9, rt, ak < 1 ? 1 : 0);
  s += `</g></svg>`;
  const fade = 1 - clamp((rt - (sc.len - 0.35)) / 0.45);
  return `<div class="abs" style="inset:0;opacity:${fade}">${s}<div class="abs" style="left:0;top:0;width:1080px;height:640px;background:linear-gradient(#0F1113 62%,rgba(15,17,19,0))"></div></div>`;
}
/** Ameise (Seitenansicht, laeuft nach links). s = Groesse, walking = Beinbewegung. */
function ant(x, y, s, t, walking) {
  const ph = walking ? Math.sin(t * 28) : 0;
  let legs = '';
  for (let i = 0; i < 3; i++) {
    const lx = -1.2 + i * 1.2, sw = (i % 2 ? ph : -ph) * 0.5;
    legs += `<line x1="${lx}" y1="0.2" x2="${lx - 0.8 + sw}" y2="1.6" stroke="#111" stroke-width="0.22" stroke-linecap="round"/>`;
    legs += `<line x1="${lx}" y1="0.2" x2="${lx + 0.8 - sw}" y2="1.6" stroke="#111" stroke-width="0.22" stroke-linecap="round"/>`;
  }
  return `<g transform="translate(${x.toFixed(2)},${y.toFixed(2)}) scale(${s})">${legs}
    <ellipse cx="-2.3" cy="-0.3" rx="0.9" ry="0.75" fill="#111"/><ellipse cx="0" cy="-0.2" rx="0.9" ry="0.55" fill="#111"/><ellipse cx="2.3" cy="-0.4" rx="1.4" ry="1" fill="#111"/>
    <line x1="-2.9" y1="-0.8" x2="-3.9" y2="-2" stroke="#111" stroke-width="0.18"/><line x1="-2.6" y1="-0.9" x2="-3.2" y2="-2.2" stroke="#111" stroke-width="0.18"/></g>`;
}

// ---------------------------------------------------------------------------
// Szene 7: Note  ·  Szene 8: Abschluss
// ---------------------------------------------------------------------------
function sceneGrade(t) {
  const sc = S.grade, rt = t - sc.t0;
  if (rt < 0 || rt > sc.len + 0.2) return '';
  const tin = popIn(rt, 0.35, 0.9, 0.4);
  const tc = sc.circle - sc.t0, tw = sc.wipe - sc.t0;
  const wipeK = E.cubicIO(clamp((rt - tw) / 0.5));
  const out = clamp((rt - tw - 0.25) / 0.35);
  let h = '';
  // Generische Noten-Karte (bewusst ohne Namen/Marke)
  if (out < 1) {
    const circ = clamp((rt - tc) / 0.7);
    const minus = popIn(rt, tc + 0.75, 0.4, 0.25);
    const fall = E.cubicIn(out);
    h += `<div class="abs" style="left:190px;top:${640 + fall * 300}px;width:700px;height:760px;transform:rotate(${-3 + fall * 14}deg) scale(${tin.s});opacity:${tin.o * (1 - out)};
      background:#ECE8DF;border-radius:6px;color:#222;box-shadow:0 30px 80px rgba(0,0,0,.5)">
      <div style="position:absolute;left:56px;top:46px;font-size:30px;font-weight:600;letter-spacing:4px;color:#6a6660">${tr('grade_title')}</div>
      <div style="position:absolute;left:56px;top:92px;font-size:34px;font-weight:600;color:#3a3732">${tr('grade_sub')}</div>
      <div style="position:absolute;left:0;right:0;top:170px;text-align:center;font-size:400px;font-weight:700;line-height:1;color:#c99a1e">C<span style="font-size:240px;color:#c8342c;display:inline-block;opacity:${minus.o};transform:scale(${minus.s})">–</span></div>
      <svg style="position:absolute;left:0;top:0" width="700" height="760"><path d="M210 360 C 200 200, 520 160, 520 360 C 520 560, 190 590, 180 380 C 175 300, 240 230, 330 215"
        fill="none" stroke="#c8342c" stroke-width="12" stroke-linecap="round" stroke-dasharray="1500" stroke-dashoffset="${1500 * (1 - E.cubicOut(circ))}"/></svg>
      <div style="position:absolute;left:56px;right:56px;bottom:56px;display:flex;justify-content:space-between">${['A', 'B', 'C', 'D', 'E'].map(l => `<div style="font-size:44px;font-weight:700;color:${l === 'C' ? '#3a3732' : '#b5b0a6'}">${l}</div>`).join('')}</div>
    </div>`;
  }
  // Wisch-Linie
  if (rt > tw - 0.05 && rt < tw + 0.8) {
    const k = E.cubicIO(clamp((rt - tw) / 0.45)), k2 = E.cubicIO(clamp((rt - tw - 0.2) / 0.45));
    h += `<div class="abs" style="top:1010px;left:${-40 + k2 * 1160}px;width:${(k - k2) * 1160}px;height:8px;background:${C.accent}"></div>`;
  }
  // Rechts: die rohen Zahlen – die echte Matrix (eine Spalte)
  if (rt > tw) {
    const st = { tray: [], current: 'muesli', built: { muesli: sc.wipe + 0.15 }, settle: {}, pulse: {}, learnedPin: true, learnedUnpin: true };
    const m = matrixHTML(t, st, [{ key: 'muesli', pinned: true }], null, null);
    const o = clamp((rt - tw) / 0.2);
    h += `<div class="abs" style="left:0;top:620px;width:1080px;padding:0 60px;opacity:${o}">
      <div style="background:${C.bg};border:1px solid ${C.line};border-radius:4px;padding:30px 30px 34px">${m}</div></div>`;
  }
  return h;
}
function sceneEnd(t) {
  const sc = S.end, rt = t - sc.t0;
  if (rt < 0) return '';
  const p = popIn(rt, 0.2, 0.94, 0.5);
  const line = (k, txt, size, col, w) => {
    const q = popIn(rt, 0.75 + k * 0.15, 0.96, 0.4);
    return `<div style="opacity:${q.o};transform:translateY(${(1 - q.o) * 12}px);font-size:${size}px;font-weight:${w};color:${col};text-align:center">${esc(txt)}</div>`;
  };
  // Ameise traegt den GESUND-Sticker davon
  const ak = clamp((rt - 1.6) / 5.2);
  const ax = lerp(1340, -400, ak);
  const ant2 = `<svg class="abs" style="left:0;top:1260px;overflow:visible" width="1080" height="440"><g transform="translate(${ax},360)">
      <line x1="-8" y1="-30" x2="-30" y2="-150" stroke="#8B9199" stroke-width="5" stroke-linecap="round"/>
      <g transform="translate(-34,-150) rotate(${-8 + 4 * Math.sin(rt * 9)})">${starburst(0, 0, 110, 14, '#3fae5a')}<text x="0" y="14" font-family="OS" font-weight="700" font-size="${40 * (LANG === 'en' ? 0.85 : 1)}" text-anchor="middle" fill="#fff">${tr('gesund')}</text></g>
      ${ant(0, 0, 15, rt, 1).replace(/#111/g, '#8B9199')}</g></svg>`;
  return `<div class="abs" style="inset:0">
    <div class="abs" style="left:0;right:0;top:700px;text-align:center;opacity:${p.o};transform:scale(${p.s})">
      <div style="font-size:124px;font-weight:700;letter-spacing:1px">MACRO<span style="color:${C.accent}"> LENS</span></div></div>
    <div class="abs" style="left:0;right:0;top:900px;height:3px;display:flex;justify-content:center"><div style="height:3px;width:${360 * E.cubicOut(clamp((rt - 0.5) / 0.5))}px;background:${C.accent}"></div></div>
    <div class="abs" style="left:60px;right:60px;top:960px;display:flex;flex-direction:column;gap:22px">
      ${line(0, tr('end_1'), 40, C.text, 600)}${line(1, tr('end_2'), 40, C.muted, 400)}</div>
    <div class="abs" style="left:60px;right:60px;top:1250px;display:flex;flex-direction:column;gap:10px">
      ${line(3, tr('end_3'), 30, C.faint, 600)}${line(4, tr('attribution'), 22, C.faint, 400)}</div>
    ${ant2}</div>`;
}

// ---------------------------------------------------------------------------
// Bildunterschriften
// ---------------------------------------------------------------------------
function captions(t) {
  const items = [];
  const add = (key, m, a, b) => items.push({ key, m, a, b });
  add('cap_problem', 'm_problem', S.problem.t0 + 0.5, S.problem.t0 + S.problem.len - 0.2);
  add('cap_scan', 'm_scan', S.scan.t0 + 0.4, S.charts.t0);
  const q = [word('charts', L(['Woraus'], ['Where']), 0), word('charts', L(['Energie'], ['energy']), 1.7) - 0.25,
    word('charts', L(['Eiweiß'], ['protein']), 3.6) - 0.25, word('charts', L(['satt'], ['filling']), 5.6) - 0.45];
  S.charts.q = q;
  add('cap_q1', 'm_charts', S.charts.t0 + 0.15, q[1]);
  add('cap_q2', 'm_charts', q[1], q[2]);
  add('cap_q3', 'm_charts', q[2], q[3]);
  add('cap_q4', 'm_charts', q[3], S.pin.t0);
  add('cap_pin', 'm_pin', S.pin.t0, S.compare.t0);
  add('cap_compare', 'm_compare', S.compare.t0, S.remove.t0);
  add('cap_remove', 'm_pin', S.remove.t0, S.grade.t0);
  add('cap_grade', 'm_grade', S.grade.t0 + 0.3, S.grade.wipe);
  add('cap_numbers', 'm_grade', S.grade.wipe, S.end.t0);
  let h = '';
  for (const it of items) {
    if (t < it.a - 0.01 || t > it.b + 0.3) continue;
    const kin = E.cubicOut(clamp((t - it.a) / 0.35)), kout = clamp((t - it.b) / 0.22);
    const o = kin * (1 - kout);
    if (o <= 0.001) continue;
    // Micro-Label bleibt stehen, wenn das naechste dasselbe hat
    h += `<div class="cap" style="top:200px;opacity:${o};transform:translateY(${(1 - kin) * 14}px)">${br(tr(it.key))}</div>`;
  }
  // Micro-Label getrennt (ohne Flackern bei gleichem Label)
  let m = null, ma = 0, mb = 0;
  const groups = [];
  for (const it of items) {
    const g = groups[groups.length - 1];
    if (g && g.m === it.m && Math.abs(g.b - it.a) < 0.05) g.b = it.b; else groups.push({ m: it.m, a: it.a, b: it.b });
  }
  for (const g of groups) {
    if (t < g.a || t > g.b + 0.3) continue;
    const o = E.cubicOut(clamp((t - g.a) / 0.35)) * (1 - clamp((t - g.b) / 0.22));
    h += `<div class="abs capmicro" style="left:96px;top:136px;opacity:${o};display:flex;align-items:center;gap:18px">
      <div style="width:${46 * E.cubicOut(clamp((t - g.a) / 0.4))}px;height:3px;background:${C.accent}"></div>${esc(tr(g.m))}</div>`;
  }
  return h;
}

// ---------------------------------------------------------------------------
// Handy + Gesamtkomposition
// ---------------------------------------------------------------------------
const PHONE_S = 0.655;          // Bildschirm 1080x1920 -> 707x1258
const PH_W = W * PHONE_S, PH_H = H * PHONE_S, BEZEL = 16;
function phoneLayer(t) {
  const sIn = S.scan.t0, gOut = S.grade.t0;
  if (t < sIn - 0.3 || t > gOut + 0.8) return '';
  const kin = E.cubicOut(clamp((t - sIn + 0.1) / 0.75));
  const kout = E.cubicIn(clamp((t - gOut) / 0.55));
  const st = appState(t);
  // Zeilen-Hervorhebung in Szene 2b
  let hl = null;
  const ch = S.charts;
  if (t >= ch.t0 && t < ch.t0 + ch.len + 0.3 && ch.q) {
    const q = ch.q;
    const row = t < q[1] ? 1 : t < q[2] ? 2 : t < q[3] ? 3 : 4;
    const k = clamp((t - ch.t0) / 0.3) * (1 - clamp((t - (ch.t0 + ch.len - 0.35)) / 0.3));
    hl = { row, k };
  }
  // Bildschirm (live/generics, mit Ueberblendung)
  let screen;
  const live = liveScreen(t, st, hl);
  if (st.screen === 'generics' || (st.prevScreen === 'generics' && t - st.screenAt < 0.2)) {
    const g = genericsScreen(t);
    const fadeIn = clamp((t - st.screenAt) / 0.2);
    if (st.screen === 'generics') screen = `<div class="screen">${live}</div><div class="screen" style="opacity:${fadeIn}">${g}</div>`;
    else screen = `<div class="screen">${g}</div><div class="screen" style="opacity:${fadeIn}">${live}</div>`;
  } else screen = `<div class="screen">${live}</div>`;
  // Finger
  screen += touchLayer(t);
  // Haptik-Ruck beim Scharfschalten
  let shake = 0;
  for (const g of GEST) { const a = armTime(g); if (a != null && t >= a && t < a + 0.12) shake = Math.sin((t - a) * 160) * 3 * (1 - (t - a) / 0.12); }
  // Kamerafahrt in "charts": leicht naeher
  const zoom = 1 + 0.07 * (hl ? hl.k : 0);
  const x = (W - PH_W) / 2 - BEZEL + shake, y = lerp(H + 40, 548, kin) + kout * (H - 560);
  // GESUND-Sticker faellt vom Muesli (Szene compare)
  let sticker = '';
  const sa = S.compare.sticker;
  if (sa != null && t > sa && t < sa + 2.4) {
    const k = t - sa;
    const p = popIn(k, 0, 0.3, 0.25);
    const fall = Math.max(0, k - 0.75);
    const sx = 40 + fall * 60, sy = 150 + 1800 * fall * fall, rot = -16 + fall * 160;
    sticker = `<svg class="abs" style="left:${sx}px;top:${sy}px;overflow:visible" width="10" height="10"><g transform="rotate(${rot}) scale(${p.s * 1.9})" opacity="${p.o}">${starburst(0, 0, 40, 12, '#3fae5a')}<text x="0" y="6" font-family="OS" font-weight="700" font-size="${15 * (LANG === 'en' ? 0.85 : 1)}" text-anchor="middle" fill="#fff">${tr('gesund')}</text></g></svg>`;
  }
  return `<div class="abs" style="left:${x}px;top:${y}px;width:${PH_W + 2 * BEZEL}px;height:${PH_H + 2 * BEZEL}px;transform:scale(${zoom});transform-origin:50% 60%">
    <div class="abs" style="inset:0;border-radius:64px;background:#050607;border:2px solid #2A2E34;box-shadow:0 40px 120px rgba(0,0,0,.55)"></div>
    <div class="abs" style="left:${BEZEL}px;top:${BEZEL}px;width:${PH_W}px;height:${PH_H}px;border-radius:50px;overflow:hidden">
      <div style="width:1080px;height:1920px;transform:scale(${PHONE_S});transform-origin:0 0;position:relative">${screen}</div>
      <div class="abs" style="left:${PH_W / 2 - 9}px;top:16px;width:18px;height:18px;border-radius:9px;background:#000"></div>
    </div>${sticker}</div>`;
}
function touchLayer(t) {
  let pos = null;
  const draw = (x, y, press, o) => `<div class="abs" style="left:${x - 52}px;top:${y - 52}px;width:104px;height:104px;border-radius:52px;
      background:rgba(255,255,255,${0.16 + 0.12 * press});border:4px solid rgba(255,255,255,0.75);transform:scale(${1 - 0.14 * press});opacity:${o};z-index:20"></div>`;
  for (const tp of TOUCH) {
    if (t < tp.down - 0.3 || t > tp.up + 0.3) continue;
    const o = clamp((t - tp.down + 0.3) / 0.2) * (1 - clamp((t - tp.up) / 0.25));
    const press = t >= tp.down && t < tp.up ? E.cubicOut(clamp((t - tp.down) / 0.08)) : 0;
    pos = draw(tp.x, tp.y, press, o);
  }
  const gst = gestureAt(t);
  if (gst) {
    const g = gst.g, st = appState(g.down);
    const cols = columns(st);
    const i = cols.findIndex(c => c.key === g.key), n = cols.length;
    const colW = (992 - 150 - 12 * n) / n;
    const x = 44 + 150 + 12 + i * (colW + 12) + colW / 2;
    const o = clamp((t - g.down + 0.12) / 0.12) * (1 - clamp((t - g.rel) / 0.25));
    const press = gst.pressed ? 1 : 0;
    pos = draw(x, g.py + gst.dy, press, o);
  }
  return pos || '';
}

function render(t) {
  const html = sceneProblem(t) + phoneLayer(t) + sceneGrade(t) + sceneEnd(t) + captions(t);
  document.getElementById('stage').innerHTML = html;
}

/** Audio-Plan fuer mix.py: Sprecher-Einsaetze + Geraeusche. */
function plan() {
  const vo = SCENES.map(sc => ({ id: sc.id, at: S[sc.id].voAt }));
  const sfx = [];
  const add = (name, at, gain = 1, rate = 1) => sfx.push({ name, at: Math.round(at * 1000) / 1000, gain, rate });
  // Szene 1: Sticker-Plopps (aufsteigende Tonhoehe), Zoom
  const sc = S.problem;
  const tS = word('problem', L(['Müslis', '200'], ['cereals']), 1.4), tG = word('problem', L(['gesund'], ['healthy']), 3.6);
  const nSt = SHELF.boxes.length;
  for (const b of SHELF.boxes) {
    const k = b.k / nSt; if (b.k % 2) continue;
    add('pop', tS + (tG + 0.3 - tS) * Math.pow(k, 0.62), 0.35, 0.9 + 0.7 * k);
  }
  add('zoom', word('problem', L(['Nährwert'], ['nutrition']), 4.4) - 0.3, 0.5);
  add('steps', word('problem', L(['Ameise'], ['ant']), 6.0) - 1.2, 0.35);
  add('whoosh', S.scan.t0 - 0.1, 0.45, 0.8);
  for (const c of CAM) if (c.confirm != null) add('tick', c.confirm, 0.8);
  for (const e of EV) if (e.type === 'current' || e.type === 'addpinned') add('build', e.at, 0.4);
  for (let i = 1; i < 4; i++) add('soft', S.charts.q[i], 0.35);
  for (const g of GEST) {
    const a = armTime(g); if (a != null) add('tick', a, 0.55, 1.25);
    add(g.dy > 0 ? 'whoosh' : 'whooshup', g.rel - 0.05, 0.4);
    if (g.dy > 0) add('pin', g.rel + 0.18, 0.6);
  }
  for (const tp of TOUCH) add('tap', tp.down, 0.6);
  add('pop', S.compare.sticker, 0.35, 0.8);
  add('fall', S.compare.sticker + 0.75, 0.35);
  add('pen', S.grade.circle, 0.5);
  add('whoosh', S.grade.wipe, 0.55, 1.2);
  add('whoosh', S.grade.t0, 0.35, 0.7);
  add('chime', S.end.t0 + 0.2, 0.7);
  add('steps', S.end.t0 + 1.6, 0.25);
  return { lang: LANG, duration: DURATION, vo, sfx, scenes: S };
}

async function init(lang) {
  LANG = lang || new URLSearchParams(location.search).get('lang') || 'de';
  document.documentElement.lang = LANG;
  VO = await (await fetch(`out/vo_${LANG}.json`)).json();
  WORDS = await (await fetch(`out/words_${LANG}.json`)).json();
  buildTimeline();
  buildShelf();
  buildEvents();
  captions(0); // setzt S.charts.q
  await document.fonts.load('700 40px OS'); await document.fonts.load('600 40px OS'); await document.fonts.load('400 40px OS');
  await document.fonts.ready;
  window.DURATION = DURATION;
  return DURATION;
}
/** Nur der App-Bildschirm in voller Groesse (Vergleich mit echten Screenshots). */
function renderRaw(t) {
  const st = appState(t);
  document.getElementById('stage').innerHTML = `<div class="screen">${st.screen === 'generics' ? genericsScreen(t) : liveScreen(t, st, null)}</div>`;
}
window.init = init; window.render = render; window.plan = plan; window.renderRaw = renderRaw;

// Vorschau im Browser: ?lang=de&t=12.3 oder ?play=1
(async () => {
  const q = new URLSearchParams(location.search);
  if (q.get('auto') === '0') return;
  await init(q.get('lang'));
  if (q.get('t')) render(parseFloat(q.get('t')));
  else if (q.get('play')) {
    const t0 = performance.now();
    const loop = () => { const t = (performance.now() - t0) / 1000 % DURATION; render(t); requestAnimationFrame(loop); };
    loop();
  } else render(0);
})();

# Macro Lens — Store-Video (Skript & JS-Umsetzung)

> **Umgesetzt (16.10.2026) in `store/video/`** — vertikal 1080×1920, 30 fps, DE 63,7 s / EN 54,4 s,
> mit Sprecher (Chatterbox Multilingual, lokal) und synthetischer Musik. Abweichungen vom Skript unten:
> vertikal statt 16:9, Regal als 2D-Illustration statt Foto, zusätzlich „+ UNVERPACKT“-Ablauf,
> Wischen nach oben und ein trockener Running Gag („GESUND!“-Sticker, Ameise).
>
> | Datei | Zweck |
> |---|---|
> | `vo.json` | Sprechertext DE/EN je Szene |
> | `tools/tts.sh` → `tts.py`, `align.py` | Stimme (Best-of-4 per Whisper-Rücklesen) + Wort-Zeitstempel |
> | `index.html`, `video.js` | Animation, reine Funktion `render(t)`; App-Nachbau aus `live.gd`/`ui.gd`/`anim.gd` |
> | `render.mjs` | Frames via Headless-Brave (`--shots t1,t2` für Einzelbilder, `--raw` = nur App-Screen) |
> | `mix.py` | Musik + Geräusche + Sprecher, Ducking |
> | `tools/build.sh [de\|en]` | alles → `out/macro-lens-store-<lang>.mp4` (−16 LUFS) |
>
> Vorschau im Browser: `index.html?lang=de&play=1` (über einen lokalen Server ab Projektwurzel).

**Gebaut als JavaScript-Animation** (HTML/CSS/SVG im Browser), **frame-genau gerendert**.
Kein Bildschirm-Mitschnitt — dadurch keine Ruckler und 100 % reproduzierbar.

| | |
|---|---|
| **Länge** | 56 s |
| **Auflösung** | 1920×1080 (16:9), Handy mittig · Alternative 1080×1920 |
| **Bildrate** | 30 fps (≈ 1680 Frames) — 60 fps optional für sehr weiche Wische |
| **Ton** | ruhiger Loop, Akzente auf Scan/Pin · **auch ohne Ton verständlich** |

**Sprache:** Deutsch (englische Textfassung unten). Play-Regel: keine Noten-/Ranking-Aussagen,
**keine genannten Konkurrenten** — die „andere App" bleibt generisch.

---

## 0:00–0:06 — Das Problem

**Bild (Ebene `bg`):** ein echtes Regalfoto, langsam heranzoomend (Ken-Burns, `scale 1.0 → 1.08`).
**Text (Ebene `overlay`):** `Regal voll. Etikett klein. Zeit knapp.`
**JS:** Foto-`transform` linear in `t`, Text `opacity 0→1` bei t=0.6 s, `translateY 12→0`.

## 0:06–0:15 — Ein Scan

**Aufbau:** CSS-Handyrahmen (Radius, Notch) → darin ein `<div class="screen">`, das die App nachbaut.
**Ablauf:**
1. t=6.0–8.0: graustufiges Kamerabild (CSS `filter: grayscale(1)`), grünes Viereck (`div` mit
   Border) skaliert `0.9→1.0` und rastet ein.
2. t=8.0: Haptik-„Tick" als kurzer kleiner Scale-Bounce auf dem Viereck.
3. t=8.2–9.4: **die vier Grafiken bauen sich auf** — genau wie in der App:
   - Donut: **SVG-Kreis**, `stroke-dasharray`-Sweep (`strokeDashoffset`) im Uhrzeigersinn.
   - Zahlen: **JS-Count-up** (`lerp(0, ziel, easeOutCubic)`), 0,6 s.
   - Balken: `div`-Breite `0 → x%`, 0,5 s.
   - „BEST"-Chip: `scale 0.6→1` + `opacity`, erst am Ende.
**Text:** `Ein Scan. Vier Grafiken.`

## 0:15–0:25 — Was die vier Grafiken sagen

**Bild:** dieselbe Ansicht; je ~2 s hebt sich eine Grafik hervor
(andere dimmen auf `opacity 0.35`), Reihenfolge: Donut → Kaloriendichte → Eiweißdichte → Sättigung.
**Text (wechselnd):** `Woraus kommen die Kalorien?` · `Wie viel Energie?` · `Wie viel Eiweiß?` · `Wie sättigend?`
**JS:** Overlay-Label mit Cross-Fade (0,25 s), `dim`-Klasse pro Zelle.

## 0:25–0:40 — Der Vergleich (Herzstück)

**Bild:**
1. t=25.0–27.0: Wisch-Indikator (kleiner Kreis mit Ring) fährt die Spalte **nach unten**,
   die Spalte folgt via `translateY`. Bei Überschreiten der Schwelle: Farbwechsel grau→grün.
2. t=27.0: Loslassen → Spalte rastet zurück (`easeOutBack`, 0,42 s), **orange Nadel** zieht sich
   oben auf (`width 0→100%`, 0,32 s).
3. t=27.5–38.0: nächstes Produkt wird „gescannt", eine neue Spalte baut sich auf (wie in 0:06),
   dann eine dritte, eine vierte. Layout geht 1 → 2 → 3 → 4 Spalten.
4. „BEST" markiert je Zeile den Bestwert (Pop bei Erscheinen der jeweiligen Spalte).
**Text:** `Nach unten wischen = pinnen. Bis zu vier vergleichen.`

## 0:40–0:48 — Die Abgrenzung

**Bild:** links eine **generische** Noten-Karte (großer Buchstabe `A`…`E` in Ampelfarbe, ohne Namen),
die sich als „Note" zu erkennen gibt. Darüber wischt eine Linie → Karte verschwindet.
Rechts erscheinen die vier rohen Zahlen von Macro Lens.
**Text:** `Andere geben dir eine Note.` → (Tausch) → `Macro Lens gibt dir die Zahlen.`
**JS:** Noten-Karte `opacity→0` + `scale 1→0.96`, Zahlen-Count-up erneut.

## 0:48–0:56 — Abschluss

**Bild:** Wortmarke `MACRO LENS` (Pixel-/SemiBold, Akzent auf „LENS"), darunter einblenden:
```
Kein Konto · Keine Werbung · Kein Tracking
Messgerät, kein Tagebuch.
```
**JS:** Logotext `scale 0.94→1` + `opacity`, Zeilen gestaffelt (0,15 s Versatz).

---

## Umsetzung in JavaScript

### Zeitleiste (deterministisch)

Keine `Date.now()`, kein `Math.random()` — ein **virtueller Takt** `t` (Sekunden) steuert alles:

```js
const FPS = 30, DUR = 56;
let t = 0;                       // wird von außen gesetzt (Rendering), nicht fortlaufend
function render(t) { /* positioniert/opak die Ebenen anhand von t */ }
```

Jede Animation ist eine **reine Funktion von `t`** (Start, Dauer, Easing). Damit ist jeder Frame
reproduzierbar — Voraussetzung für sauberes Rendering.

### Ebenen

```
<body> (1920×1080, overflow hidden)
  ├─ .bg         Regalfoto (Ken-Burns)
  ├─ .phone      Rahmen + .screen (die App-Nachbildung)
  ├─ .overlay    große Textzeilen
  ├─ .cursor     Wisch-/Zeige-Indikator
  └─ .endcard    Abschluss
```

### Die App-Nachbildung

Die App in HTML/CSS/SVG nachbauen — nicht abfotografieren, sonst lassen sich Donut-Sweep,
Count-up und Wisch nicht animieren. Zutaten **aus der App übernehmen**, damit es identisch aussieht:

- **Schrift:** dieselben Dateien wie in Godot — `assets/fonts/OpenSans-*.ttf` (Regular/SemiBold/Bold).
- **Farben (dunkles Theme):** Fläche `#17191C` / `#1F2227`, Linie `#2A2E34`, Text `#ECEEF0`,
  gedämpft `#8B9199`, **Akzent Amber `#F0A020`**, gut `#4CC38A`, Warn `#E8B931`,
  Protein `#4C8DF6`, KH `#F0A020`, Fett `#E5684D`.
- **Form:** eckige Karten, dünne Linien, Uppercase-Mikrolabels — der reduzierte Look der App.
- **Charts:** Donut als SVG (`stroke-dasharray`), Balken als `div`-Breite, Zahlen als Zähler.

> Ehrlichkeitsregel: Das Video ist Store-Werbung. Die Nachbildung muss dem echten Verhalten
> entsprechen (Kamera grau, grünes Viereck, Wisch nach unten = pinnen). Keine erfundenen Effekte.

### Rendern (frame-genau)

**Variante A — Remotion** (React, rendert jede Frame-Nummer deterministisch im Headless-Chrome,
schreibt direkt mp4). Angenehmster Workflow; für Einzelpersonen kostenlos.
Modell: `<Sequence from={} durationInFrames={}>` + `useCurrentFrame()`.

**Variante B — Vanilla + Playwright + ffmpeg** (keine Zusatz-Frameworks):

```bash
# 1) Frames rendern: t = f/FPS durchspielen, je Frame ein PNG
#    (Headless-Chrome/Playwright, viewport 1920x1080, deviceScaleFactor 1)
#    page.evaluate((f) => window.render(f / 30), f)  →  screenshot frames/f0000.png
# 2) encodieren
ffmpeg -framerate 30 -i frames/f%04d.png -c:v libx264 -pix_fmt yuv420p -crf 18 \
       -movflags +faststart macro-lens-store.mp4
```

1680 Frames bei 1920×1080 sind wenige Minuten Renderzeit. Vorteil von B: keine Abhängigkeit,
volle Kontrolle; Vorteil von A: weniger Eigenbau. Für dich reicht **B** (Node + Playwright + ffmpeg
hast du ohnehin).

### Prüfpunkte

- **Ohne Ton verständlich** — Text ist die Hauptsprache, VO optional.
- **Tempo:** keine Einstellung länger als 4 s stehen lassen.
- **Kein Flackern:** bei 30 fps alle Bewegungen ≥ 0,2 s; keine 1-Frame-Sprünge.
- **Safe Area:** Text nicht in die äußeren 5 % legen (Store-Zuschnitt).

## Upload (Play)

Video auf **YouTube** laden („nicht gelistet" reicht), URL unter **Store-Eintrag → Vorschau-Video**
eintragen. Play erlaubt 30 s bis 2 min — 56 s passt.

---

# Englische Textfassung (gleiche Bilder)

| Zeit | Text |
|---|---|
| 0:00 | `Shelves full. Labels tiny. No time.` |
| 0:06 | `One scan. Four charts.` |
| 0:15 | `Where do the calories come from? · How much energy? · How much protein? · How filling?` |
| 0:25 | `Swipe down to pin. Compare up to four.` |
| 0:40 | `Others give you a grade.` → `Macro Lens gives you the numbers.` |
| 0:48 | `No account · No ads · No tracking` / `A measuring device, not a diary.` |

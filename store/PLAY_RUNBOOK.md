# Macro Lens → Google Play — Runbook

Stand 15.10.2026. Schritt für Schritt. ✅ = schon erledigt (von mir vorbereitet).

---

## Phase 0 — Entscheidungen vorab

| Frage | Empfehlung |
|---|---|
| **Konto-Typ** | **Einzelperson (personal)** — einfacher, keine D-U-N-S-Nummer. Nachteil: 12-Tester-/14-Tage-Pflicht (Phase 7). Organisation (Firma) umgeht die Testpflicht, braucht aber **D-U-N-S-Nummer** + Firmenverifizierung. |
| **Kosten** | einmalig **25 USD** Registrierung. Sonst keine. |
| **Monetarisierung** | **keine** — der Play-Build enthält bewusst **keinen** Spendenlink (Play-Policy). Optional später Supporter-IAP. |
| **Paketname** | `com.eyedea3d.macrolens` ✅ — **unveränderlich**, nach dem Anlegen nicht mehr änderbar. |
| **Kategorie** | *Gesundheit & Fitness* (Alternative: *Essen & Trinken*) |
| **Zielgruppe** | 13+ (nicht „Kinder") |

---

## Phase 1 — Technische Artefakte ✅ vorbereitet

- [x] **AAB** gebaut, signiert: `build/macro-lens.aab` (≈59 MB, arm64-v8a + armeabi-v7a) — Play zerlegt das automatisch pro Gerät.
- [x] **targetSdk 36** (Play-Vorgabe ab 31.08.2026), minSdk 24.
- [x] **16-KB-Page-Size** aller nativen Bibliotheken geprüft (`libgodot_android.so`, `libbarhopper_v3.so`, …) → alle `0x4000`. Pflicht ab 1.11.2025 erfüllt.
- [x] **Berechtigungen**: nur `CAMERA`, `INTERNET`, `ACCESS_NETWORK_STATE` — keine sensiblen.
- [x] **Store-Grafiken**: `store/icon-512.png`, `store/feature-graphic-1024x500.png`
- [x] **Screenshots** (1080×1920, 9:16): `store/screenshots/de/…` und `…/en/…` (je 4)
- [x] **Texte** DE/EN: `store/listing-de.md`, `store/listing-en.md`
- [x] **Datenschutzerklärung** als Seite: `docs/privacy.html` (→ Phase 3, GitHub Pages aktivieren)

Neuen Build erzeugen:
```bash
tools/setup_build_template.sh      # nur beim ersten Mal / nach Godot-Update
tools/build_plugin.sh              # Barcode-Plugin-AAR
tools/build_aab.sh                 # → build/macro-lens.aab
tools/store_shots.sh               # Store-Screenshots neu rendern
```
> **Vor jedem Play-Update:** `version/code` in `export_presets.cfg` erhöhen (muss je Upload steigen), `version/name` anpassen.

---

## Phase 2 — Entwicklerkonto

1. https://play.google.com/console → **Konto erstellen** (Typ *Einzelperson*).
2. **25 USD** zahlen.
3. **Identität verifizieren** (Ausweis/Adresse). Dauert oft 1–3 Tage — früh anfangen.
4. Kontaktdaten (Name, Anschrift, E-Mail) hinterlegen; die werden im Play-Listing öffentlich gezeigt.

---

## Phase 3 — GitHub Pages für Datenschutz-URL aktivieren

Die Datenschutzerklärung braucht eine **öffentliche URL**. Am einfachsten über GitHub Pages aus `docs/`:

```bash
# einmalig, aus dem Repo heraus
gh api -X POST repos/3p1cball-code/macro-lens/pages \
  -f "source[branch]=main" -f "source[path]=/docs"
```
→ erreichbar unter
`https://3p1cball-code.github.io/macro-lens/` (Landingpage) und
`https://3p1cball-code.github.io/macro-lens/privacy.html` (**die Datenschutz-URL**).

---

## Phase 4 — App in der Play Console anlegen

1. Alle Apps → **App erstellen**.
2. **App-Name:** `Macro Lens` · **Sprache:** Deutsch · **App:** (kein Spiel) · **kostenlos**.
3. Paketname bleibt `com.eyedea3d.macrolens`.

---

## Phase 5 — Store-Eintrag („App-Inhalte" → „Store-Eintrag")

| Feld | Quelle |
|---|---|
| App-Name (≤30) | `store/listing-de.md` |
| Kurzbeschreibung (≤80) | `store/listing-de.md` |
| Vollständige Beschreibung (≤4000) | `store/listing-de.md` |
| App-Symbol 512×512 | `store/icon-512.png` |
| Feature-Grafik 1024×500 | `store/feature-graphic-1024x500.png` |
| Telefon-Screenshots (2–8) | `store/screenshots/de/*.png` |
| Kontakt-E-Mail | `info@augenrahmen.de` |
| Website | `https://augenrahmen.de` (oder die Pages-URL) |
| Kategorie & Tags | Gesundheit & Fitness · Ernährung, Einkaufen |

Englisch zusätzlich anlegen (Übersetzung → Englisch) mit `store/listing-en.md` und `store/screenshots/en/*`.

---

## Phase 6 — Formulare (Pflicht vor Veröffentlichung)

1. **Datenschutzerklärung:** URL aus Phase 3 eintragen.
2. **App-Zugriff:** „Alle Funktionen sind ohne besonderen Zugang verfügbar" (kein Login).
3. **Datensicherheit (Data Safety):**
   - *Erhebt oder teilt deine App Nutzerdaten?* → **Nein**.
   - Der App ist kein Nutzerkonto bekannt; gesendet wird ausschließlich die **Barcode-Nummer** an Open Food Facts (keine personenbezogenen Daten). Das steht so in der Datenschutzerklärung (Kapitel 2).
4. **Zielgruppe & Inhalte:** Altersgruppe **13+**, nicht für Kinder ausgerichtet.
5. **Werbung:** *Nein, keine Werbung*.
6. **Content-Rating (IARC-Fragebogen):** Kategorie *Dienstprogramm/Referenz*; alle Gewalt-/Sex-/Glücksspielfragen **Nein** → erwartete Einstufung *USK 0 / Everyone*.
7. **Gesundheit:** keine medizinischen Aussagen (steht als Hinweis in der Beschreibung).
8. **Behörden-/Nachrichten-/Finanz-Apps:** jeweils *Nein*.

---

## Phase 7 — Signierung & erster Upload (Internal Testing)

1. **Play App Signing** aktivieren (Standard). Hochgeladen wird mit deinem **Upload-Key** = `release.keystore`.
   > ⚠️ Keystore + Passwort sicher aufbewahren (`~/.local/opt/shadegunner-tools/keystore/`). Play verschlüsselt die App-Signatur selbst; der Upload-Key lässt sich im Notfall zurücksetzen.
2. **Testen → Interner Test → Neuen Release erstellen** → `build/macro-lens.aab` hochladen.
3. Release-Notes eintragen, „Speichern", **Review starten** (bei neuen Apps meist wenige Stunden bis 1–2 Tage).
4. Danach den **Internal-Testing-Link** öffnen und auf dem eigenen Gerät installieren → echten Scan-Test machen.

---

## Phase 8 — Geschlossener Test (nur Einzelpersonen-Konten)

Neue **persönliche** Konten müssen **vor** dem Produktionsantrag:
- **≥ 12 Tester** gewinnen, die sich *freiwillig* eintragen (Opt-in über den Closed-Testing-Link),
- **14 Tage am Stück** testen lassen (die Tester müssen die App im Testtrack installiert haben).

Praktisch: `Testen → Geschlossener Test → Testerliste` (E-Mails anlegen) → Link teilen.
Nach Ablauf: **„Produktion beantragen"** — du wirst gefragt, warum du die Freigabe willst (kurz: „Persönlicher Entwickler, 12 Tester über 14 Tage aktiv, App stabil").

> Organisation-Konten überspringen das. Falls dir das zu lang ist: Konto auf *Organisation* upgraden (D-U-N-S nötig).

---

## Phase 9 — Produktion

1. **Produktion → Neuen Release erstellen**, dasselbe AAB, Release-Notes.
2. **Rollout:** erst manuell 10–20 % (staged), ein paar Tage beobachten, dann 100 %.
3. Länder auswählen (DE + EN-Länder), Preis: kostenlos.

---

## Phase 10 — Nach dem Release

- **Vitals** (Abstürze/ANR) im Blick behalten.
- Bewertungen beantworten.
- Updates: `version/code` erhöhen → neues AAB → Production-Release.

---

## Anhang — häufige Stolperfallen

| Stolperstein | Antwort |
|---|---|
| „App bundle must be signed" | `keystore/release` + Passwort in `export_presets.cfg` prüfen. |
| „targetSdk zu alt" | Wir sind auf 36 ✅. |
| „16 KB page size" | Alle `.so` mit `0x4000`-Alignment ✅ (mit `llvm-readelf -l` prüfbar). |
| Kamera wird hinterfragt | Kein sensibler Antrag nötig; nur Zweck in der Beschreibung erwähnen. |
| Sideload-APK ≠ Play-Signatur | Mit Play App Signing hat die Store-Version eine andere Signatur → Nutzer der GitHub-APK müssen die Play-Version ggf. neu installieren (nicht „drüberinstallieren"). |
| Keystore verloren | Upload-Key kann bei Play zurückgesetzt werden, solange das Konto zugänglich ist. |

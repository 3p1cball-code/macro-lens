# Macro Lens → Google Play — Runbook

Stand 17.10.2026 · Version **0.5.0** (versionCode 16). Schritt für Schritt.
✅ = schon erledigt (von mir vorbereitet).

> **Neu seit 0.5.0:** Allergen-/Unverträglichkeits-Warnungen machen Macro Lens zur
> **Health-App („Ernährung und Gewichtsmanagement“)**. Folgen: Health-Deklaration ankreuzen,
> Pflicht-Hinweis „kein Medizinprodukt“ im Store-Text (drin), Kamera-Hinweis vor der
> Berechtigung (in der App), Data Safety ehrlich mit „App-Aktivität“. Einzelpersonen-Konto
> bleibt zulässig (Organisation nur für *medizinische* Apps).
> GitHub-Releases (APK) gibt es nicht mehr – verteilt wird nur noch über Play.

> **Gewählter Weg: Einzelpersonen-Konto.** Das heißt konkret:
> 25 USD → Identitätsprüfung → App + Formulare → **geschlossener Test mit ≥ 12 Testern über
> 14 Tage** → Produktionsantrag → Review.
>
> | Wann | Was | Dauer |
> |---|---|---|
> | Tag 0 | Konto + 25 USD + Identitätsprüfung | 1–3 Tage (blockiert alles) |
> | Tag 1–3 | App anlegen, Store-Eintrag, Formulare, Internal-Test | ~1 Tag |
> | Tag 4 | Geschlossenen Test starten (12 Tester finden) | — |
> | Tag 4–18 | Test läuft (App installiert lassen!) | 14 Tage |
> | Tag 18 | Produktion beantragen | — |
> | Tag 19–21 | Review + Rollout | 1–3 Tage |
>
> **≈ 3 Wochen ab heute.** Der lange Pol ist die Verifizierung (früh starten) und die 14 Testtage.
>
> Hilfsdateien:
> - `store/tester-invite.md` — Weiterleit-Text für die 12 Tester + Nachverfolgungstabelle
> - `store/production-request.md` — fertige Antworten für Data-Safety, Content-Rating und den Produktionsantrag
> - `store/release-notes-template.md` — Release-Notes-Vorlagen

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

- [x] **AAB 0.5.0** gebaut, signiert: `build/macro-lens.aab` (arm64-v8a + armeabi-v7a) — Play zerlegt das automatisch pro Gerät. Geprüft: versionCode 16, Signatur, Berechtigungen, 16-KB-Alignment.
- [x] **targetSdk 36** (Play-Vorgabe ab 31.08.2026), minSdk 24.
- [x] **16-KB-Page-Size** aller nativen Bibliotheken geprüft (`libgodot_android.so`, `libbarhopper_v3.so`, …) → alle `0x4000`. Pflicht ab 1.11.2025 erfüllt.
- [x] **Berechtigungen**: nur `CAMERA`, `INTERNET`, `ACCESS_NETWORK_STATE`, `VIBRATE`. `CAMERA` gilt bei Health-Apps als gesundheitsrelevant → In-App-Hinweis vor der Anfrage ✅.
- [x] **Store-Grafiken**: `store/icon-512.png`, `store/feature-graphic-1024x500.png` (DE), `store/feature-graphic-1024x500-en.png` (EN) — `python3 tools/make_store_assets.py`
- [x] **Screenshots** (1080×1920, 9:16): `store/screenshots/de/…` und `…/en/…` (je 7: Vergleich, Allergen-Warnung, eigene Seite, Editor, Allergen-Liste, Kein Lebensmittel, Unverpackt)
- [x] **Texte** DE/EN: `store/listing-de.md`, `store/listing-en.md`, Release-Notes 0.5.0 in `store/release-notes-template.md` — geprüft mit `python3 tools/check_listing.py`
- [x] **Datenschutzerklärung** live: https://3p1cball-code.github.io/macro-lens/privacy.html

Neuen Build erzeugen:
```bash
tools/setup_build_template.sh      # nur beim ersten Mal / nach Godot-Update
tools/build_plugin.sh              # Barcode-Plugin-AAR
tools/build_aab.sh                 # → build/macro-lens.aab
tools/store_shots.sh               # Store-Screenshots neu rendern
python3 tools/make_store_assets.py # Icon + Feature-Grafiken DE/EN
python3 tools/check_listing.py     # Zeichengrenzen + Grafiken prüfen
```
> **Vor jedem Play-Update:** `version/code` in `export_presets.cfg` erhöhen (muss je Upload steigen), `version/name` anpassen.

---

## Phase 2 — Entwicklerkonto

1. https://play.google.com/console → **Konto erstellen** (Typ *Einzelperson*).
2. **25 USD** zahlen.
3. **Identität verifizieren** (Ausweis/Adresse). Dauert oft 1–3 Tage — früh anfangen.
4. Kontaktdaten (Name, Anschrift, E-Mail) hinterlegen; die werden im Play-Listing öffentlich gezeigt.

---

## Phase 3 — Datenschutz-URL ✅ aktiviert

GitHub Pages ist eingerichtet und live:

- Landingpage: **https://3p1cball-code.github.io/macro-lens/**
- Datenschutzerklärung (diese URL im Formular eintragen):
  **https://3p1cball-code.github.io/macro-lens/privacy.html**

(Wiederherstellen/neu aktivieren, falls nötig:
`gh api -X POST repos/3p1cball-code/macro-lens/pages -f "source[branch]=main" -f "source[path]=/docs"`)

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
| Feature-Grafik 1024×500 | `store/feature-graphic-1024x500.png` (EN: `…-en.png`) |
| Telefon-Screenshots (2–8) | `store/screenshots/de/*.png` (7 Stück, Reihenfolge 1–7) |
| Kontakt-E-Mail | `macro-lens@eyedea3d.com` |
| Website | `https://3p1cball-code.github.io/macro-lens/` |
| Kategorie & Tags | Gesundheit & Fitness · Ernährung, Einkaufen, Allergien |

Englisch zusätzlich anlegen (Übersetzung → Englisch) mit `store/listing-en.md`, `store/screenshots/en/*` und `store/feature-graphic-1024x500-en.png`.

---

## Phase 6 — Formulare (Pflicht vor Veröffentlichung)

1. **Datenschutzerklärung:** URL aus Phase 3 eintragen.
2. **App-Zugriff:** „Alle Funktionen sind ohne besonderen Zugang verfügbar" (kein Login).
3. **Datensicherheit (Data Safety):** *Ja* – nur **App-Aktivität** (In-App-Suchverlauf optional, Barcode-Nummer als „Sonstige Aktionen“), nicht geteilt, verschlüsselt, Zweck App-Funktionalität. Allergen-Auswahl bleibt lokal → nicht angeben. Tabelle + Begründung: `store/production-request.md`.
4. **Zielgruppe & Inhalte:** Altersgruppe **13+**, nicht für Kinder ausgerichtet.
5. **Werbung:** *Nein, keine Werbung*.
6. **Content-Rating (IARC-Fragebogen):** Kategorie *Dienstprogramm/Referenz*; alle Gewalt-/Sex-/Glücksspielfragen **Nein** → erwartete Einstufung *USK 0 / Everyone*.
7. **Gesundheits-Apps:** **„Ernährung und Gewichtsmanagement“**, kein Medizinprodukt. Pflicht-Hinweis in der Beschreibung ✅.
8. **Behörden-/Nachrichten-/Finanz-Apps:** jeweils *Nein* bzw. „keine“.

---

## Phase 7 — Signierung & erster Upload (Internal Testing)

1. **Play App Signing** aktivieren (Standard). Hochgeladen wird mit deinem **Upload-Key** = `release.keystore`.
   > ⚠️ Keystore + Passwort sicher aufbewahren (`~/.local/opt/shadegunner-tools/keystore/`). Play verschlüsselt die App-Signatur selbst; der Upload-Key lässt sich im Notfall zurücksetzen.
2. **Testen → Interner Test → Neuen Release erstellen** → `build/macro-lens.aab` hochladen.
3. Release-Notes eintragen, „Speichern", **Review starten** (bei neuen Apps meist wenige Stunden bis 1–2 Tage).
4. Danach den **Internal-Testing-Link** öffnen und auf dem eigenen Gerät installieren → echten Scan-Test machen.

---

## Phase 8 — Geschlossener Test (dein Pflichtteil)

Neue **persönliche** Konten müssen **vor** dem Produktionsantrag:
- **≥ 12 Tester** gewinnen, die sich *freiwillig* eintragen (Opt-in über den Closed-Testing-Link),
- **14 Tage am Stück** testen lassen (die Tester müssen die App im Testtrack installiert haben).

Praktisch: `Testen → Geschlossener Test → Testnutzer` (E-Mails anlegen) → Link teilen.
**Details, Einladungstext und Nachverfolgung: `store/tester-invite.md`.**
Nach Ablauf: **„Produktion beantragen"** — Formulierung siehe `store/production-request.md`.

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
- Updates: `tools/bump_version.sh 0.5.1` → `tools/build_aab.sh` → Production-Release
  (Release-Notes-Vorlage: `store/release-notes-template.md`).

---

## Anhang — häufige Stolperfallen

| Stolperstein | Antwort |
|---|---|
| „App bundle must be signed" | `keystore/release` + Passwort in `export_presets.cfg` prüfen. |
| „targetSdk zu alt" | Wir sind auf 36 ✅. |
| „16 KB page size" | Alle `.so` mit `0x4000`-Alignment ✅ (mit `llvm-readelf -l` prüfbar). |
| Kamera wird hinterfragt | Kein sensibler Antrag nötig; nur Zweck in der Beschreibung erwähnen. |
| Sideload-APK ≠ Play-Signatur | Mit Play App Signing hat die Store-Version eine andere Signatur → die selbst gebaute App vor der Play-Installation deinstallieren (Verlauf/Einstellungen gehen dabei verloren). |
| „Health-App braucht Organisationskonto“ | Nur medizinische Apps und Forschungs-Apps. Ernährung/Allergene = „Ernährung und Gewichtsmanagement“ → Einzelperson ok. |
| Allergen-Warnung als Medizin missverstanden | Hinweis „kein Medizinprodukt …“ steht in Beschreibung und App; die App sagt nie „sicher“. |
| Keystore verloren | Upload-Key kann bei Play zurückgesetzt werden, solange das Konto zugänglich ist. |

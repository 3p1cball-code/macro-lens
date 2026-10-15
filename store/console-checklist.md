# Play Console — Checkliste (zum Abhaken)

Konto ist erstellt ✅. Jetzt in dieser Reihenfolge durch die Console.

---

## 0. Zuallererst: Verifizierung

- [ ] **Konto → Kontodetails / Verifizierung:** Identität bestätigen (Ausweis/Adresse).
  Bei Einzelpersonen nötig, bevor veröffentlicht werden kann. Läuft parallel — **kein Grund zu warten**,
  du kannst App und Formulare schon fertig machen.

---

## 1. App anlegen

- [ ] **Alle Apps → App erstellen**
- [ ] App-Name: `Macro Lens`
      *(falls belegt: `Macro Lens – Nährwerte per Scan`; max. 30 Zeichen)*
- [ ] Standardsprache: **Deutsch**
- [ ] Typ: **App** (kein Spiel)
- [ ] **Kostenlos** ⚠️ *Diese Wahl ist endgültig – kostenlos kann später nicht kostenpflichtig werden.*
- [ ] Erklärungen (Play-Richtlinien, US-Export) → Häkchen setzen

---

## 2. App-Inhalte (Dashboard → „App-Inhalte")

Alle Punkte müssen „fertig" sein, sonst lässt sich kein Release veröffentlichen.

- [ ] **Datenschutzerklärung:** `https://3p1cball-code.github.io/macro-lens/privacy.html`
- [ ] **App-Zugriff:** *Alle Funktionen sind ohne besonderen Zugang verfügbar* (kein Login)
- [ ] **Werbung:** *Nein, meine App enthält keine Werbung*
- [ ] **Inhaltseinstufung (IARC):** E-Mail + Kategorie *Dienstprogramm/Referenz*,
      alle Gewalt-/Sex-/Drogen-/Glücksspielfragen → **Nein**
- [ ] **Zielgruppe:** Altersgruppen 13+, „App an Kinder gerichtet?" → **Nein**
- [ ] **Neuigkeiten-App:** Nein
- [ ] **COVID-19-Kontaktverfolgung:** Nein
- [ ] **Datensicherheit:** *Erhebt/teilt die App Nutzerdaten?* → **Nein**
- [ ] **Behörden-App:** Nein
- [ ] **Finanzfunktionen:** Nein
- [ ] **Gesundheits-App:** ehrlich „Nein" (reine Nährwert-Information, keine Gesundheitsdaten,
      keine medizinischen Aussagen)

> Formulierungen zum Kopieren: **`store/production-request.md`**

---

## 3. Store-Eintrag (Dashboard → „Store-Eintrag" → „Hauptfilial-Eintrag")

- [ ] App-Name: `Macro Lens`
- [ ] Kurzbeschreibung (≤80): aus `store/listing-de.md`
- [ ] Vollständige Beschreibung (≤4000): aus `store/listing-de.md`
- [ ] App-Symbol: `store/icon-512.png`
- [ ] Feature-Grafik: `store/feature-graphic-1024x500.png`
- [ ] Telefon-Screenshots (mind. 2): `store/screenshots/de/1_dauerscan.png` … `4_grundnahrung.png`
- [ ] Kategorie: **Gesundheit & Fitness**
- [ ] Kontakt-E-Mail: `macro-lens@eyedea3d.com`
- [ ] Website (optional): `https://augenrahmen.de`
- [ ] Sprachen: Deutsch (Standard) — danach **Englisch** ergänzen (Übersetzung → Englisch)
      mit `store/listing-en.md` + `store/screenshots/en/`

---

## 4. Erster Upload (internal testing)

- [ ] **Testen → Interner Test → Neuen Release erstellen**
- [ ] Play App Signing bestätigen (Standard)
- [ ] **AAB hochladen:** `build/macro-lens.aab` (neu bauen: `tools/build_aab.sh`)
- [ ] Release-Name/Notes: aus `store/release-notes-template.md`
- [ ] **Speichern → Review starten** (bei neuen Apps oft einige Stunden)
- [ ] Nach Freigabe: Link öffnen, auf dem eigenen Handy installieren, **echten Scan testen**

---

## 5. Danach

- [ ] **Geschlossener Test** starten (12 Tester, 14 Tage) → `store/tester-invite.md`
- [ ] Nach 14 Tagen **Produktion beantragen** → Text in `store/production-request.md`
- [ ] **Produktions-Rollout** (erst 10–20 %, dann 100 %)

---

## Gut zu wissen

- **Paketname** wird beim ersten Upload festgelegt (`com.eyedea3d.macrolens`) → nicht mehr änderbar.
- **Version hochziehen** vor jedem Upload: `tools/bump_version.sh 0.3.0` → `tools/build_aab.sh`
- **Nur kostenlos & werbefrei** = die Formulare bleiben so einfach wie hier beschrieben.
  (Supporter-IAP später nachrüstbar.)

# Play Console — Checkliste (zum Abhaken)

Stand: Version **0.5.0** (versionCode 16). Konto ist erstellt ✅. Jetzt in dieser Reihenfolge
durch die Console.

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
- [ ] **Datensicherheit:** *Erhebt/teilt die App Nutzerdaten?* → **Ja**, nur *App-Aktivität*
      (In-App-Suchverlauf optional, Barcode-Nummer als „Sonstige Aktionen“), nicht geteilt,
      verschlüsselt, Zweck App-Funktionalität → Details in `store/production-request.md`
- [ ] **Behörden-App:** Nein
- [ ] **Finanzfunktionen:** keine
- [ ] **Gesundheits-Apps:** **„Ernährung und Gewichtsmanagement“** ankreuzen (Allergen-Warnungen,
      spezielle Ernährungsbedürfnisse), *kein* Medizinprodukt, keine Health-Connect-Berechtigungen.
      Der Pflicht-Hinweis „kein Medizinprodukt …“ steht in der Beschreibung.

> Formulierungen zum Kopieren: **`store/production-request.md`**

---

## 3. Store-Eintrag (Dashboard → „Store-Eintrag" → „Hauptfilial-Eintrag")

- [ ] App-Name: `Macro Lens`
- [ ] Kurzbeschreibung (≤80): aus `store/listing-de.md`
- [ ] Vollständige Beschreibung (≤4000): aus `store/listing-de.md`
- [ ] App-Symbol: `store/icon-512.png`
- [ ] Feature-Grafik: `store/feature-graphic-1024x500.png`
- [ ] Telefon-Screenshots: alle 7 aus `store/screenshots/de/` in der Reihenfolge 1–7
      (Liste mit Beschreibung in `store/listing-de.md`)
- [ ] Kategorie: **Gesundheit & Fitness**
- [ ] Kontakt-E-Mail: `macro-lens@eyedea3d.com`
- [ ] Website (optional): `https://3p1cball-code.github.io/macro-lens/`
- [ ] Sprachen: Deutsch (Standard) — danach **Englisch** ergänzen (Übersetzung → Englisch)
      mit `store/listing-en.md`, `store/screenshots/en/` und
      `store/feature-graphic-1024x500-en.png`

---

## 4. Erster Upload (internal testing)

- [ ] **Testen → Interner Test → Neuen Release erstellen**
- [ ] Play App Signing bestätigen (Standard)
- [ ] **AAB hochladen:** `build/macro-lens.aab` (neu bauen: `tools/build_aab.sh`)
- [ ] Release-Name: `0.5.0`, Notes: Abschnitt „0.5.0“ aus `store/release-notes-template.md`
- [ ] **Speichern → Review starten** (bei neuen Apps oft einige Stunden)
- [ ] Nach Freigabe: Link öffnen, auf dem eigenen Handy installieren (vorher die selbst
      gebaute App deinstallieren – andere Signatur), **echten Scan testen**: Kamera-Hinweis,
      Scan, Allergen-Warnung (z. B. Milch + Nutella), Einstellungen

---

## 5. Danach

- [ ] **Geschlossener Test** starten (12 Tester, 14 Tage) → `store/tester-invite.md`
- [ ] Nach 14 Tagen **Produktion beantragen** → Text in `store/production-request.md`
- [ ] **Produktions-Rollout** (erst 10–20 %, dann 100 %)

---

## Gut zu wissen

- **Paketname** wird beim ersten Upload festgelegt (`com.eyedea3d.macrolens`) → nicht mehr änderbar.
- **Version hochziehen** vor jedem *weiteren* Upload: `tools/bump_version.sh 0.5.1` → `tools/build_aab.sh`
  (0.5.0 / versionCode 16 ist der erste Upload)
- **Texte prüfen:** `python3 tools/check_listing.py` (Zeichengrenzen, Grafiken)
- **Nur kostenlos & werbefrei** = die Formulare bleiben so einfach wie hier beschrieben.
  (Supporter-IAP später nachrüstbar.)

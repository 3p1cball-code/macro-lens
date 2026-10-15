# Texte für die Play Console (vorbereitet)

## Produktion beantragen („Warum sollte deine App Produktionszugriff erhalten?")

Kurz, faktisch, ohne Marketing:

```
Macro Lens ist fertig, stabil und vollständig getestet. Die App hat den geschlossenen Test
mit 12 Testern über 14 Tage durchlaufen; in dieser Zeit gab es keine offenen Abstürze (Android
Vitals: keine Abstürze/ANR mit Handlungsbedarf).

Die App ist ein einfaches Werkzeug zum Vergleichen von Nährwerten per Barcode-Scan:
- kein Nutzerkonto, keine Anmeldung, keine Werbung, keine In-App-Käufe
- keine Datenerhebung; gesendet wird ausschließlich die Barcode-Nummer an die offene
  Datenbank Open Food Facts (in der Datenschutzerklärung beschrieben)
- nur die notwendigen Berechtigungen (Kamera, Internet)
- Deutsch und Englisch, hell und dunkel

Ich möchte die App jetzt für alle Nutzer freigeben.
```

## Data Safety (Datensicherheit)

| Frage | Antwort |
|---|---|
| Erhebt oder teilt die App erforderliche Nutzerdatentypen? | **Nein** |
| Werden Daten verschlüsselt übertragen? | (entfällt, da keine Erhebung) — falls abgefragt: **Ja** (HTTPS) |
| Können Nutzer die Löschung ihrer Daten anfordern? | **Nein** (es werden keine personenbezogenen Daten gespeichert) |
| Zugriff ohne Anmeldung | **Ja, alle Funktionen ohne besonderen Zugang** |

> Begründung, falls ein Prüfer nachfragt: Die App sendet beim Scan nur die Barcode-Nummer an
> `world.openfoodfacts.org`. Es werden keine Konten, keine Standortdaten, keine Geräte-Kennungen
> und keine Nutzungsprofile erstellt oder übertragen.

## Content-Rating (IARC-Fragebogen)

- App-Typ: **Dienstprogramm / Referenz / Nachschlagewerk**
- Gewalt, Sexualität, Drogen, Glücksspiel, Schrecken, Nutzerinteraktion: **überall Nein**
- Erwartete Einstufung: **USK 0 / Everyone / PEGI 3**

## Zielgruppe

- Altersgruppen: **13–15, 16–17, 18+** (nicht „unter 13")
- „App an Kinder gerichtet?" → **Nein**
- Store-Präsenz für Familienprogramm: **Nein**

## Weitere Formulare

| Formular | Antwort |
|---|---|
| Werbung | **Nein, keine Werbung** |
| App-Zugriff | **Alle Funktionen ohne besonderen Zugang verfügbar** |
| Nachrichten-App | Nein |
| Behörden-App | Nein |
| Finanz-Funktionen | Nein |
| Health-Connect / Gesundheitsdaten | Nein (nur Nährwerte aus öffentlicher Datenbank) |
| Sonderberechtigungen (MANAGE_EXTERNAL_STORAGE, QUERY_ALL_PACKAGES, …) | **keine** |

## Contact / Öffentlichkeit

Bei **Einzelpersonen-Konten** werden **Entwicklername und Kontaktdaten im Store öffentlich**
angezeigt.
- Entwicklername: `Alexander Riedel` (oder z. B. `augenrahmen`)
- E-Mail: `info@augenrahmen.de`
- Website: `https://augenrahmen.de` (optional)

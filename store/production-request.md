# Texte und Antworten für die Play Console (Stand 0.5.0)

Seit 0.5.0 hat Macro Lens **Allergen-/Unverträglichkeits-Warnungen**. Damit ist die App für
Google eine **Health-App (Kategorie „Ernährung und Gewichtsmanagement“)** – das ändert drei
Antworten gegenüber der ersten Fassung: Health-Deklaration, Data Safety, Kamera-Hinweis.

---

## Health-Apps-Deklaration (App-Inhalte → „Gesundheits-Apps“)

Pflicht für jede App, auch ohne Gesundheitsfunktionen.

| Frage | Antwort |
|---|---|
| Gesundheitsfunktionen | **Ernährung und Gewichtsmanagement** („Nutrition and Weight Management“) – *„Apps focused on specific dietary needs or goals“* |
| Weitere Kategorien | keine (nicht „Krankheiten und Erkrankungen“, keine Diagnose, kein Tracking) |
| Medizinprodukt? | **Nein** |
| Health Connect / Gesundheitsberechtigungen | **keine** |

- Für Ernährungs-Apps reicht ein **Einzelpersonen-Konto**. Ein Organisationskonto verlangt Google
  nur für *medizinische* Apps (Patientenportale, Telemedizin, Software als Medizinprodukt …) und
  Forschungs-Apps.
- Pflicht-Hinweis im Store-Text ist drin (letzter Absatz der Beschreibung):
  *„Macro Lens ist kein Medizinprodukt und dient nicht der Diagnose, Behandlung, Heilung oder
  Vorbeugung von Krankheiten.“*
- **Kamera:** `CAMERA` steht auf Googles Liste gesundheitsrelevanter Berechtigungen. Für Health-Apps
  verlangt Google eine deutliche Erklärung + Zustimmung in der App. Ab 0.5.0 erscheint vor der
  ersten Kamera-Anfrage ein Hinweis („Macro Lens braucht die Kamera – nur für Barcodes …“,
  Knopf „Kamera erlauben“). Erst danach kommt der Android-Dialog.

---

## Data Safety (Datensicherheit)

Google: *„Erheben“ = Daten verlassen das Gerät* – auch an fremde Server. Die App schickt
Barcode-Nummern und Suchbegriffe an Open Food Facts. Das steht so in der Datenschutzerklärung;
Data Safety und Datenschutzerklärung müssen zusammenpassen. **Empfehlung: ehrlich angeben**
(zeigt im Store „App-Aktivitäten“, kostet nichts, vermeidet Rückfragen im Review).

| Frage | Antwort |
|---|---|
| Erhebt oder teilt die App erforderliche Nutzerdatentypen? | **Ja** |
| Werden alle Nutzerdaten bei der Übertragung verschlüsselt? | **Ja** (HTTPS) |
| Können Nutzer die Löschung anfordern? | **Nein** – kein Konto, der Entwickler speichert nichts (Hinweis: Anfragen landen bei Open Food Facts) |
| Unabhängige Sicherheitsprüfung | Nein |

**Datentypen**

| Datentyp | Erhoben | Geteilt | Flüchtig verarbeitet | Erforderlich? | Zweck |
|---|---|---|---|---|---|
| App-Aktivität → **In-App-Suchverlauf** (Suchbegriffe der Namenssuche) | Ja | Nein¹ | Nein² | **Optional** (nur bei Nutzung der Suche) | App-Funktionalität |
| App-Aktivität → **Sonstige Aktionen** (Barcode-Nummer des gescannten Produkts) | Ja | Nein¹ | Nein² | Erforderlich (Scan-Funktion) | App-Funktionalität |

¹ Übertragung an Dritte auf ausdrückliche Nutzeraktion hin, bei der der Nutzer das erwartet
(Ausnahme „user-initiated action“) – Open Food Facts ist der Dienst, den die App sichtbar abfragt.
² Was Open Food Facts serverseitig protokolliert, kann die App nicht garantieren → „Nein“.

**Nicht anzugeben** (bleibt auf dem Gerät): Allergen-Auswahl (Gesundheitsangaben), Verlauf,
Vorlagen, Einstellungen, Kamerabilder.

> Alternative, wenn du die Zeile im Store vermeiden willst: „Nein, keine Erhebung“ mit der
> Begründung, dass Barcode-Nummern und Produktnamen keine personenbezogenen Daten sind.
> Vertretbar, aber Google definiert „Erheben“ technisch (Daten verlassen das Gerät) – deshalb
> nicht meine Empfehlung.

---

## Content-Rating (IARC-Fragebogen)

- App-Typ: **Dienstprogramm / Referenz / Nachschlagewerk**
- Gewalt, Sexualität, Drogen, Glücksspiel, Schrecken, Nutzerinteraktion: **überall Nein**
- Erwartete Einstufung: **USK 0 / Everyone / PEGI 3**

## Zielgruppe

- Altersgruppen: **13–15, 16–17, 18+** (nicht „unter 13")
- „App an Kinder gerichtet?" → **Nein**

## Weitere Formulare

| Formular | Antwort |
|---|---|
| Werbung | **Nein, keine Werbung** |
| App-Zugriff | **Alle Funktionen ohne besonderen Zugang verfügbar** |
| Nachrichten-App | Nein |
| Behörden-App | Nein |
| Finanzfunktionen | **Keine** (Deklaration ausfüllen: „keine Finanzfunktionen“) |
| Sonderberechtigungen (MANAGE_EXTERNAL_STORAGE, QUERY_ALL_PACKAGES, …) | **keine** |

---

## Produktion beantragen („Warum sollte deine App Produktionszugriff erhalten?")

```
Macro Lens ist fertig, stabil und getestet. Die App hat den geschlossenen Test mit 12 Testern
über 14 Tage durchlaufen; in dieser Zeit gab es keine offenen Abstürze (Android Vitals: keine
Abstürze/ANR mit Handlungsbedarf). Rückmeldungen der Tester zu Allergen-Warnungen und Bedienung
sind eingeflossen.

Die App vergleicht Nährwerte per Barcode-Scan und warnt optional vor ausgewählten Allergenen
und Unverträglichkeiten:
- kein Nutzerkonto, keine Werbung, keine In-App-Käufe
- Allergen-Auswahl, Verlauf und Einstellungen bleiben auf dem Gerät; an die offene Datenbank
  Open Food Facts gehen nur Barcode-Nummer bzw. Suchbegriff (in Datenschutzerklärung und
  Data Safety beschrieben)
- Kamera nur für die Barcode-Erkennung auf dem Gerät, mit Hinweis vor der Berechtigung
- klarer Hinweis, dass die App kein Medizinprodukt ist und das Etikett maßgeblich bleibt
- Deutsch und Englisch, hell und dunkel

Ich möchte die App jetzt für alle Nutzer freigeben.
```

---

## Öffentliche Angaben

Bei **Einzelpersonen-Konten** werden Entwicklername und Kontaktdaten im Store öffentlich angezeigt.
- Entwicklername: `Alexander Riedel`
- E-Mail: `macro-lens@eyedea3d.com`
- Website: `https://3p1cball-code.github.io/macro-lens/`

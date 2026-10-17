# Macro Lens

**Kamera auf ein Produkt → Barcode erkannt → die Grafiken, die dir wichtig sind.**
Keine Nährwerttabelle zum Lesen, keine Noten, keine Konten, keine Cloud.

Macro Lens ist eine kleine Android-App für gesundheitsbewusste Menschen, die im
Supermarkt **schneller bessere Kaufentscheidungen** treffen wollen. Das Angebot ist
riesig, die Zeit am Regal kurz: Man steht mit zwei Joghurts im Gang und will in
Sekunden wissen, welcher die bessere Wahl ist — ohne Etikett, ohne Rechnerei.

Bewusst **ohne** Mengen, Mahlzeiten oder Tagesbilanz. Die App macht genau eins:
das übervolle Supermarktangebot schnell filtern.

<p align="center">
  <img src="screenshots/live.png" width="31%" alt="Dauerscan mit Live-Kamera und bis zu vier verglichenen Produkten">
  <img src="screenshots/live_custom.png" width="31%" alt="Eigene Hauptseite mit fünf Bausteinen">
  <img src="screenshots/layout.png" width="31%" alt="Hauptseiten-Editor mit Vorlagen und Baustein-Dock">
</p>

Die ganze App ist **ein Screen**: oben die Live-Kameravorschau, darunter die
Grafiken — standardmäßig vier, oder bis zu fünf selbst gewählte Bausteine. **Spalte nach unten wischen = pinnen** für den direkten Vergleich
(bis zu vier), **nach oben wischen = entfernen**. Keine Knöpfe dafür, keine Menüs,
kein Scrollen.

## Was es ist

Ein **Messgerät**, kein Tagebuch. Es scannt durchgehend: Barcode ins obere
Drittel halten, die vier Grafiken darunter aktualisieren sich sofort. Spalte
**nach unten** wischen pinnt das Produkt, der nächste Scan erscheint daneben — bis
zu vier Produkte im Vergleich. **Nach oben** wischen wirft eine Spalte wieder raus.

Standardmäßig tragen vier Grafiken die Kaufentscheidung — nichts wird zu einer
Note zusammengefasst. In den Einstellungen lässt sich die Hauptseite aus **bis zu
fünf von zehn Bausteinen** zusammenstellen (fünf passen ohne Scrollen):

| Baustein | Beantwortet die Frage | Optionen |
|---|---|---|
| **Makro-Donut** *(Standard)* | Woraus kommen die Kalorien? | Zucker als eigener Teil, Wert in der Mitte |
| **Kaloriendichte** *(Standard)* | Wie energiedicht ist es? | pro 100 g / Portion / Packung |
| **Eiweiß** *(Standard)* | Wie viel Eiweiß pro 100 kcal? | pro 100 kcal oder Gramm pro 100 g / Portion / Packung |
| **Sättigung** *(Standard)* | Wie satt macht es pro Kalorie? (Schätzung) | Sättigung 2.0 oder klassischer Fullness Factor |
| **Zucker** | Wie viel Zucker? | g, % der KH, pro 100 kcal, % Energie; pro 100 g / Portion / Packung |
| **Ballaststoffe** | Wie viele Ballaststoffe? | g oder pro 100 kcal; pro 100 g / Portion / Packung |
| **Salz** | Wie viel Salz? | Salz in g oder Natrium in mg; pro 100 g / Portion / Packung |
| **Gesättigte Fette** | Wie viel gesättigtes Fett? | g, % vom Fett, % Energie |
| **Fettqualität** | Wie viel vom Fett ist gesättigt? | — |
| **Ampel** | Fett, Gesättigte, Zucker, Salz auf einen Blick | Zeilen an/aus, optional Ballaststoffe und Eiweiß |

Jeder Baustein kann das **BEST**-Produkt der Zeile markieren. Die Farbe beschreibt
immer das Lebensmittel selbst (pro 100 g / 100 ml), die Balkenlänge den
angezeigten Wert — „rot“ bleibt also auch „pro Packung“ ehrlich.

Fünf **Vorlagen** (Standard, Satt & leicht, Eiweiß-Fokus, Zucker-Check, Fett &
Salz) plus **eigene Vorlagen**. Der Editor arbeitet mit Drag & Drop: Baustein aus
dem Dock in die Vorschau ziehen (rastet ein), ziehen zum Umsortieren, zurück ins
Dock ziehen zum Entfernen; Tippen öffnet die Einstellungen. Alles wird sofort
gespeichert.

Bewusst **kein** Nutri-Score, keine A–E-Note, kein Gesamtscore — die Ampel zeigt
einzelne Lichter, nie eine Note. Fehlt ein Eingangswert, entfällt der betroffene
Wert — es wird nie geraten.

### Sättigung 2.0

Sättigung ist eine Schätzung pro Kalorie (0–100). Kern ist der veröffentlichte
**Fullness Factor** (an die Satiety-Index-Daten von Holt et al. 1995 gefittet:
Energiedichte, Eiweiß, Ballaststoffe, Fett, mit den Original-Grenzen). Dazu kommt,
was er pro Kalorie übersieht: **Ballaststoffe pro 100 kcal** (bis +8),
**Eiweiß pro 100 kcal** (bis +6) und **Zucker**: Abzug über 25 % Zuckerenergie
(bis −15) und bei Getränken proportional zum Zuckeranteil (bis −30), weil flüssige
Zuckerkalorien kaum ausgeglichen werden. Fehlen Ballaststoffe oder Zucker, entfällt
nur der jeweilige Term. Der klassische Fullness Factor ist in den
Baustein-Einstellungen wählbar.

### Schwellen

Die Ampelfarben folgen den Front-of-Pack-Schwellen der britischen Food Standards
Agency (pro 100 g; für Getränke strenger pro 100 ml). Ballaststoffe und Eiweiß
folgen den EU-Angaben „Quelle“ / „hoher Gehalt“. Orientierung, keine medizinische
Bewertung.

## Was es nicht ist

Kein Konto, keine Cloud, keine Werbung, keine Telemetrie, kein Tracking, kein
Kalender, keine Tagesziele. Alles bleibt auf dem Gerät. Nach außen gehen nur der
Barcode (bzw. ein Suchbegriff) an Open Food Facts — und bei Barcodes, die Open
Food Facts nicht kennt, der Barcode an die Schwesterprojekte Open Products Facts
und Open Beauty Facts.

## Funktionen

- **Dauerscan**: Live-Kameravorschau (CameraX) mit On-Device-ML-Kit-Barcode-Decoder
  (gebündelt, ohne Play-Services-Zwang) — EAN-8/13, UPC-A/E, Code 128, Code 39,
  ITF. Barcode reinhalten, Grafiken aktualisieren.
- **Wischen & Vergleich**: nach unten = pinnen, nach oben = entfernen; bis zu vier
  nebeneinander, Bestwert je Grafik markiert.
- **Eigene Hauptseite**: bis zu fünf von zehn Bausteinen, fünf Vorlagen, eigene
  Vorlagen, Drag-&-Drop-Editor, Einstellungen je Baustein (bleiben gespeichert).
- **Pro 100 g, Portion oder Packung**: Portions- und Packungsgrößen werden vom
  Etikett gelesen („4 x 125 g“, „1,5 l“, „1 Portion (30 g)“). Getränke werden mit
  1 ml ≈ 1 g umgerechnet (in den Einstellungen abschaltbar).
- **Kein Lebensmittel?** Kennt Open Food Facts einen Barcode nicht, fragt die App
  bei Open Products Facts und Open Beauty Facts nach — Waschmittel scannen ergibt
  „Putzmittel ist kein Frühstück“ statt eines Netzwerkfehlers.
- **Robuste Abfragen**: „nicht gefunden“, „Limit“ und „keine Verbindung“ werden
  unterschieden; Produkt- und Suchanfragen getrennt gedrosselt; Suchen gecacht und
  zusammengelegt; Suche über Search-a-licious mit der alten Suche als Rückfall.
- **Optionales X** zum sofortigen Schließen der App (Einstellungen).
- **Allergene & Unverträglichkeiten** (Einstellungen): Auswahl aus den 14
  EU-Hauptallergenen („Nüsse (alle)“ inkl. Erdnüsse, dazu „Nur Erdnüsse“) sowie
  Laktose, Fruktose, Sorbit, Koffein, Histamin. Enthält ein gescanntes Produkt eine
  ausgewählte Allergie, wird es **rot** hinterlegt (drei kräftige Vibrationen), bei
  Unverträglichkeit oder Allergen-Spur **orange** (eine kräftige Vibration); ein
  Banner sagt warum, Tippen auf die Spalte zeigt alles. Erkannt wird über
  Allergen-Angaben, Spuren und Zutatenliste von Open Food Facts (deutsche/englische
  Stichwörter, Verneinungen wie „ohne Milch“, Fallen wie Kokosmilch oder
  Kakaobutter, „laktosefrei“/„glutenfrei“); Grundnahrungsmittel sind kuratiert.
  Fehlen Zutaten, steht „nicht geprüft“ – nie „sicher“. **Eine Hilfe, keine
  Garantie: immer das Etikett lesen.** Die Auswahl bleibt auf dem Gerät.
- **Unverpackt-Liste** (~65 Grundnahrungsmittel: Banane, Haferflocken, Hähnchen,
  Skyr …), direkt in den Vergleich übernehmbar, vollständig offline.
- **Namenssuche** über Open Food Facts.
- **Offline-Cache**: jedes gescannte Produkt wird lokal gemerkt.
- **Verlauf** mit Suche, **manuelle Barcode-Eingabe** als Fallback.
- **Deutsch / Englisch**, Hell / Dunkel.

## Daten

Die Nährwerte stammen aus [Open Food Facts](https://world.openfoodfacts.org) (ODbL).
Die Unverpackt-Liste basiert auf USDA FoodData Central (public domain).
Die Barcode-Erkennung läuft on-device über den gebündelten ML-Kit-Scanner (CameraX-Vorschau).

> Daten: Open Food Facts (ODbL) · Generika: USDA FoodData Central · Nicht-Lebensmittel: Open Products Facts, Open Beauty Facts

## Download

Macro Lens kommt in den **Google Play Store**. APK-Builds werden hier nicht mehr
veröffentlicht; bis zum Store-Release lässt sich die App selbst bauen (siehe
unten). Die alten APK-Releases auf GitHub sind veraltet.

## Aus dem Quelltext bauen

Voraussetzungen: Linux, [Godot 4.7](https://godotengine.org), JDK 17, Android-SDK
(Platform + Build-Tools 36) und ein passendes NDK, dazu ein Release-Keystore.

Die Skripte nehmen die während der Entwicklung genutzte Toolchain an
(`~/.local/opt/shadegunner-tools/`); überschreibbar über `SHADEGUNNER_TOOLS`,
`JAVA_HOME` und `ANDROID_HOME`.

```bash
# 1) Godot-Android-Build-Template installieren (und lokales NDK setzen)
tools/setup_build_template.sh

# 2) Barcode-Plugin-AAR bauen -> addons/macrolens/macrolens-barcode.aar
tools/build_plugin.sh

# 3) Signier-Konfiguration anlegen
cp export_presets.cfg.example export_presets.cfg   # Keystore + Passwort eintragen

# 4) signierte Release-APK exportieren -> build/macro-lens.apk
tools/build_apk.sh
```

Tests (Rechenlogik, App-Zustand, Gesten, Netz/Nicht-Lebensmittel, Layout & Editor):

```bash
godot --headless --path . --script res://tests/test_metrics.gd
godot --headless --path . --script res://tests/test_app.gd
godot --headless --path . --script res://tests/test_gesture.gd
godot --headless --path . --script res://tests/test_off.gd
godot --headless --path . --script res://tests/test_layout.gd
godot --headless --path . --script res://tests/test_allergens.gd
```

Screenshots aller Screens (Demo-Daten):

```bash
tools/shots.sh
```

## Projektstruktur

```
src/
  food.gd            Datenmodell (alles pro 100 g, -1 = fehlt)
  metrics.gd         die Rechnung hinter allen Grafiken (Bezug, Schwellen, Sättigung) — getestet
  blocks.gd          die zehn Bausteine: Katalog, Optionen, Auswertung
  layout.gd          Hauptseite, Vorlagen, eigene Vorlagen
  nonfood.gd         Nicht-Lebensmittel: Einordnung und Texte
  allergens.gd       Allergene & Unverträglichkeiten: Katalog und Erkennung
  off_client.gd      Open-Food-Facts-Client (Fehlerklassen, Drosselung, Caches, Nicht-Lebensmittel)
  generics.gd        mitgelieferte Unverpackt-Liste
  store.gd           lokale Persistenz (Cache, Verlauf, Einstellungen)
  i18n.gd            DE/EN-Texte
  app.gd             Zustand, Navigation, Ablage, Screenshot-Harness
  ui/                Design-System (Palette, Karten, Buttons, Typografie)
  widgets/           Makro-Donut, Balken
  screens/           live (Dauerscan), Hauptseiten-Editor, Unverpackt, Suche, Verlauf, Einstellungen, Über
assets/about/        Porträt für die Über-Seite
data/generics.json   Unverpackt-Liste (pro 100 g)
plugins/macrolens-barcode/   Kotlin-Quelle des Godot-Android-Plugins
addons/macrolens/    gepacktes Plugin (AAR + Export-Plugin)
tests/               Unit- und UI-Tests
```

Die Rechnung (`metrics.gd`) ist bewusst von Netz und UI getrennt und lässt sich
gegen echte Etiketten prüfen, ohne die App zu starten.

## Stand

Im Alltag benutzbar. Scannen → Lookup → Grafiken → Vergleich funktioniert
durchgängig; seit 0.4.0 ist die Hauptseite frei zusammenstellbar, seit 0.5.0 gibt es
Allergen- und Unverträglichkeits-Warnungen. Geplant:
Play-Store-Build (AAB) mit optionaler Unterstützer-Option.

## Lizenz

MIT — siehe [LICENSE](LICENSE). Nährwertdaten: Open Food Facts (ODbL).

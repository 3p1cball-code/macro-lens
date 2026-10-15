# Release-Notes — Vorlage

Max. **500 Zeichen pro Sprache** im Play-Console-Feld „Neuigkeiten in dieser Version".

## Erstveröffentlichung (geschlossener Test)

```
Erster Test-Build.
Barcode scannen → vier Grafiken statt Nährwerttabelle: Makro-Donut, Kaloriendichte,
Eiweißdichte und Sättigung. Bis zu vier Produkte im direkten Vergleich (PIN),
Unverpackt-Liste, Verlauf, Deutsch/Englisch, hell/dunkel.
```
```
First test build.
Scan a barcode → four charts instead of a nutrition table: macro donut, calorie
density, protein density and satiety. Compare up to four products (PIN),
unpackaged basics, history, German/English, light/dark.
```

## Vorlage für Updates

```
Neu:
- …

Behoben:
- …

Bekannt:
- …
```
```
New:
- …

Fixed:
- …

Known:
- …
```

---

## Versionsnummer erhöhen

```bash
tools/bump_version.sh 0.3.0        # versionCode +1, versionName setzen
tools/build_aab.sh                 # → build/macro-lens.aab
```
Jeder Play-Upload braucht einen **höheren versionCode** — der Name ist frei wählbar.

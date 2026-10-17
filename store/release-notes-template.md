# Release-Notes

Max. **500 Zeichen pro Sprache** im Play-Console-Feld „Neuigkeiten in dieser Version".
Der Text muss in **Sprach-Tags** stehen (`<de-DE>…</de-DE>`, `<en-US>…</en-US>`),
sonst meckert die Console „Text außerhalb der Sprach-Tags". Zeichen prüfen:
`python3 tools/check_listing.py`.

## 0.5.0 — erster Upload (interner / geschlossener Test)

Ein Feld, beide Sprachen in Tags:

```
<de-DE>
Erste Version im Play Store.
• Barcode scannen und bis zu vier Produkte nebeneinander vergleichen
• Eigene Hauptseite aus bis zu fünf von zehn Bausteinen, mit Vorlagen
• Allergene & Unverträglichkeiten: Produkte werden rot/orange hinterlegt, mit Vibration und Begründung
• Pro 100 g, Portion oder Packung
• Waschmittel & Co. werden als „kein Lebensmittel“ erkannt
• Ohne Konto, ohne Werbung, ohne Tracking
</de-DE>
<en-US>
First version on Google Play.
• Scan barcodes and compare up to four products side by side
• Build your own home screen from up to five of ten blocks, with presets
• Allergens & intolerances: products are highlighted red/orange, with vibration and the reason
• Per 100 g, serving or pack
• Detergent and the like are recognised as "not food"
• No account, no ads, no tracking
</en-US>
```

## Vorlage für Updates

```
<de-DE>
Neu in Version X.Y:
• …
• …
Fehlerbehebungen und kleinere Verbesserungen.
</de-DE>
<en-US>
New in version X.Y:
• …
• …
Bug fixes and minor improvements.
</en-US>
```

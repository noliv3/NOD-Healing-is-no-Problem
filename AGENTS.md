# Projektweite Hinweise für NOD-Heal

## Geltungsbereich
Diese Richtlinien gelten für das gesamte Repository, sofern in Unterordnern keine spezifischeren `AGENTS.md`-Dateien vorhanden sind.

## Stil- und Strukturvorgaben
- Alle Addon-Dateien liegen unter `NOD_Heal/`.
- Lua-Module verwenden `local` für Funktionen/Tabellen, die nicht global benötigt werden.
- Gemeinsame Funktionen werden über einen zentralen Namespace `NODHeal` exportiert (siehe `Core/Init.lua`).
- Kommentare im Code möglichst deutsch/englisch gemischt vermeiden; entscheide dich pro Datei für eine Sprache (bevorzugt Englisch).

## Dokumentation
- Jede funktionale Änderung sollte in der `README.md` nachvollziehbar sein.
- Backend-Entscheidungen orientieren sich an `DOCU/NOD_Backend_Funktionsreferenz.md`.
- Planungs- und Vergleichsdokumente im Ordner `DOCU/` sind nach dem Schema `NOD_*` bzw. thematisch sprechend benannt (z.B. `NOD_Systemaufbau_Modulstruktur.docx`, `NOD_Konzept_Funktionsliste.txt`). Bitte bei neuen Dateien dieselbe klare Benennung beibehalten.

## Testing & Tooling
- Aktuell existieren keine automatisierten Tests; bei manuellen Tests das Ergebnis im PR-/Commit-Text dokumentieren.

Viel Erfolg beim Ausbau des Addons!

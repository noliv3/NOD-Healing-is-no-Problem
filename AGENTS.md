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
- Planungs- und Vergleichsdokumente im Ordner `DOCU/` liegen bevorzugt als Markdown (`.md`) vor und folgen sprechenden Dateinamen wie `NOD_Systemaufbau_Modulstruktur.md` oder `HealingAddons_Funktionsvergleich_NOD_Integration.md`. Bei neuen Inhalten bitte dieses Format und die Benennung fortführen.
- Bereits produktiv umgesetzte Core-Module: `HealthSnapshot`, `CastLandingTime`, `IncomingHeals`, `HealValueEstimator`, `PredictiveSolver`, `LatencyTools`. Die verbleibenden Platzhalter (`DamagePrediction`, `AuraTickPredictor`, `EffectiveHP`, `DesyncGuard`, `CoreDispatcher`) werden weiterhin gemäß Funktionsreferenz ergänzt.

## Testing & Tooling
- Aktuell existieren keine automatisierten Tests; bei manuellen Tests das Ergebnis im PR-/Commit-Text dokumentieren.

Viel Erfolg beim Ausbau des Addons!

## Auditvermerk (aktueller Stand)
- Konform zur WoW-Addon-Konvention: `Core/Init.lua` (`RegisterModule`, `GetModule`), `Core/CastTiming.lua` (`CastTiming:Compute` mit statischem GCD, noch zu verfeinern) sowie `Core/IncomingHealAggregator.lua` (`AddHeal`, `GetIncoming`).
- Backend-Grundpfad aktiv: `Core/HealthSnapshot.lua`, `Core/CastLandingTime.lua`, `Core/IncomingHeals.lua`, `Core/HealValueEstimator.lua`, `Core/PredictiveSolver.lua`, `Core/LatencyTools.lua` verfügen nun über lauffähige Kernfunktionen.
- Noch ohne funktionsfähige Umsetzung bzw. WoW-API-Anbindung: Platzhalter in `Core/` (`DamagePrediction`, `AuraTickPredictor`, `EffectiveHP`, `DesyncGuard`, `CoreDispatcher`) sowie `UI/Init.lua`.

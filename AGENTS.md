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
- UI-Frame-Dokumentation wird aus `DOCU/NOD_Konzept_Funktionsliste.txt` generiert und liegt versioniert unter `docu/ui_frames/`. Nutzt zum Aktualisieren das Skript `scripts/generate_ui_frame_yaml.py`, damit die Segmentierung (≤500 Einträge pro Datei, Rest in `unsorted.yaml`) konsistent bleibt.
- Bereits produktiv umgesetzte Core-Module: `HealthSnapshot`, `CastLandingTime`, `IncomingHeals`, `HealValueEstimator`, `PredictiveSolver`, `LatencyTools` sowie die nun angebundenen Welle-1-Komponenten (`DamagePrediction`, `AuraTickPredictor`, `EffectiveHP`, `DesyncGuard`, `CoreDispatcher`).

## Testing & Tooling
- Aktuell existieren keine automatisierten Tests; bei manuellen Tests das Ergebnis im PR-/Commit-Text dokumentieren.

Viel Erfolg beim Ausbau des Addons!

## Auditvermerk (aktueller Stand)
- Konform zur WoW-Addon-Konvention: `Core/Init.lua` (`RegisterModule`, `GetModule`), `Core/CastTiming.lua` (`CastTiming:Compute` mit statischem GCD, noch zu verfeinern) sowie `Core/IncomingHealAggregator.lua` (`AddHeal`, `GetIncoming`).
- Backend-Grundpfad aktiv: `Core/HealthSnapshot.lua`, `Core/CastLandingTime.lua`, `Core/IncomingHeals.lua`, `Core/HealValueEstimator.lua`, `Core/PredictiveSolver.lua`, `Core/LatencyTools.lua` verfügen nun über lauffähige Kernfunktionen.
- Welle 1 der Backend-Module ist nun lauffähig: `Core/DamagePrediction.lua` (liefert `Estimate` mit Rate & Betrag), `Core/AuraTickPredictor.lua` (Tick-Mengen + Sammelfunktion), `Core/IncomingHealAggregator.lua` (Dispatcher-gestützter Heal-Feed), `Core/EffectiveHP.lua`, `Core/DesyncGuard.lua`, `Core/CoreDispatcher.lua` liefern produktive Daten für den Solver.
- Noch ohne funktionsfähige Umsetzung bzw. WoW-API-Anbindung: Frontend-Platzhalter `UI/Init.lua` sowie Erweiterungen außerhalb Welle 1.
- Stabilisierung 2025-03: `IncomingHealAggregator` und `IncomingHeals` besitzen jetzt `CleanExpired`-Hilfen mit Zeitpuffer; `CastLandingTime` normalisiert Castzeiten & Grenzwerte; `LatencyTools` refresht bei jeder Abfrage und klemmt CVars; `PredictiveSolver` klemmt negative Beiträge.

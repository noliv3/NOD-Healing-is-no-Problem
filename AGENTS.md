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
- Die aktuelle Verzeichnisstruktur inkl. Zielinstallationspfad wird in `DOCU/NOD_Heal_Pfadstruktur.md` gepflegt und bei Strukturänderungen aktualisiert.
- UI-Frame-Dokumentation wird aus `DOCU/NOD_Konzept_Funktionsliste.txt` generiert und liegt versioniert unter `docu/ui_frames/`. Nutzt zum Aktualisieren das Skript `scripts/generate_ui_frame_yaml.py`, damit die Segmentierung (≤500 Einträge pro Datei, Rest in `unsorted.yaml`) konsistent bleibt.
- Feedback-Protokolle zu UI-Bausteinen werden unter `DOCU/Feedback/` geführt; ergänzt neue Einträge je Feature (z. B. Grid-Rebuild-Logs inkl. `player`-Frame) zeitnah.
- Bereits produktiv umgesetzte Core-Module: `HealthSnapshot`, `CastLandingTime`, `IncomingHeals`, `HealValueEstimator`, `PredictiveSolver`, `LatencyTools` sowie die nun angebundenen Welle-1-Komponenten (`DamagePrediction`, `AuraTickPredictor`, `EffectiveHP`, `DesyncGuard`, `CoreDispatcher`).

## Testing & Tooling
- Aktuell existieren keine automatisierten Tests; bei manuellen Tests das Ergebnis im PR-/Commit-Text dokumentieren.

## Review-/Build-Checkliste
- TOC-Datei (`NOD_Heal/NOD_Heal.toc`) auf Vollständigkeit prüfen.
- Modul-Initialisierung gegen `NOD_Backend_Funktionsreferenz.md` abgleichen.
- Event-Routen und Dispatcher-Hooks verifizieren (`Core/CoreDispatcher.lua`).
- Latenz- und Queue-Werte mit Live-API oder Mock-Werten plausibilisieren.
- SavedVariables und Debug-Toggles auf Persistenz- und Speicherbedarf prüfen.
- Dokumentation (`README.md`, `DOCU/`) nachziehen und Version angeben.
- Spell-Binding-GUI (`UI/BindingFrame.lua`) über `/nodgui` erreichbar halten; Änderungen an den Bindings im README vermerken.
- Binding-GUI Tag 8: `/nodgui` öffnet das neue Drag-&-Drop-Interface mit Spellbook-Autofill, Dropdown-Auswahl für Modifier/Mausbuttons und persistenter Frame-Position (`NODHealDB.ui.bindingFrame`).
- Neuer Vermerk: `DOCU/NOD_Datenpfad_LHC_API.md` dokumentiert den LibHealComm-Datenpfad (Tag 1, Fallback-Spezifikation).
- Tag‑1-LHC-Brücke produktiv: SavedVariables `NODHealDB.useLHC`, Slash `/nod healcomm`, LibHealComm-Callbacks, Aggregator-Cleanups sowie Mini-Status-UI liefern echte Laufzeit-Logs.
- Build-Artefakte ohne Entwicklungsdateien paketieren.
- Release-Notizen mit bekannten Risiken und Checks verlinken.
- Smoke-Test im Client ohne LUA-Fehler bestätigen.

Viel Erfolg beim Ausbau des Addons!

## Auditvermerk (aktueller Stand)
- Konform zur WoW-Addon-Konvention: `Core/Init.lua` (`RegisterModule`, `GetModule`), `Core/CastTiming.lua` (`CastTiming:Compute` mit statischem GCD, noch zu verfeinern) sowie `Core/IncomingHealAggregator.lua` (`AddHeal`, `GetIncoming`).
- Backend-Grundpfad aktiv: `Core/HealthSnapshot.lua`, `Core/CastLandingTime.lua`, `Core/IncomingHeals.lua`, `Core/HealValueEstimator.lua`, `Core/PredictiveSolver.lua`, `Core/LatencyTools.lua` verfügen nun über lauffähige Kernfunktionen.
- Welle 1 der Backend-Module ist nun lauffähig: `Core/DamagePrediction.lua` (liefert `Estimate` mit Rate & Betrag), `Core/AuraTickPredictor.lua` (Tick-Mengen + Sammelfunktion), `Core/IncomingHealAggregator.lua` (Dispatcher-gestützter Heal-Feed), `Core/EffectiveHP.lua`, `Core/DesyncGuard.lua`, `Core/CoreDispatcher.lua` liefern produktive Daten für den Solver.
- CoreDispatcher besitzt jetzt einen globalen Safe-Invoker (`safeCall`), einen Fehler-Ringpuffer (`/nod errors`) sowie Logout-/Leaving-World-Abbruch des 0,2‑s-Tickers; `/nod debug on|off|status` steuert den Log-Level bei aktivierter Throttle (`logThrottle`).
- Mini-Status-Frame (`UI/Init.lua`) steht unten rechts (200×40 px, Offset −20/80), aktualisiert alle 0,5 s Quelle (`LHC`/`API`) inklusive grün/gelb-Farbcode und zeigt die laufende Spielzeit präzise an.
- Overlay-Phase 2 (`UI/Overlay.lua`) liefert dynamische Breiten für Prognose-Balken, nutzt weiterhin `IncomingHealAggregator:GetIncomingForGUID` (Fallback Blizzard-API), respektiert den Overlay-Toggle in `NODHeal.Config` und hebt Healthbars beim Hover dezent hervor.
- GridFrame-Basis (`UI/GridFrame.lua`) erstellt ein verschiebbares Fünf-Spalten-Raster, zeigt Solo/Party/Raid-Einheiten mit Klassenfarben und Tooltip-Hover an und reserviert eine Incoming-Heal-Lane.
- Click-Cast-System (`UI/ClickCast.lua`) mappt Mausbuttons inkl. Alt/Ctrl/Shift-Kombinationen auf Heilzauber, hookt Blizzard-Player-/Party-/Raid-Frames, liefert Hover/Modifier-Highlights und ruft `CastSpellByName` direkt auf dem anvisierten Frame auf.
- Stabilisierung 2025-03: `IncomingHealAggregator` und `IncomingHeals` besitzen jetzt `CleanExpired`-Hilfen mit Zeitpuffer; `CastLandingTime` normalisiert Castzeiten & Grenzwerte; `LatencyTools` refresht bei jeder Abfrage und klemmt CVars; `PredictiveSolver` klemmt negative Beiträge.
- HealthSnapshot kapselt `UnitHealth`/`UnitHealthMax` über einen Safe-Wrapper, damit ungültige Einheiten keine `[NOD] ERROR`-Logs mehr erzeugen.

## Vor Merge prüfen
- [ ] Pfade/Module konsistent zu `/NOD_Heal/NOD_Heal.toc`
- [ ] Einheiten dokumentiert (ms, %, HP)
- [ ] Keine spekulativen Aussagen
- [ ] Logs: Level & Orte definiert
- [ ] UI-Hooks genannt, keine Stilvorgaben
- [ ] Testszenarien verlinkt (`DOCU/Tests.md`)
- [ ] README/AGENTS Abschnittslängen eingehalten
- [ ] Keine externen Abhängigkeiten unerwähnt
- [ ] Changelog-Hinweis auf v1.1-Plan enthalten

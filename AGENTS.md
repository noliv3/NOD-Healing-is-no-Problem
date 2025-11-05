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
- Binding-GUI Tag 8: `/nodgui` öffnet das neue Drag-&-Drop-Interface mit Spellbook-Autofill, Dropdown-Auswahl für Modifier/Mausbuttons, Delete-Schaltflächen pro Zeile und persistenter Frame-Position (`NODHealDB.ui.bindingFrame`).
- Neuer Vermerk: `DOCU/NOD_Datenpfad_LHC_API.md` dient als Archiv; aktive Implementierung nutzt ausschließlich Blizzard-APIs ohne LibHealComm-Abhängigkeit.
- Eingehende Heilungen laufen vollständig über Combat-Log-Feeds + `UnitGetIncomingHeals`; SavedVariables müssen keine LHC-Toggles mehr enthalten und Slash-Kommandos fokussieren sich auf Debug/Error-Ausgaben.
- Build-Artefakte ohne Entwicklungsdateien paketieren.
- Release-Notizen mit bekannten Risiken und Checks verlinken.
- Smoke-Test im Client ohne LUA-Fehler bestätigen.

Viel Erfolg beim Ausbau des Addons!

## Auditvermerk (aktueller Stand)
- Konform zur WoW-Addon-Konvention: `Core/Init.lua` (`RegisterModule`, `GetModule`), `Core/CastTiming.lua` (`CastTiming:Compute` mit statischem GCD, noch zu verfeinern) sowie `Core/IncomingHealAggregator.lua` (`AddHeal`, `GetIncoming`).
- Backend-Grundpfad aktiv: `Core/HealthSnapshot.lua`, `Core/CastLandingTime.lua`, `Core/IncomingHeals.lua`, `Core/HealValueEstimator.lua`, `Core/PredictiveSolver.lua`, `Core/LatencyTools.lua` verfügen nun über lauffähige Kernfunktionen.
- Welle 1 der Backend-Module ist nun lauffähig: `Core/DamagePrediction.lua` (liefert `Estimate` mit Rate & Betrag), `Core/AuraTickPredictor.lua` (Tick-Mengen + Sammelfunktion), `Core/IncomingHealAggregator.lua` (Dispatcher-gestützter Heal-Feed), `Core/EffectiveHP.lua`, `Core/DesyncGuard.lua`, `Core/CoreDispatcher.lua` liefern produktive Daten für den Solver.
- CoreDispatcher besitzt jetzt einen globalen Safe-Invoker (`safeCall`), einen Fehler-Ringpuffer (`/nod errors`) sowie Logout-/Leaving-World-Abbruch des 0,2‑s-Tickers; `/nod debug on|off|status` steuert den Log-Level bei aktivierter Throttle (`logThrottle`).
- Mini-Status-Frame (`UI/Init.lua`) steht unten rechts (200×40 px, Offset −20/80), aktualisiert alle 0,5 s die Quelle („API“) inklusive Farbcode und zeigt die laufende Spielzeit präzise an.
- Overlay-Phase 2 (`UI/Overlay.lua`) liefert dynamische Breiten für Prognose-Balken, nutzt weiterhin `IncomingHealAggregator:GetIncomingForGUID` (Fallback Blizzard-API), respektiert den Overlay-Toggle in `NODHeal.Config` und hebt Healthbars beim Hover dezent hervor.
- GridFrame-Basis (`UI/GridFrame.lua`) erstellt ein verschiebbares Fünf-Spalten-Raster, zeigt Solo/Party/Raid-Einheiten mit Klassenfarben und Tooltip-Hover an, registriert Click-Casts direkt über `NODHeal.Bindings` und zeichnet die Incoming-Heal-Lane dynamisch mittels `UnitGetIncomingHeals`; seit Tag 3 werden Healthbars alle 0,1 s weich animiert, wechseln bei niedriger HP die Farbe, zeigen halbtransparente Overheal-Überlagerungen und kombinieren Blizzard-Incoming-Heals mit Solver-Projektionen für eine vorausschauende Darstellung. Neu: `/nodsort` setzt das Roster-Sortierverhalten (group/class/alpha), der Grid-Rebuild reagiert verzögert auf Roster-Events und markiert den Spieler mit einem halbtransparenten weißen Rahmen.
- Neues Optionsfenster (`UI/Options.lua`, Slash `/nodoptions`) liefert ein sofort wirksames Layout-Panel für Grid-Scale, Spaltenanzahl, Spacing, Hintergrund-Alpha sowie Overheal/Incoming-Heal-Toggles und einen Lock-Schalter; Änderungen landen in `NODHeal.Config`, werden nach `NODHealDB.config` persistiert und triggern automatisch `NODHeal.Grid.Initialize()`.
- Click-Cast-System (`UI/ClickCast.lua`) mappt Mausbuttons inkl. Alt/Ctrl/Shift-Kombinationen auf Heilzauber, registriert ausschließlich die eigenen `SecureUnitButtonTemplate`-GridFrames und setzt deren Attribute (Spell/Unit) kampfsicher.
- Spell-Bindings werden beim Login automatisch aus `NODHealDB.bindings` geladen; fällt `CompactUnitFrame_OnEnter` weg (Classic-API), greifen Tooltip-Hooks direkt über die GridFrames.
- Stabilisierung 2025-03: `IncomingHealAggregator` und `IncomingHeals` besitzen jetzt `CleanExpired`-Hilfen mit Zeitpuffer; `CastLandingTime` normalisiert Castzeiten & Grenzwerte; `LatencyTools` refresht bei jeder Abfrage und klemmt CVars; `PredictiveSolver` klemmt negative Beiträge.
- HealthSnapshot kapselt `UnitHealth`/`UnitHealthMax` über einen Safe-Wrapper, damit ungültige Einheiten keine `[NOD] ERROR`-Logs mehr erzeugen.

- SavedVariables-Synchronisierung konsolidiert: `Config/Defaults.lua` spiegelt Grid-, Overlay- und Debug-Optionen zwischen `NODHeal.Config` und `NODHealDB.config`; Module können `NODHeal.ApplyConfigDefaults()` aufrufen.
- Einheitliches Log-Gateway (`NODHeal.Log`/`Logf`) ersetzt direkte `print`-Aufrufe in UI-Komponenten und respektiert das Debug-Flag; Zwangsausgaben nutzen `force = true`.
- GridFrame reagiert auf zusätzliche Events (`UNIT_CONNECTION`, `PLAYER_ROLES_ASSIGNED`, `PLAYER_REGEN_ENABLED`) und exportiert `unitFrames` für Overlay-/Click-Cast-Fallbacks; Tooltip-Aufrufe sind gegen fehlendes `GameTooltip` abgesichert.
- Overlay-Hooks prüfen vor `hooksecurefunc`, ob `CompactUnitFrame_*` verfügbar ist, und verwenden sichere Refresh-Pfade statt direkter Global-Zugriffe.
- Binding-/Options-UI melden Konflikte über das Log-System und persistieren Sortieränderungen unmittelbar.
- Neue Artefakte: `reports/QA_Report.md`, `reports/change_log.md`, `reports/bindings_snapshot.json` und `DOCU/Validation/Functional_Readiness.md` dokumentieren den aktuellen Heal-Ready-Status.
- **Refresh 2025-11-05:** Inventar (`reports/file_inventory.json`) und Binding-Snapshot wurden neu erzeugt; Folgesweeps sollen die Dateien mit neuen UTC-Zeitstempeln aktualisieren und die QA-Checks in README/DOCU spiegeln.

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

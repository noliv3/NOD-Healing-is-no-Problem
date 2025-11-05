# NOD-Heal (Mists of Pandaria Classic)

NOD-Heal ist ein leistungsorientiertes Healing-Framework für den WoW-Client der Mists-of-Pandaria-Classic-Ära. Dieses Repository enthält die Addon-Struktur, die sukzessive zu einem modularen Vorhersage-Healsystem ausgebaut wird.

## Aktueller Stand
- Basisordnerstruktur gemäß Projektplan erstellt (`NOD_Heal/`).
- Erste Backend-Kernmodule implementiert: HealthSnapshot, CastLandingTime, IncomingHeals, HealValueEstimator, PredictiveSolver und LatencyTools bilden den Datenpfad für Heal-Prognosen.
- DamagePrediction, AuraTickPredictor, IncomingHealAggregator, EffectiveHP, DesyncGuard und CoreDispatcher arbeiten nun mit produktiven WoW-API-Anbindungen und sind an den Solver angebunden.
- Eingehende Heilungen basieren vollständig auf Blizzard-APIs: Combat-Log-Feeds landen im Aggregator, `UnitGetIncomingHeals` dient als Fallback und der Statusrahmen kennzeichnet die Quelle als „API“.
- TOC-Datei mit Load-Reihenfolge eingerichtet.

### Backend-Stabilisierung
- `Core/IncomingHealAggregator` speichert pro Ziel GUID-Queues, räumt via `CleanExpired` automatisch auf und fasst Combat-Log-basierte Heilungen für die Prognose zusammen.
- `Core/IncomingHeals` kombiniert die Aggregator-Daten mit `UnitGetIncomingHeals`, liefert aggregierte Summen sowie Confidence-Level und benötigt keine externen Bibliotheken.
- `Core/CastLandingTime` normalisiert Castzeiten (Millisekunden/Sekunden) und klemmt Warteschlange sowie Latenz auf sinnvolle Grenzwerte.
- `Core/LatencyTools` aktualisiert Latenz- und Spell-Queue-Werte bei jeder Abfrage und clamped CVars gegen Ausreißer.
- `Core/PredictiveSolver` verhindert negative Beiträge aus Schaden-, Heal- oder HoT-Bausteinen, bevor das projizierte Ergebnis berechnet wird.
- CoreDispatcher bootstrappt Events, startet einen 0,2‑s-Ticker für `CleanExpired` und `PredictiveSolver:CalculateProjectedHealth("player")`, kapselt Callback-Aufrufe über einen Safe-Invoker und beendet den Ticker sauber bei Logout/Leaving-World.
- Globaler Error-Ring (`/nod errors`) und Debug-Toggle (`/nod debug on|off|status`) sammeln Fehlermeldungen throttled über den Dispatcher-Logger (`logThrottle` ≥0,25 s).
- Mini-Status-Frame (`UI/Init.lua`) steht unten rechts (200×40 px, Offset −20/80), aktualisiert alle 0,5 s die Quelle („API“) inklusive Farbcode und zeigt die laufende Spielzeit in Millisekundenpräzision.
- Overlay-Phase 1 (`UI/Overlay.lua`) hängt einen grünen Prognose-Balken an CompactUnitFrame-Gesundheitsleisten, nutzt `IncomingHealAggregator:GetIncomingForGUID` (Fallback `UnitGetIncomingHeals`) und respektiert den Toggle `NODHeal.Config.overlay`.
- Overlay-Phase 2 erweitert die Prognose-Balken um dynamische Breitensteuerung und einen Hover-Highlight-Effekt auf den CompactUnitFrames.
- GridFrame-Kern (`UI/GridFrame.lua`) erzeugt ein verschiebbares Raster mit Klassenfarben, Tooltip-Hover und Solo-Fallback für Spieler-, Party- und Raid-Mitglieder; der `player`-Frame wird nun immer zuerst aufgebaut, jede Raster-Neuerstellung landet im Feedback-Log (`NODHeal.Feedback.Grid`) und Click-Casts aus `NODHeal.Bindings` greifen direkt auf den GridFrames inklusive Incoming-Heal-Overlay als Basis für Overheal-Berechnungen. Die Healthbars aktualisieren sich nun sanft (0,1‑s-Ticker), färben bei niedriger Gesundheit gelb/rot, blenden ein halbtransparentes Overheal-Segment ein und kombinieren Blizzard-Incoming-Heals mit dem PredictiveSolver für projizierte Gesamtwerte. Neu: dynamisches Roster-Sorting (`/nodsort group|class|alpha`), automatischer Grid-Rebuild bei Gruppenwechseln und eine weiße Player-Border heben die eigene Einheit hervor.
- In-Game-Optionsfenster (`UI/Options.lua`, Slash `/nodoptions`) erlaubt Grid-Layout-Anpassungen in Echtzeit: Skalierung, Spaltenanzahl, Abstände und Hintergrundtransparenz können per Slider verändert werden, Sortiermodus und Overlay-Anzeigen (Incoming/Overheal) lassen sich über Dropdowns und Checkbuttons toggeln, und die Grid-Position kann gesperrt/entsperrt werden. Alle Werte landen in `NODHeal.Config` und werden als `NODHealDB.config` persistiert; Änderungen triggern sofort einen Grid-Rebuild.
- `Core/HealthSnapshot.lua` nutzt eine abgesicherte `UnitHealth`/`UnitHealthMax`-Abfrage, um ungültige Einheiten still zu verwerfen und Fehler-Spam zu verhindern.
- Click-Cast-System (`UI/ClickCast.lua`) erlaubt Spell-Bindings für Mausbuttons inklusive Alt/Ctrl/Shift-Kombinationen (`/nodbind` zum Anzeigen/Setzen) und setzt die Attribute der eigenen GridFrames sicher (`SecureUnitButtonTemplate`), sodass Casts auch im Kampf funktionieren.
- Spell-Bindings werden beim Login automatisch aus `NODHealDB.bindings` geladen; Classic-Clients erhalten einen Tooltip-Fallback über GridFrames, sodass Click-Casts und Hover-Tooltips ohne `CompactUnitFrame_OnEnter` funktionieren.
- Spell-Binding-UI (`UI/BindingFrame.lua`) stellt ein eigenständiges, verschiebbares Binding-Center bereit: Maus- und Modifier-Kombinationen werden über Dropdowns gewählt, Zauber stammen automatisch aus dem Spellbook und lassen sich per Klick oder Drag & Drop zuweisen; Änderungen werden sofort in `NODHeal.Bindings` gespeichert, jede Zeile besitzt eine Delete-Schaltfläche zum direkten Unbinden und das Fenster merkt sich seine Position (`/nodgui`).

## QA+Autofix 2025-11-05
- Persistente Konfiguration: `Config/Defaults.lua` synchronisiert `NODHeal.Config` und `NODHealDB.config` inklusive Grid-/Debug-Optionen, sodass SavedVariables beim Login vollständig wiederhergestellt werden.
- Zentralisiertes Logging: `Core/Init.lua` stellt `NODHeal.Log/Logf` bereit; UI-Module rufen Ausgaben über diese Gateways ab, wodurch Debug-Spam dem Toggle `NODHeal.Config.debug` folgt.
- Click-Cast & Grid-Härtung: Grid-Frames bewahren Solo/Group/Raid-Einträge, triggern bei zusätzlichen Events (`UNIT_CONNECTION`, `PLAYER_ROLES_ASSIGNED` usw.) einen verzögerten Rebuild und veröffentlichen die Frame-Liste für Overlay/Click-Cast-Fallbacks.
- Overlay-Schutz: Sichere Hooks prüfen die Existenz von `CompactUnitFrame_*`-Funktionen, bevor sie registriert werden; Overlay-Refresh nutzt Guards für ungültige Einheiten und Tooltip-Zugriffe.
- Binding- und Options-UI melden Konflikte/Änderungen über das neue Log-System, speichern Sortiermodi dauerhaft und respektieren Combat-Lockdown durch das bestehende Click-Cast-Queuing.
- Reports: Unter `reports/` liegen aktualisierte Artefakte (`file_inventory.json`, `QA_Report.md`, `change_log.md`, `bindings_snapshot.json`), außerdem dokumentiert `DOCU/Validation/Functional_Readiness.md` den Heal-Ready-Status.

### 2025-11-05 Refresh
- Repository-Inventar und Binding-Snapshot wurden neu generiert; beide Artefakte enthalten jetzt UTC-Zeitstempel sowie vollständige Pfad-/Typ-/Größeninformationen.
- `reports/QA_Report.md` und `DOCU/Validation/Functional_Readiness.md` spiegeln den erneuten Review der Grid-, Overlay- und Click-Cast-Funktionalität wider.
- README/`AGENTS.md` weisen künftig explizit auf die aktualisierten Artefakte hin, um Folge-Sweeps an denselben Quellen auszurichten.

Weitere Implementierungen folgen in iterativen Schritten (DamageForecast, AuraTickScheduler, UI-Overlays usw.). Details zu den geplanten Backend-Funktionen befinden sich im Ordner [`DOCU/`](DOCU/).

## Entwicklung
- Addon-Code vollständig in Lua.
- Fokus auf modulare, testbare Komponenten.
- Performanceorientiertes Design für 40-Spieler-Raids.

## Nächste Schritte
1. Backend-Logik gemäß Dokumentation implementieren.
2. Overlay- und GUI-Schichten ergänzen.
3. Click-Casting-Integration ausarbeiten.

## v1.1 – End-to-End-MVP (Plan)
- [`DOCU/Tasks/Tag 1.md`](DOCU/Tasks/Tag%201.md): (Legacy) Datenpfad schließen (LibHealComm + Blizzard-Fallback, Toggle `/nod healcomm`).
- [`DOCU/Tasks/Tag 2.md`](DOCU/Tasks/Tag%202.md): Timing finalisieren (LatencyTools, CastLandingTime, Freeze-Guard 100–150 ms).
- [`DOCU/Tasks/Tag 3.md`](DOCU/Tasks/Tag%203.md): Minimal-Solver spezifizieren (`ComposeResult`, Clamp-Regeln, Effektiv-HP).
- [`DOCU/Tasks/Tag 4.md`](DOCU/Tasks/Tag%204.md): UI-Overlay (MVP) auf CompactUnitFrame beschreiben.
- [`DOCU/Tasks/Tag 5.md`](DOCU/Tasks/Tag%205.md): Debug-Slash-Kommandos und manuelles Test-Playbook dokumentieren.
- [`DOCU/Tasks/Tag 6.md`](DOCU/Tasks/Tag%206.md): Docs & TOC konsolidieren (README, AGENTS, Lade-Reihenfolge).
- [`DOCU/Tasks/Tag 7.md`](DOCU/Tasks/Tag%207.md): Smoke-Test-Plan und Versionierungsschritte für `v1.1` vorbereiten.

Hinweis: Dieser Abschnitt beschreibt den Arbeitsplan; Implementierung folgt in v1.1.

## Dokumentation
- Projektweite Richtlinien siehe [`AGENTS.md`](AGENTS.md).
- Ausführliche Backend-Referenz unter [`DOCU/NOD_Backend_Funktionsreferenz.md`](DOCU/NOD_Backend_Funktionsreferenz.md).
- Strukturierte Planungs- und Vergleichsdokumente (jetzt im Markdown-Format):
  - [`DOCU/NOD_Systemaufbau_Modulstruktur.md`](DOCU/NOD_Systemaufbau_Modulstruktur.md) – Architektur- und Modulübersicht mit Eingabe/Output-Tabellen.
  - [`DOCU/NOD_Konzept_Funktionsliste.txt`](DOCU/NOD_Konzept_Funktionsliste.txt) – Priorisierte Funktionsliste inkl. Klassifikationen.
  - UI-Frames und Funktionsreferenzen sind zusätzlich als YAML-Segmente unter [`docu/ui_frames/`](docu/ui_frames/) abgelegt und können bei Bedarf über [`scripts/generate_ui_frame_yaml.py`](scripts/generate_ui_frame_yaml.py) erneut aus dem Dump erzeugt werden (`unsorted.yaml` fasst derzeit 421 Rest-Einträge zusammen).
- [`DOCU/NOD_Machbarkeitsanalyse_Technik_MoP.md`](DOCU/NOD_Machbarkeitsanalyse_Technik_MoP.md) – Technische Analyse zu LibHealComm, API-Fallbacks und Raid-Performance.
- [`DOCU/Vergleich_NOD_vs_HealBot_FeatureAnalyse.md`](DOCU/Vergleich_NOD_vs_HealBot_FeatureAnalyse.md) – Gegenüberstellung HealBot vs. NOD.
- [`DOCU/HealingAddons_Funktionsvergleich_NOD_Integration.md`](DOCU/HealingAddons_Funktionsvergleich_NOD_Integration.md) – Feature-Matrix aktueller Healing-Addons.
- [`DOCU/Datei_und_Modulstruktur_NOD-Projektbaum.txt`](DOCU/Datei_und_Modulstruktur_NOD-Projektbaum.txt) – geplanter Projektbaum und Build-Checkliste.
- [`DOCU/NOD_Datenpfad_LHC_API.md`](DOCU/NOD_Datenpfad_LHC_API.md) – Historische Dokumentation des LibHealComm-Datenpfads; aktuelle Umsetzung nutzt ausschließlich die Blizzard-API.
- [`DOCU/NOD_Heal_Pfadstruktur.md`](DOCU/NOD_Heal_Pfadstruktur.md) – Verzeichnisstruktur des Addons mit Änderungsständen und aktuellem Installationspfad.
- [`DOCU/Validation/Final_Audit_Report_v1.md`](DOCU/Validation/Final_Audit_Report_v1.md) – Aktueller CODEx-Abschlussbericht zum Funktionsstand (Subsystem-Matrix, Empfehlungen).

## WoW-API- und Richtlinien-Review (aktueller Stand)
Die folgende Übersicht dokumentiert, welche Funktionen bereits den WoW-Addon-Richtlinien entsprechen und welche noch offene Implementierungsarbeiten oder API-Anbindungen benötigen.

| Moduldatei | Funktion | Bewertung | Bemerkungen |
| --- | --- | --- | --- |
| `Core/Init.lua` | `NODHeal:RegisterModule` | ✅ geeignet | Sauberes Namespacing und Eingabevalidierung. |
| `Core/Init.lua` | `NODHeal:GetModule` | ✅ geeignet | Standardisiertes Lookup ohne Seiteneffekte. |
| `Core/CastTiming.lua` | `CastTiming:Compute` | ⚠️ teilweise geeignet | WoW-APIs korrekt genutzt, GCD noch statisch. |
| `Core/IncomingHealAggregator.lua` | `IncomingHealAggregator:AddHeal` | ✅ geeignet | Erfasst Combat-Log-Heilungen, loggt Quelle/Menge und dispatcht Events. |
| `Core/IncomingHealAggregator.lua` | `IncomingHealAggregator:RemoveHeal` | ✅ geeignet | Entfernt Einträge pro Caster/Spell bei HealStop/HealSucceeded. |
| `Core/IncomingHealAggregator.lua` | `IncomingHealAggregator:GetIncoming` | ✅ geeignet | Summiert Ereignisse API-konform inkl. automatischer Bereinigung. |
| `UI/Init.lua` | `UI:Initialize` | ✅ geeignet | Erstellt Status-Frame, ticker-basierte Aktualisierung inkl. Farbcode. |
| `Core/AuraTickPredictor.lua` | `M.GetHoTTicks` | ✅ geeignet | Liefert HoT-Zeitplan inkl. Tick-Beträgen und Cache je Einheit. |
| `Core/CastLandingTime.lua` | `M.Initialize` | ⚠️ teilweise geeignet | Dispatcher-Hooks vorhanden, warten auf CoreDispatcher. |
| `Core/CastLandingTime.lua` | `M.ComputeLandingTime` | ✅ geeignet | Berechnet `T_land` inkl. Latenz und Queue-Window. |
| `Core/CastLandingTime.lua` | `M.TrackUnitCast` | ⚠️ teilweise geeignet | Ermittelt Cast-Zeitpunkte, benötigt Live-Events zum Feinschliff. |
| `Core/CoreDispatcher.lua` | `M.RegisterHandler` | ✅ geeignet | Hinterlegt Handler inkl. optionaler Throttle. |
| `Core/CoreDispatcher.lua` | `M.Dispatch` | ✅ geeignet | Verteilt Events und respektiert Throttle-Zeitfenster. |
| `Core/CoreDispatcher.lua` | `M.Initialize` | ✅ geeignet | Bootstrappt Events + 0,2‑s-Ticker, berücksichtigt SavedVariables-Toggle. |
| `Core/DamagePrediction.lua` | `M.Estimate` | ✅ geeignet | EMA-basierte CombatLog-Auswertung liefert Rate & Betrag bis Landezeit. |
| `Core/DesyncGuard.lua` | `M.ApplyFreeze` | ✅ geeignet | Sperrt Overlay-Refresh kurz nach Caststart. |
| `Core/DesyncGuard.lua` | `M.ReleaseFreeze` | ✅ geeignet | Hebt Freeze bei Cast-Ende/Cancels zuverlässig auf. |
| `Core/EffectiveHP.lua` | `M.Calculate` | ✅ geeignet | Liest HP & Absorb live, liefert gepufferten EHP-Wert. |
| `Core/HealthSnapshot.lua` | `M.Initialize` | ⚠️ teilweise geeignet | Integriert Invalidate-Handler, wartet auf Dispatcher. |
| `Core/HealthSnapshot.lua` | `M.Capture` | ✅ geeignet | Liest HP/Absorb/Status via WoW-API. |
| `Core/HealthSnapshot.lua` | `M.FlagOfflineState` | ✅ geeignet | Aktualisiert Dead/Offline-Status im Cache. |
| `Core/HealValueEstimator.lua` | `M.Initialize` | ✅ geeignet | Initialisiert Rolling-Cache und Fallback-DB. |
| `Core/HealValueEstimator.lua` | `M.Learn` | ✅ geeignet | Aktualisiert Rolling Average & Varianz. |
| `Core/HealValueEstimator.lua` | `M.Estimate` | ⚠️ teilweise geeignet | Stat-basierte Prognose aktiv, Feintuning offen. |
| `Core/HealValueEstimator.lua` | `M.FetchFallback` | ✅ geeignet | Liefert statische Werte aus Fallback-DB. |
| `Core/IncomingHeals.lua` | `M.Initialize` | ✅ geeignet | Registriert Dispatcher-Hooks und verbindet Aggregator + Blizzard-API. |
| `Core/IncomingHeals.lua` | `M.CollectUntil` | ✅ geeignet | Aggregiert Combat-Log-Heals und Blizzard-API-Werte bis `tLand`. |
| `Core/IncomingHeals.lua` | `M.CollectUntil` | ✅ geeignet | Aggregiert Heals bis `tLand` inkl. Confidence und Fallback. |
| `Core/IncomingHeals.lua` | `M.FetchFallback` | ✅ geeignet | Nutzt Blizzard-API, liefert Amount + Confidence-Level. |
| `Core/LatencyTools.lua` | `M.Initialize` | ✅ geeignet | Initialisiert Latenz- und Queue-Cache. |
| `Core/LatencyTools.lua` | `M.Refresh` | ✅ geeignet | Liest `GetNetStats` & SpellQueueWindow defensiv. |
| `Core/LatencyTools.lua` | `M.GetLatency` | ✅ geeignet | Gibt gecachten Wert zurück. |
| `Core/LatencyTools.lua` | `M.GetSpellQueueWindow` | ✅ geeignet | Exponiert CVar-gestützte Queue-Länge. |
| `Core/PredictiveSolver.lua` | `M.Initialize` | ⚠️ teilweise geeignet | Registriert Abhängigkeiten inkl. Alias-Unterstützung. |
| `Core/PredictiveSolver.lua` | `M.CalculateProjectedHealth` | ✅ geeignet | Kombiniert Snapshot, Schaden, Inc-Heals, HoT-Daten & Heal-Wert. |
| `Core/PredictiveSolver.lua` | `M.ComposeResult` | ✅ geeignet | Liefert Overlay-Werte samt Overheal & Confidence. |

# NOD-Heal (Mists of Pandaria Classic)

NOD-Heal ist ein leistungsorientiertes Healing-Framework für den WoW-Client der Mists-of-Pandaria-Classic-Ära. Dieses Repository enthält die Addon-Struktur, die sukzessive zu einem modularen Vorhersage-Healsystem ausgebaut wird.

## Aktueller Stand
- Basisordnerstruktur gemäß Projektplan erstellt (`NOD_Heal/`).
- Backend-Platzhaltermodule gemäß Funktionsreferenz erstellt (HealthSnapshot, CastLandingTime, IncomingHeals, DamagePrediction, AuraTickPredictor, EffectiveHP, HealValueEstimator, PredictiveSolver, DesyncGuard, LatencyTools, CoreDispatcher).
- TOC-Datei mit Load-Reihenfolge eingerichtet.

Weitere Implementierungen folgen in iterativen Schritten (DamageForecast, AuraTickScheduler, UI-Overlays usw.). Details zu den geplanten Backend-Funktionen befinden sich im Ordner [`DOCU/`](DOCU/).

## Entwicklung
- Addon-Code vollständig in Lua.
- Fokus auf modulare, testbare Komponenten.
- Performanceorientiertes Design für 40-Spieler-Raids.

## Nächste Schritte
1. Backend-Logik gemäß Dokumentation implementieren.
2. Overlay- und GUI-Schichten ergänzen.
3. Click-Casting-Integration ausarbeiten.

## Dokumentation
- Projektweite Richtlinien siehe [`AGENTS.md`](AGENTS.md).
- Ausführliche Backend-Referenz unter [`DOCU/NOD_Backend_Funktionsreferenz.md`](DOCU/NOD_Backend_Funktionsreferenz.md).
- Strukturierte Planungs- und Vergleichsdokumente (jetzt im Markdown-Format):
  - [`DOCU/NOD_Systemaufbau_Modulstruktur.md`](DOCU/NOD_Systemaufbau_Modulstruktur.md) – Architektur- und Modulübersicht mit Eingabe/Output-Tabellen.
  - [`DOCU/NOD_Konzept_Funktionsliste.txt`](DOCU/NOD_Konzept_Funktionsliste.txt) – Priorisierte Funktionsliste inkl. Klassifikationen.
  - [`DOCU/NOD_Machbarkeitsanalyse_Technik_MoP.md`](DOCU/NOD_Machbarkeitsanalyse_Technik_MoP.md) – Technische Analyse zu LibHealComm, API-Fallbacks und Raid-Performance.
  - [`DOCU/Vergleich_NOD_vs_HealBot_FeatureAnalyse.md`](DOCU/Vergleich_NOD_vs_HealBot_FeatureAnalyse.md) – Gegenüberstellung HealBot vs. NOD.
  - [`DOCU/HealingAddons_Funktionsvergleich_NOD_Integration.md`](DOCU/HealingAddons_Funktionsvergleich_NOD_Integration.md) – Feature-Matrix aktueller Healing-Addons.
  - [`DOCU/Datei_und_Modulstruktur_NOD-Projektbaum.txt`](DOCU/Datei_und_Modulstruktur_NOD-Projektbaum.txt) – geplanter Projektbaum und Build-Checkliste.

## WoW-API- und Richtlinien-Review (aktueller Stand)
Die folgende Übersicht dokumentiert, welche Funktionen bereits den WoW-Addon-Richtlinien entsprechen und welche noch offene Implementierungsarbeiten oder API-Anbindungen benötigen.

| Moduldatei | Funktion | Bewertung | Bemerkungen |
| --- | --- | --- | --- |
| `Core/Init.lua` | `NODHeal:RegisterModule` | ✅ geeignet | Sauberes Namespacing und Eingabevalidierung. |
| `Core/Init.lua` | `NODHeal:GetModule` | ✅ geeignet | Standardisiertes Lookup ohne Seiteneffekte. |
| `Core/CastTiming.lua` | `CastTiming:Compute` | ⚠️ teilweise geeignet | WoW-APIs korrekt genutzt, GCD noch statisch. |
| `Core/IncomingHealAggregator.lua` | `IncomingHealAggregator:AddHeal` | ✅ geeignet | Nutzt `GetTime()` und lokale Queues regelkonform. |
| `Core/IncomingHealAggregator.lua` | `IncomingHealAggregator:GetIncoming` | ✅ geeignet | Summiert Ereignisse API-konform, Aufräumlogik fehlt noch. |
| `UI/Init.lua` | `UI:Initialize` | ❌ nicht geeignet | Placeholder ohne Frame-Aufbau. |
| `Core/AuraTickPredictor.lua` | `M.Initialize` | ❌ nicht geeignet | Keine Event-Registrierung. |
| `Core/AuraTickPredictor.lua` | `M.RefreshUnit` | ❌ nicht geeignet | Tick-Scan nicht umgesetzt. |
| `Core/AuraTickPredictor.lua` | `M.GetTicksUntil` | ❌ nicht geeignet | Liefert keine Daten. |
| `Core/CastLandingTime.lua` | `M.Initialize` | ❌ nicht geeignet | Ereignis-Hooks fehlen. |
| `Core/CastLandingTime.lua` | `M.ComputeLandingTime` | ❌ nicht geeignet | Landungsberechnung nicht vorhanden. |
| `Core/CastLandingTime.lua` | `M.TrackUnitCast` | ❌ nicht geeignet | Kein Cast-Tracking. |
| `Core/CoreDispatcher.lua` | `M.Initialize` | ❌ nicht geeignet | Dispatcher-Struktur fehlt. |
| `Core/CoreDispatcher.lua` | `M.RegisterHandler` | ❌ nicht geeignet | Keine Handler-Verwaltung. |
| `Core/CoreDispatcher.lua` | `M.Dispatch` | ❌ nicht geeignet | Dispatch-Logik nicht vorhanden. |
| `Core/CoreDispatcher.lua` | `M.SetThrottle` | ❌ nicht geeignet | Throttling nicht implementiert. |
| `Core/DamagePrediction.lua` | `M.Initialize` | ❌ nicht geeignet | Combat-Log-Hook fehlt. |
| `Core/DamagePrediction.lua` | `M.RecordCombatSample` | ❌ nicht geeignet | EMA-Berechnung fehlt. |
| `Core/DamagePrediction.lua` | `M.CalculateUntil` | ❌ nicht geeignet | Projektion nicht umgesetzt. |
| `Core/DesyncGuard.lua` | `M.Initialize` | ❌ nicht geeignet | Keine Steuerung des Sperrfensters. |
| `Core/DesyncGuard.lua` | `M.OnCastStart` | ❌ nicht geeignet | Latenz-Puffer nicht implementiert. |
| `Core/DesyncGuard.lua` | `M.OnCastResolved` | ❌ nicht geeignet | Ereignisreaktion fehlt. |
| `Core/EffectiveHP.lua` | `M.Initialize` | ❌ nicht geeignet | Absorb-Cache nicht angelegt. |
| `Core/EffectiveHP.lua` | `M.Calculate` | ❌ nicht geeignet | Formel nicht hinterlegt. |
| `Core/EffectiveHP.lua` | `M.UpdateFromUnit` | ❌ nicht geeignet | Kein Zugriff auf `UnitGetTotalAbsorbs`. |
| `Core/HealthSnapshot.lua` | `M.Initialize` | ❌ nicht geeignet | Event-Bindings fehlen. |
| `Core/HealthSnapshot.lua` | `M.Capture` | ❌ nicht geeignet | Snapshot bleibt leer. |
| `Core/HealthSnapshot.lua` | `M.FlagOfflineState` | ❌ nicht geeignet | Offline/Death-Status nicht gepflegt. |
| `Core/HealValueEstimator.lua` | `M.Initialize` | ❌ nicht geeignet | Lernspeicher nicht vorbereitet. |
| `Core/HealValueEstimator.lua` | `M.Learn` | ❌ nicht geeignet | Keine Rolling-Averages. |
| `Core/HealValueEstimator.lua` | `M.Estimate` | ❌ nicht geeignet | Stat-basierte Prognose fehlt. |
| `Core/HealValueEstimator.lua` | `M.FetchFallback` | ❌ nicht geeignet | Fallback-Datenbank ungenutzt. |
| `Core/IncomingHeals.lua` | `M.Initialize` | ❌ nicht geeignet | LibHealComm nicht angebunden. |
| `Core/IncomingHeals.lua` | `M.CollectUntil` | ❌ nicht geeignet | Sammellogik offen. |
| `Core/IncomingHeals.lua` | `M.FetchFallback` | ❌ nicht geeignet | `UnitGetIncomingHeals` nicht verwendet. |
| `Core/LatencyTools.lua` | `M.Initialize` | ❌ nicht geeignet | Latenz-Cache fehlt. |
| `Core/LatencyTools.lua` | `M.Refresh` | ❌ nicht geeignet | Keine Aktualisierung via `GetNetStats`. |
| `Core/LatencyTools.lua` | `M.GetLatency` | ❌ nicht geeignet | Gibt keine Werte zurück. |
| `Core/LatencyTools.lua` | `M.GetSpellQueueWindow` | ❌ nicht geeignet | CVar-Lesen nicht umgesetzt. |
| `Core/PredictiveSolver.lua` | `M.Initialize` | ❌ nicht geeignet | Abhängigkeiten unverdrahtet. |
| `Core/PredictiveSolver.lua` | `M.CalculateProjectedHealth` | ❌ nicht geeignet | Kernformel fehlt. |
| `Core/PredictiveSolver.lua` | `M.ComposeResult` | ❌ nicht geeignet | Ergebnisstruktur fehlt. |

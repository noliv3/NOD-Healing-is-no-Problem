# NOD-Heal (Mists of Pandaria Classic)

NOD-Heal ist ein leistungsorientiertes Healing-Framework für den WoW-Client der Mists-of-Pandaria-Classic-Ära. Dieses Repository enthält die Addon-Struktur, die sukzessive zu einem modularen Vorhersage-Healsystem ausgebaut wird.

## Aktueller Stand
- Basisordnerstruktur gemäß Projektplan erstellt (`NOD_Heal/`).
- Erste Backend-Kernmodule implementiert: HealthSnapshot, CastLandingTime, IncomingHeals, HealValueEstimator, PredictiveSolver und LatencyTools bilden den Datenpfad für Heal-Prognosen.
- Weitere Backend-Platzhalter (DamagePrediction, AuraTickPredictor, EffectiveHP, DesyncGuard, CoreDispatcher) folgen gemäß Funktionsreferenz.
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
| `Core/CastLandingTime.lua` | `M.Initialize` | ⚠️ teilweise geeignet | Dispatcher-Hooks vorhanden, warten auf CoreDispatcher. |
| `Core/CastLandingTime.lua` | `M.ComputeLandingTime` | ✅ geeignet | Berechnet `T_land` inkl. Latenz und Queue-Window. |
| `Core/CastLandingTime.lua` | `M.TrackUnitCast` | ⚠️ teilweise geeignet | Ermittelt Cast-Zeitpunkte, benötigt Live-Events zum Feinschliff. |
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
| `Core/HealthSnapshot.lua` | `M.Initialize` | ⚠️ teilweise geeignet | Integriert Invalidate-Handler, wartet auf Dispatcher. |
| `Core/HealthSnapshot.lua` | `M.Capture` | ✅ geeignet | Liest HP/Absorb/Status via WoW-API. |
| `Core/HealthSnapshot.lua` | `M.FlagOfflineState` | ✅ geeignet | Aktualisiert Dead/Offline-Status im Cache. |
| `Core/HealValueEstimator.lua` | `M.Initialize` | ✅ geeignet | Initialisiert Rolling-Cache und Fallback-DB. |
| `Core/HealValueEstimator.lua` | `M.Learn` | ✅ geeignet | Aktualisiert Rolling Average & Varianz. |
| `Core/HealValueEstimator.lua` | `M.Estimate` | ⚠️ teilweise geeignet | Stat-basierte Prognose aktiv, Feintuning offen. |
| `Core/HealValueEstimator.lua` | `M.FetchFallback` | ✅ geeignet | Liefert statische Werte aus Fallback-DB. |
| `Core/IncomingHeals.lua` | `M.Initialize` | ⚠️ teilweise geeignet | Bindet LibHealComm-Callbacks, benötigt Praxistest. |
| `Core/IncomingHeals.lua` | `M.CollectUntil` | ✅ geeignet | Aggregiert Heals bis `tLand` inkl. Fallback. |
| `Core/IncomingHeals.lua` | `M.FetchFallback` | ✅ geeignet | Nutzt `UnitGetIncomingHeals` als Sicherheitsnetz. |
| `Core/LatencyTools.lua` | `M.Initialize` | ✅ geeignet | Initialisiert Latenz- und Queue-Cache. |
| `Core/LatencyTools.lua` | `M.Refresh` | ✅ geeignet | Liest `GetNetStats` & SpellQueueWindow defensiv. |
| `Core/LatencyTools.lua` | `M.GetLatency` | ✅ geeignet | Gibt gecachten Wert zurück. |
| `Core/LatencyTools.lua` | `M.GetSpellQueueWindow` | ✅ geeignet | Exponiert CVar-gestützte Queue-Länge. |
| `Core/PredictiveSolver.lua` | `M.Initialize` | ⚠️ teilweise geeignet | Registriert Abhängigkeiten inkl. Alias-Unterstützung. |
| `Core/PredictiveSolver.lua` | `M.CalculateProjectedHealth` | ✅ geeignet | Kombiniert Snapshot, Schaden, Inc-Heals & Heal-Wert. |
| `Core/PredictiveSolver.lua` | `M.ComposeResult` | ✅ geeignet | Liefert Overlay-Werte samt Overheal & Confidence. |

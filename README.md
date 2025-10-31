# NOD-Heal (Mists of Pandaria Classic)

NOD-Heal ist ein leistungsorientiertes Healing-Framework für den WoW-Client der Mists-of-Pandaria-Classic-Ära. Dieses Repository enthält die Addon-Struktur, die sukzessive zu einem modularen Vorhersage-Healsystem ausgebaut wird.

## Aktueller Stand
- Basisordnerstruktur gemäß Projektplan erstellt (`NOD_Heal/`).
- Erste Backend-Kernmodule implementiert: HealthSnapshot, CastLandingTime, IncomingHeals, HealValueEstimator, PredictiveSolver und LatencyTools bilden den Datenpfad für Heal-Prognosen.
- DamagePrediction, AuraTickPredictor, IncomingHealAggregator, EffectiveHP, DesyncGuard und CoreDispatcher arbeiten nun mit produktiven WoW-API-Anbindungen und sind an den Solver angebunden.
- TOC-Datei mit Load-Reihenfolge eingerichtet.

### Backend-Stabilisierung
- `Core/IncomingHealAggregator` stellt jetzt eine explizite `CleanExpired`-Routine bereit und bereinigt Queues mit Toleranzpuffer, um veraltete Einträge zuverlässig zu entfernen.
- `Core/IncomingHeals` nutzt dieselbe Ablauf-Logik und bietet ebenfalls `CleanExpired`, inklusive sanfter Fallbacks für fehlende Timestamps.
- `Core/CastLandingTime` normalisiert Castzeiten (Millisekunden/Sekunden) und klemmt Warteschlange sowie Latenz auf sinnvolle Grenzwerte.
- `Core/LatencyTools` aktualisiert Latenz- und Spell-Queue-Werte bei jeder Abfrage und clamped CVars gegen Ausreißer.
- `Core/PredictiveSolver` verhindert negative Beiträge aus Schaden-, Heal- oder HoT-Bausteinen, bevor das projizierte Ergebnis berechnet wird.

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
- [`DOCU/Tasks/Tag 1.md`](DOCU/Tasks/Tag%201.md): Datenpfad schließen (LibHealComm + Blizzard-Fallback, Toggle `/nod healcomm`).
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

## WoW-API- und Richtlinien-Review (aktueller Stand)
Die folgende Übersicht dokumentiert, welche Funktionen bereits den WoW-Addon-Richtlinien entsprechen und welche noch offene Implementierungsarbeiten oder API-Anbindungen benötigen.

| Moduldatei | Funktion | Bewertung | Bemerkungen |
| --- | --- | --- | --- |
| `Core/Init.lua` | `NODHeal:RegisterModule` | ✅ geeignet | Sauberes Namespacing und Eingabevalidierung. |
| `Core/Init.lua` | `NODHeal:GetModule` | ✅ geeignet | Standardisiertes Lookup ohne Seiteneffekte. |
| `Core/CastTiming.lua` | `CastTiming:Compute` | ⚠️ teilweise geeignet | WoW-APIs korrekt genutzt, GCD noch statisch. |
| `Core/IncomingHealAggregator.lua` | `IncomingHealAggregator:AddHeal` | ✅ geeignet | Nimmt GUID-basierte Payloads auf und dispatcht Ereignisse. |
| `Core/IncomingHealAggregator.lua` | `IncomingHealAggregator:GetIncoming` | ✅ geeignet | Summiert Ereignisse API-konform inkl. automatischer Bereinigung. |
| `UI/Init.lua` | `UI:Initialize` | ❌ nicht geeignet | Placeholder ohne Frame-Aufbau. |
| `Core/AuraTickPredictor.lua` | `M.GetHoTTicks` | ✅ geeignet | Liefert HoT-Zeitplan inkl. Tick-Beträgen und Cache je Einheit. |
| `Core/CastLandingTime.lua` | `M.Initialize` | ⚠️ teilweise geeignet | Dispatcher-Hooks vorhanden, warten auf CoreDispatcher. |
| `Core/CastLandingTime.lua` | `M.ComputeLandingTime` | ✅ geeignet | Berechnet `T_land` inkl. Latenz und Queue-Window. |
| `Core/CastLandingTime.lua` | `M.TrackUnitCast` | ⚠️ teilweise geeignet | Ermittelt Cast-Zeitpunkte, benötigt Live-Events zum Feinschliff. |
| `Core/CoreDispatcher.lua` | `M.Initialize` | ✅ geeignet | Erstellt Frame-Hub für Register-/Dispatch-Fluss. |
| `Core/CoreDispatcher.lua` | `M.RegisterHandler` | ✅ geeignet | Hinterlegt Handler inkl. optionaler Throttle. |
| `Core/CoreDispatcher.lua` | `M.Dispatch` | ✅ geeignet | Verteilt Events und respektiert Throttle-Zeitfenster. |
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
| `Core/IncomingHeals.lua` | `M.Initialize` | ⚠️ teilweise geeignet | Bindet LibHealComm-Callbacks, benötigt Praxistest. |
| `Core/IncomingHeals.lua` | `M.CollectUntil` | ✅ geeignet | Aggregiert Heals bis `tLand` inkl. Fallback. |
| `Core/IncomingHeals.lua` | `M.FetchFallback` | ✅ geeignet | Nutzt `UnitGetIncomingHeals` als Sicherheitsnetz. |
| `Core/LatencyTools.lua` | `M.Initialize` | ✅ geeignet | Initialisiert Latenz- und Queue-Cache. |
| `Core/LatencyTools.lua` | `M.Refresh` | ✅ geeignet | Liest `GetNetStats` & SpellQueueWindow defensiv. |
| `Core/LatencyTools.lua` | `M.GetLatency` | ✅ geeignet | Gibt gecachten Wert zurück. |
| `Core/LatencyTools.lua` | `M.GetSpellQueueWindow` | ✅ geeignet | Exponiert CVar-gestützte Queue-Länge. |
| `Core/PredictiveSolver.lua` | `M.Initialize` | ⚠️ teilweise geeignet | Registriert Abhängigkeiten inkl. Alias-Unterstützung. |
| `Core/PredictiveSolver.lua` | `M.CalculateProjectedHealth` | ✅ geeignet | Kombiniert Snapshot, Schaden, Inc-Heals, HoT-Daten & Heal-Wert. |
| `Core/PredictiveSolver.lua` | `M.ComposeResult` | ✅ geeignet | Liefert Overlay-Werte samt Overheal & Confidence. |

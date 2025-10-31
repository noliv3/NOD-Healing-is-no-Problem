# CODEx Final Function Audit – NOD-Heal v1

## Überblick
Dieser Abschlussbericht fasst den aktuellen Funktionsstand des Addons zusammen. Bewertet wurden alle Backend- und Interaktionspfade mit Fokus auf real vorhandene Logik, Verkettungen und dokumentierte Lücken.

## System-Matrix
| Subsystem | Hauptfunktionen | Status | Verbunden mit | Fehlend / unvollständig | Bemerkung |
|-----------|-----------------|--------|---------------|-------------------------|-----------|
| Core-Hub & Solver | `CoreDispatcher:RegisterHandler/Dispatch`, `LatencyTools:GetLatency`, `HealthSnapshot:Capture`, `PredictiveSolver:CalculateProjectedHealth` | ⚙️ | HealthSnapshot, PredictiveSolver, LatencyTools | HealComm-Toggle ohne State, keine zentrale Initialisierung der Module | Event-Hub und Solver rechnen konsistent, benötigen aber Bootstrap & Toggle-State, um LHC/API-Wechsel steuern zu können. |
| Healing-Intake (LHC/API) | `IncomingHeals.scheduleFromTargets`, `IncomingHeals.CleanExpired`, `IncomingHealAggregator.AddHeal/GetIncoming` | ⚙️ | PredictiveSolver, CoreDispatcher | Dispatcher-Bridge für LHC-Stubs, Aggregator-Fallback (0-Werte), Toggle-Statusmeldungen | LHC-Callbacks füllen lokale Queue, jedoch fehlt der Dispatcher-Bindung und echte Umschaltung; API-Fallback liefert nur Rohwerte ohne Confidence-Upgrade. |
| Predictive & Damage Modelle | `HealValueEstimator.Estimate`, `DamagePrediction.Estimate`, `EffectiveHP.Calculate` | ⚙️ | PredictiveSolver, CoreDispatcher | Initialisierung im Spielstart, fehlende Übergabe von Stat-Snapshots | Zahlmodelle liefern stabile Werte, solange `Initialize` manuell getriggert wird; Stats-Anreicherungen bleiben offen. |
| Timing & Desync-Kontrolle | `CastLandingTime.ComputeLandingTime/TrackUnitCast`, `DesyncGuard.IsFrozen`, Queue-Cleanup-Routinen | ⚙️ | CoreDispatcher, LatencyTools, IncomingHeals/Aggregator | Keine kontinuierliche Dispatcher-Aktivierung, Freeze-Fenster fix (0,15 s) | Zeitmodelle funktionieren rechnerisch, sind aber noch nicht adaptiv (keine dynamische Freeze-Konfiguration, kein Health-Check der Dispatcher-Loop). |
| UI & Interaktion | `UI:Initialize` | ❌ | – | Slash-Commands (`/nod healcomm`, `/nod debug`), Overlay-Frames, Statusausgabe | Benutzerinteraktion ist rein dokumentiert; weder Slash-Handler noch Frames existieren derzeit. |

## Gesamtbewertung
**nur Stub-Status** – Zentrale Berechnungs- und Speicherpfade sind vorhanden, jedoch fehlt eine produktive Verkettung der HealComm-Toggles, Dispatcher-Bridges und Benutzerkommandos. Ohne Bootstrap bleiben viele Module inaktiv.

## Priorisierte Handlungsempfehlung
1. CoreDispatcher-/Toggle-Implementierung vervollständigen (State, Register/Deregister, gemeinsame Queue-Brücke zu IncomingHeals/Aggregator).
2. Einheitlichen Initialisierungsfluss beim Addon-Load herstellen, der alle Module (`Initialize`) und den Dispatcher aktiviert.
3. Slash-Command-Handler (`/nod healcomm`, `/nod debug`) und UI-Feedback implementieren, damit Umschaltungen und Debug-Status sichtbar werden.

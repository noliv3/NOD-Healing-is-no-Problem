# Backend Function Audit

## Module & Function Checklist

### Core/CoreDispatcher.lua
- ✅ `Initialize`
- ✅ `RegisterHandler`
- ✅ `Dispatch`
- ✅ `SetThrottle`

### Core/LatencyTools.lua
- ✅ `Initialize`
- ✅ `Refresh`
- ✅ `GetLatency`
- ✅ `GetSpellQueueWindow`

### Core/HealthSnapshot.lua
- ✅ `Initialize`
- ✅ `Capture`
- ✅ `FlagOfflineState`

### Core/EffectiveHP.lua
- ✅ `Calculate`
- ✅ `UpdateFromUnit`

### Core/HealValueEstimator.lua
- ✅ `Initialize`
- ✅ `Learn`
- ✅ `Estimate`
- ✅ `FetchFallback`

### Core/IncomingHeals.lua
- ✅ `Initialize`
- ✅ `CollectUntil`
- ✅ `FetchFallback`
- ✅ `CleanExpired`

### Core/IncomingHealAggregator.lua
- ✅ `Initialize`
- ✅ `AddHeal`
- ✅ `CleanExpired`

### Core/CastLandingTime.lua
- ✅ `Initialize`
- ✅ `TrackUnitCast`
- ✅ `ComputeLandingTime`

### Core/CastTiming.lua (legacy)
- ✅ Stub remains deprecated, no new logic added

### Core/DamagePrediction.lua
- ✅ `Initialize`
- ✅ `RecordCombatSample`
- ✅ `Estimate`

### Core/AuraTickPredictor.lua
- ✅ `Initialize`
- ✅ `RefreshUnit`
- ✅ `GetHoTTicks`

### Core/DesyncGuard.lua
- ✅ `Initialize`
- ✅ `ApplyFreeze`
- ✅ `ReleaseFreeze`

### Core/PredictiveSolver.lua
- ✅ `Initialize`
- ✅ `CalculateProjectedHealth`
- ✅ `ComposeResult`

## Changed Files
- `NOD_Heal/Core/AuraTickPredictor.lua` – Added refresh helper, tightened HoT scheduling, and registered module.
- `NOD_Heal/Core/CastLandingTime.lua` – Reworked interfaces to compute land times with latency/queue inputs and dispatcher wiring.
- `NOD_Heal/Core/CoreDispatcher.lua` – Introduced throttling controls and module registration.
- `NOD_Heal/Core/DamagePrediction.lua` – Added sample tracking, confidence reporting, and module export.
- `NOD_Heal/Core/DesyncGuard.lua` – Routed through dispatcher lookup and module registration.
- `NOD_Heal/Core/EffectiveHP.lua` – Simplified calculation interface, ensured clamps, and registered module.
- `NOD_Heal/Core/HealValueEstimator.lua` – Implemented rolling statistics and standardized estimate outputs.
- `NOD_Heal/Core/HealthSnapshot.lua` – Added dispatcher invalidation hooks and registration.
- `NOD_Heal/Core/IncomingHealAggregator.lua` – Normalized payload handling, dispatcher hookup, and expiry management.
- `NOD_Heal/Core/IncomingHeals.lua` – Synced with aggregator callbacks, provided clean read API, and bounded queues.
- `NOD_Heal/Core/LatencyTools.lua` – Converted metrics to milliseconds and registered module.
- `NOD_Heal/Core/PredictiveSolver.lua` – Reimplemented solver pipeline to assemble projected health outputs.

## Follow-up Notes
- ⚠️ Predictive confidence blending is heuristic; future iterations could incorporate healer-specific reliability metrics when data becomes available.
- ⚠️ HealValueEstimator currently treats stat snapshots generically; integrating spec-specific coefficients would further tighten projections.

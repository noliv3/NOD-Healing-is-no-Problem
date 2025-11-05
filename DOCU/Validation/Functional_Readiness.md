# Functional Readiness Checklist — QA+Autofix 2025-11-05

| Check | Status | Evidence |
| --- | --- | --- |
| Solo/Party/Raid grid visibility | OK | `UI/GridFrame.lua` keeps `player` in `getUnits()` and rebuilds on roster/connect events. |
| Click-cast via SecureActionButtons | OK | `UI/ClickCast.lua` queues OOC attribute writes and registers frames from `GridFrame`. |
| Binding persistence (Set/Get/Delete) | OK | `Config/Defaults.lua` + `Core/Init.lua` load `NODHealDB.bindings`; `UI/Init.lua` slash commands log via gateway. |
| Overlay HP/Incoming/Overheal | OK | `UI/GridFrame.lua` animates health/incoming/overheal textures; `UI/Overlay.lua` guards CompactUnitFrame hooks. |
| SavedVariables wiring (`NODHeal.Config` ↔ `NODHealDB.config`) | OK | `Config/Defaults.lua` exposes `NODHeal.ApplyConfigDefaults()` and merges defaults. |
| Debug log throttle | OK | `Core/Init.lua` `NODHeal.Log/Logf` respect `NODHeal.Config.debug` (force override only for user commands). |
| Ticker frequency ≤ 10 Hz | OK | `UI/GridFrame.lua` ticker uses `0.1` s interval; `Core/CoreDispatcher.lua` ticker unchanged at `0.2` s. |
| Combat lockdown safety | OK | `UI/ClickCast.lua` defers attribute updates when `InCombatLockdown()` returns true. |
| Hook guards | OK | `UI/Overlay.lua` wraps `hooksecurefunc` behind function existence checks. |

## Notes
- Manual smoke test in client still recommended (see `reports/QA_Report.md`).
- Solver/latency tuning remains future scope; not evaluated during this sweep.

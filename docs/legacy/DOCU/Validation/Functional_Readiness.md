# Functional Readiness Checklist — QA+Autofix 2025-11-05 Refresh

| Check | Status | Evidence |
| --- | --- | --- |
| Solo/Party/Raid grid visibility | OK | `UI/GridFrame.lua` keeps `player` present via `getUnits()` and rebuilds after roster/connect events. |
| Click-cast via SecureActionButtons | OK | `UI/ClickCast.lua` defers attribute writes during `InCombatLockdown()` and reapplies on `PLAYER_REGEN_ENABLED`. |
| Binding persistence (Set/Get/Delete) | OK | `Config/Defaults.lua` syncs `NODHeal.Config` ↔ `NODHealDB.config`; `/nodbind` gateway in `UI/Init.lua` lists and updates bindings. |
| Overlay HP/Incoming/Overheal | OK | `UI/GridFrame.lua` renders health/incoming/overheal textures; `UI/Overlay.lua` guards CompactUnitFrame hooks. |
| SavedVariables wiring (`NODHeal.Config` ↔ `NODHealDB.config`) | OK | `Config/Defaults.lua` exposes `NODHeal.ApplyConfigDefaults()` invoked from `Core/Init.lua`. |
| Debug log throttle | OK | `Core/Init.lua` `NODHeal.Log/Logf` respect `NODHeal.Config.debug` with explicit `force` overrides only for user commands. |
| Ticker frequency ≤ 10 Hz | OK | `UI/GridFrame.lua` ticker runs at 0.1 s (10 Hz); `Core/CoreDispatcher.lua` background ticker remains at 0.2 s. |
| Combat lockdown safety | OK | `UI/ClickCast.lua` queues unit/binding changes until combat ends. |
| Hook guards | OK | `UI/Overlay.lua` wraps `hooksecurefunc` calls in `secureHook()` availability checks. |

## Notes
- Artefacts regenerated on 2025-11-05 (UTC); repeat these checks after functional changes to grid, bindings, or overlays.
- Live combat validation remains advised before tagging a release build.

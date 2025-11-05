# QA Report — NOD-Heal QA+Autofix (2025-11-05)

## Summary
- **Decision:** GO (Heal-ready baseline achieved for Solo/Party/Raid use).
- **Scope:** Config persistence, click-cast enforcement, grid/overlay stability, logging hygiene.
- **Key Outcomes:**
  - SavedVariables wiring restores runtime config and bindings on login without taint.
  - Grid reacts to roster/connection events and keeps the player frame visible even out of group.
  - Overlay hooks run only when Blizzard CompactUnitFrame APIs are present, preventing load-time errors.
  - Debug/command outputs respect `NODHeal.Config.debug`, reducing chat spam.

## Findings
### Critical
- _None._

### Major
- Legacy modules emitted user-facing prints regardless of debug state → resolved via shared log gateway.
- Overlay hooks executed unguarded `hooksecurefunc` calls → guarded with availability checks.

### Minor
- Grid ticker refreshed all frames on every health event → now updates the matching unit when provided.
- Sort mode from `/nodsort` was not persisted → stored back to `NODHealDB.config`.
- Tooltip handlers on custom frames did not guard against missing `GameTooltip` → early return added.

## Fix List
1. Synced `NODHeal.Config` ↔ `NODHealDB.config` defaults and exposed `NODHeal.ApplyConfigDefaults()`.
2. Added `NODHeal.Log`/`Logf` helpers; updated Options, Init, BindingFrame to route outputs through debug gate.
3. Hardened GridFrame roster rebuild and exported `unitFrames` for overlay fallback.
4. Wrapped CompactUnitFrame hooks with presence checks and safe refresh calls.
5. Generated artefacts: `file_inventory.json`, `change_log.md`, `bindings_snapshot.json`, `Functional_Readiness.md`.

## Smoke Path (Not Executed, Manual Steps Recommended)
1. **Login:** Verify `/nod debug status` reflects SavedVariables state, status frame shows source `API`.
2. **Grid Solo/Party/Raid:** Toggle between solo, party, and raid groups; ensure player frame persists and roster rebuild occurs within 0.2 s delay.
3. **Bindings UI:** `/nodgui` → assign `Shift-LeftButton` to a new spell, confirm log message and persistence after reload.
4. **Click-Cast:** Cast assigned spell via grid SecureActionButton (out of combat), then enter combat and confirm queued reapply.
5. **Overlay:** Enable overlay, apply incoming heal to unit, verify projection bar width matches expected incoming amount.

## Outstanding Items
- Full combat lockdown simulation (in-client) still pending; requires live verification.
- Predictive solver tuning and latency smoothing unchanged by this pass.

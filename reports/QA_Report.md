# QA Report — NOD-Heal QA+Autofix (2025-11-05 Refresh)

## Summary
- **Decision:** GO (Heal-ready toolchain intact; no blocking regressions detected).
- **Scope:** Repository inventory regeneration, static WoW-API guard review, grid/click-cast/overlay readiness verification, documentation refresh.
- **Key Outcomes:**
  - `reports/file_inventory.json` now reflects the full repository tree (paths, types, byte sizes, mtimes) captured on 2025-11-05.
  - Click-cast SecureActionButtons, SavedVariables wiring, and combat lockdown queues reviewed—no additional fixes required.
  - Overlay and grid logic continue to guard Blizzard API hooks and throttle updates at ≤10 Hz.
  - Documentation (`README.md`, `AGENTS.md`, `DOCU/Validation/Functional_Readiness.md`) updated to mirror the current QA state and artefact locations.

## Findings
### Critical
- _None._

### Major
- _None._

### Minor
- _None._

## Fix List
1. Regenerated repository-wide inventory and bindings snapshot artefacts (`reports/file_inventory.json`, `reports/bindings_snapshot.json`).
2. Revalidated SavedVariables/config bridges and click-cast queue behaviour—no code edits necessary.
3. Refreshed readiness checklist and high-level documentation to capture the 2025-11-05 QA sweep results.

## Smoke Path (Not Executed, Manual Steps Recommended)
1. **Login:** `/nod debug status` to verify SavedVariables hydration; confirm status frame shows source `API`.
2. **Grid Solo/Party/Raid:** Rotate between solo, party, and raid scenarios; ensure `player` frame persists and roster rebuild occurs within the delayed handler.
3. **Bindings UI:** `/nodgui` → assign & remove a binding (e.g., `Shift-LeftButton`), reload UI to confirm persistence and unbind flow.
4. **Click-Cast In Combat:** Apply bindings out of combat, enter combat to confirm deferred attribute updates replay when `PLAYER_REGEN_ENABLED` fires.
5. **Overlay Verification:** Trigger incoming heals on a tracked unit; observe projection lane width and overheal segments relative to `UnitGetIncomingHeals` and solver results.

## Outstanding Items
- Live-client verification of combat lockdown behaviour and overlay visuals still required before release packaging.
- Solver/latency parameter tuning remains out of scope for this refresh.

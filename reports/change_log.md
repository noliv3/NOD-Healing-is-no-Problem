# Change Log — 2025-11-05

## Code Updates
- `Config/Defaults.lua`
  - Synchronised SavedVariables defaults for profile and configuration, exposing `NODHeal.ApplyConfigDefaults` and publishing grid/debug settings to `NODHeal.Config`.
- `Core/Init.lua`
  - Exposed shared logging helpers (`NODHeal.Log`/`Logf`), invoked config bootstrap during addon load and ensured bindings hydrate on `ADDON_LOADED`.
- `UI/Options.lua`
  - Reused central config defaults, channelled UI notifications through the logging gateway and ensured persisted writes mirror SavedVariables.
- `UI/Init.lua`
  - Routed slash command feedback through the logger, persisted `/nodsort` mode and reused the shared log helper.
- `UI/BindingFrame.lua`
  - Replaced direct prints with gated logging for conflicts/unbind actions.
- `UI/GridFrame.lua`
  - Hardened tooltip handling, guarded unit updates, exported the frame list and registered additional roster/connection events for reliable rebuilds.
- `UI/Overlay.lua`
  - Added hook guards before calling `hooksecurefunc` and refreshed CompactUnitFrame updates via safe lookups.

## Documentation & Reports
- `README.md` / `AGENTS.md`
  - Documented the QA+Autofix 2025-11-05 improvements and linked new artefacts.
- `reports/file_inventory.json`
  - Generated repository inventory snapshot (path, type, size, mtime).
- `reports/QA_Report.md`
  - Summarised validation findings and GO/NO-GO decision.
- `reports/bindings_snapshot.json`
  - Captured default click-cast bindings persisted for Heal-ready baseline.
- `DOCU/Validation/Functional_Readiness.md`
  - Recorded checklist outcomes for Solo/Party/Raid grid, bindings, overlays and SavedVariables wiring.

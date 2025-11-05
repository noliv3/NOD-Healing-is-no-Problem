# Change Log — 2025-11-05 Refresh

## Artefact Updates
- `reports/file_inventory.json`
  - Rebuilt repository inventory with UTC timestamps, file types, and byte sizes for every tracked path.
- `reports/bindings_snapshot.json`
  - Captured current default click-cast bindings (Left/Right/Shift-Left) with refreshed ISO timestamp.
- `reports/QA_Report.md`
  - Documented the latest QA+Autofix sweep findings, smoke recommendations, and outstanding work.
- `DOCU/Validation/Functional_Readiness.md`
  - Updated checklist statuses to reflect the November 2025 validation refresh.
- `README.md`
  - Extended QA section with the refreshed artefact summary and verification scope.
- `AGENTS.md`
  - Added guidance for future sweeps referencing the regenerated artefacts and documentation touchpoints.

## Notes
- No Lua source modifications were required for this pass; existing click-cast, grid, and overlay implementations already satisfy the QA+Autofix acceptance criteria.
- Next sweeps should reuse the regenerated inventory/bindings artefacts as baselines and update timestamps when rerun.

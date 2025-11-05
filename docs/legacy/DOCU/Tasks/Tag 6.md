# Tag 6 — Docs & TOC konsolidieren

**Ziel**
`README.md` (Abschnitt v1.1 Plan) und `AGENTS.md` (Review-/Build-Checkliste) präzise ergänzen; TOC-Ladereihenfolge kurz referenzieren.

**Scope**
- `/README.md` (nur Ergänzung)
- `/AGENTS.md` (nur Ergänzung)
- `/NOD_Heal/NOD_Heal.toc` (nur Referenz)

**Teilaufgaben**
- ☐ README: Kurzliste der 7 Tags + Verweise auf `/DOCU/Tasks/*.md`.
- ☐ AGENTS: „Vor Merge prüfen“-Checkliste (Linting, Pfade, Einheiten, ms, keine toten Exporte).
- ☐ TOC: 3–6 Stichpunkte zur Reihenfolge (Config → Core → UI).

**Referenzartefakte**
- README-Zusammenfassung pro Tag (ein Satz, Link, Hinweis „Implementierung folgt in v1.1“).
- Checkliste ≤15 Zeilen, Items: Pfade zu TOC, Einheiten, keine Spekulation, Logs, UI-Hooks, Tests, Abschnittslängen, Abhängigkeiten, Changelog-Hinweis.
- TOC-Stichpunkte aus `NOD_Heal/NOD_Heal.toc`: Reihenfolge (SavedVariables, Core/Init.lua, Core-Module, UI-Init).

**Akzeptanzkriterien**
- Änderungen ≤ 1 Bildschirmseite pro Datei; keine Dopplungen.

**Risiken**
- Divergenzen zu späteren Implementierungen (regelmäßiges Nachziehen nötig).

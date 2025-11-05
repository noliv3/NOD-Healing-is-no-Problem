# Tag 4 — UI-Overlay (MVP) beschreiben

**Ziel**
Ein einziges Prognose-Overlay auf **CompactUnitFrame** (kein eigener Frame-Stack), Modul `UI/Overlay.lua`.

**Scope**
- `NOD_Heal/UI/Init.lua`
- `NOD_Heal/UI/Overlay.lua` (neu zu beschreiben)

**Teilaufgaben**
- ☐ Hook-Punkte (z. B. `CompactUnitFrame_UpdateHealth`).
- ☐ Visual-Element (Text/Bar), Update-Intervall, Throttle.
- ☐ Zustände (kein Target/Offline/Unbekannt).

**Referenzartefakte**
- Hook-Liste: `CompactUnitFrame_UpdateHealth`, `CompactUnitFrame_UpdateStatusText`, `CompactUnitFrame_UpdateAuras` (Lesekontext, nur Health-Hook aktiv nutzen).
- Overlay-API: `Overlay.Initialize(dispatcher, solver)`, `Overlay.Attach(frame)`, `Overlay.Update(frame, unit, data)`, `Overlay.Hide(frame)`.
- Visualbeschreibung: dünner Balken (`StatusBar`) über Health-Bar + `FontString` für `EffectiveHP`. Throttle 0,1 s pro Frame, Respekt `DesyncGuard.IsFrozen(unit)`.
- Zustandsmatrix (Eintrag → Anzeige):
  - `unit=nil` → Overlay verstecken.
  - `offline/dead` → grauer Balken, Text „offline“.
  - `unknown data` → Text „–“, Balken transparent.
  - `confidence=low` → gelber Text, Balken halbtransparent.
  - `confidence=high` → grüner Text, Balken volle Deckkraft.
- Ressourcen-Budget: keine zusätzlichen Frames pro Unit, Re-Use `frame.NODOverlay`.

**Akzeptanzkriterien**
- Klare API des Overlays (Init/Show/Hide/Update) und Zustandsmatrix.

**Risiken**
- Performance bei 40 Frames; Überschreiben durch andere Addons.

# Tag 3 — Minimal-Solver spezifizieren

**Ziel**
`PredictiveSolver.ComposeResult` Spezifikation: `HP_now + IncomingUntilT + OwnHeal - D_pred(=0)` → `EffectiveHP` + Clamp.

**Scope**
- `NOD_Heal/Core/PredictiveSolver.lua`
- `NOD_Heal/Core/HealthSnapshot.lua`
- `NOD_Heal/Core/IncomingHealAggregator.lua`
- `NOD_Heal/Core/HealValueEstimator.lua`
- `NOD_Heal/Core/EffectiveHP.lua`

**Teilaufgaben**
- ☐ Datenabhängigkeiten (Quelle/Einheit/ms).
- ☐ Ausgabeschema (Felder, Typen, Gültigkeit, Timestamps).
- ☐ Clamp-Regeln (min/max, Overheal/Overcap-Umgang).

**Referenzartefakte**
- Input-Tabelle (Feld, Herkunft, Einheit, Aktualität):
  - `hp_now` ← `HealthSnapshot.Capture` (HP, sofort, ≤50 ms alt).
  - `incoming_until` ← `IncomingHealAggregator:GetForWindow` (HP, Fenster `t_land` aus Tag 2).
  - `own_cast` ← `HealValueEstimator:Estimate` (HP, Gültigkeit 8 s, Flag `confidence`).
  - `damage_pred` ← vorerst 0 (Tag 1 Fokus, Damage optional markiert als TODO).
- Formelpfad: `effective = clamp_min_max(hp_now + incoming_until + own_cast, 0, max_hp)` → `EffectiveHP.Calculate` liefert `hp_cap`, `absorb` berücksichtigen.
- Ausgabeschema für `ComposeResult`: Felder `unit`, `t_land`, `effective_hp`, `deficit`, `sources`, `confidence`, `expires_at`.
- Clamp-Regeln: negative Werte auf 0 setzen; Overheal > MaxHP → `deficit=0`, `overcap` Feld setzen.
- Beispiel (Raid-Heal): `hp_now=320k`, `incoming=50k`, `own_cast=80k`, `max=400k` → `effective=400k`, `overcap=50k`, `deficit=0`.

**Akzeptanzkriterien**
- Vollständige Feldliste Input/Output; Beispiel mit realistischen Zahlen.

**Risiken**
- Heuristik im Estimator; fehlende spec-spezifische Koeffizienten.

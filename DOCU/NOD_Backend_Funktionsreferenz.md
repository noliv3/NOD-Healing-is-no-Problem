
# NOD-Heal Backend – Funktionsreferenz (Markdown-Dokumentation)

## Übersicht

Diese Dokumentation beschreibt die vollständige Funktionalität des Backends des NOD-Heal-Systems für World of Warcraft: Mists of Pandaria Classic. Ziel ist es, eine genaue Grundlage für Entwickler zu schaffen, um jeden Funktionsblock modular, wartbar und effizient umzusetzen.

---

## 1. HealthSnapshotManager

**Zweck:** Ermittelt aktuellen HP-Zustand, Tot-/Offline-Status und Absorbs pro Unit.

**Verwendete API:**
- `UnitHealth(unit)`
- `UnitHealthMax(unit)`
- `UnitIsDeadOrGhost(unit)`
- `UnitGetTotalAbsorbs(unit)`

**Ausgabe:** Objekt mit `hp_now`, `hp_max`, `absorbs`, `isDead`, `isOffline`

---

## 2. CastTimingEngine

**Zweck:** Berechnet erwarteten Zauber-Landezeitpunkt (`T_land`).

**Verwendete API:**
- `GetSpellCooldown(spellID)`
- `GetNetStats()`
- `C_CVar.GetCVar("SpellQueueWindow")`

**Berechnung:**
```
T_land = CastTime + GCD + SpellQueueWindow + Latency
```

---

## 3. IncomingHealAggregator

**Zweck:** Aggregiert eingehende Heilungen von allen Quellen bis `T_land`.

**Quellen:**
- LibHealComm (via Events)
- `UnitGetIncomingHeals(unit)` (Fallback)

**Ausgabe:** Liste/Map eingehender Heals mit Zeit und Quelle. Optionales `confidenceFlag`, wenn nur Blizzard-API verwendet wird.

---

## 4. DamageForecastEngine

**Zweck:** Schätzt zu erwartenden Schaden (D_pred) bis `T_land`.

**Quellen:**
- `COMBAT_LOG_EVENT_UNFILTERED` (DPS-Ereignisse)

**Technik:** Exponentieller gleitender Mittelwert (EMA) der letzten X Sekunden pro Unit.

**Berechnung:**
```
D_pred = EMA_DPS * (T_land - now)
```

---

## 5. AuraTickScheduler

**Zweck:** Berechnet bevorstehende HoT-/DoT-Ticks bis `T_land`.

**API:**
- `AuraUtil.FindAuraBy...`
- `UnitAura(unit, index)`

**Output:** Geplante Tick-Termine und ihre Summen.

---

## 6. AbsorbEstimator

**Zweck:** Schätzt tatsächliche Wirksamkeit von Heals unter Einbeziehung von aktiven Schilden.

**Quellen:**
- `UnitGetTotalAbsorbs`

**Formel:** 
```
EHP_now = HP_now + Absorbs_now
```

---

## 7. HealValueResolver

**Zweck:** Ermittelt voraussichtlichen Heilwert pro Spell.

**Methoden:**
- `Learn(new_heal)` → für Rolling Average
- `Estimate(stats)` → krit-/mastery-basiert
- Fallback auf statische Spell-Datenbank

**Optional:** Varianzband für Unsicherheitsanzeige

---

## 8. PredictiveSolver

**Zweck:** Berechnet den projizierten HP-Wert einer Unit bei `T_land`.

**Formel:**
```
HP_proj = clamp(HP_now - D_pred + IncHeals + HealValue, 0, MaxHP)
```

**Ausgabe:** Overlay-Wert für GUI, Overheal-Berechnung, Confidence-Flag

---

## 9. SyncController & DesyncGuard

**Zweck:** Verhindert flackernde Updates durch Event-Latenz.

**Mechanik:**
- CastStart friert Overlay-Updates für 100–150 ms
- CAST_STOP oder SPELL_HEAL triggert Aktualisierung

---

## 10. LatencyCompensator

**Zweck:** Holt aktuelle Latenz und QueueWindow-Wert.

**Quellen:**
- `GetNetStats()`
- `SpellQueueWindow` via CVAR

**Verwendung:** Fließt in `T_land` ein → konservative Projektion

---

## 11. Update-Takt & Ressourcensteuerung

**Mechanik:**
- Throttle: max. 5–10 Updates/sec (0.1–0.2s Intervall)
- Instant-Reaktionen: eigene SPELLCAST-Events, SPELL_HEAL, UnitHealthChange
- HoTs & Aura nur auf eigenen Einheiten

**Ziel:** Volle 40-Spieler-Raid-Kompatibilität

---

## 12. EventHandler & Dispatcher

**Verwendete Events:**
- `UNIT_HEALTH`, `UNIT_AURA`
- `UNIT_SPELLCAST_START/STOP/INTERRUPTED`
- `COMBAT_LOG_EVENT_UNFILTERED`
- `HealComm_HealStarted`, `HealComm_HealUpdated`

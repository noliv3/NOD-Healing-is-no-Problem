# Tag 2 — Timing finalisieren

**Ziel**
Verwendung von `LatencyTools` + `CastLandingTime` und Freeze-Guard dokumentiert (100–150 ms).

**Scope**
- `NOD_Heal/Core/LatencyTools.lua`
- `NOD_Heal/Core/CastLandingTime.lua`
- `NOD_Heal/Core/DesyncGuard.lua`

**Teilaufgaben**
- ☐ Definition `GetLatency()`/`GetSpellQueueWindow()` (Einheiten, Aktualisierungsfrequenz).
- ☐ Landing-Time-Formel mit Komponenten (Cast, Latency, SQW).
- ☐ Freeze-Fenster (Wann/Wie, Aufhebung, Nebenwirkungen).

**Referenzartefakte**
- Tabelle „Timing-Quellen“: Funktion, Einheit, Messintervall, Clamp. Beispiel: `LatencyTools.GetLatency()` → ms, Refresh ≥0,2 s, Clamp 0–4000.
- Formel: `T_land = t_start + cast_s + gcd_s + queue_s + latency_s` (alle Werte ≥0, clamp queue/latency auf ≤1,5 s).
- Beispielrechnung (2,0 s Heal, 80 ms Latency, 200 ms Queue, 1,0 s GCD) → `T_land = t_start + 3,28 s`.
- Freeze-Guard-Matrix: Trigger (`UNIT_SPELLCAST_START`, `CHANNEL_START`), Dauer 0,15 s, Aufhebung bei `STOP|FAILED|SUCCEEDED`, Nebeneffekt „Overlay pausiert“.
- Hinweis: `DesyncGuard.IsFrozen(unit)` muss vom Overlay bei jedem Update geprüft werden.

**Akzeptanzkriterien**
- Eindeutige Formel + Beispielrechnung; klare Reihenfolge der Korrekturen.

**Risiken**
- Addon-Events vs. tatsächliche Server-Ankunft (Edge-Cases).

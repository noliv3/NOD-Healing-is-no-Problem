# Datenpfad Incoming Heals – LibHealComm + Blizzard-Fallback

## Überblick
Dieser Vermerk beschreibt den Datenpfad für eingehende Heilungen in NOD-Heal. Er deckt den LHC-Callback-Strom bis `IncomingHeals` ab, die Übergabe an den `IncomingHealAggregator` sowie den Blizzard-API-Fallback via `UnitGetIncomingHeals`. Alle Beträge werden in Heilpunkten (HP) geführt, Zeitpunkte in Sekunden (s) mit Millisekundenauflösung (ms).

## Datenquellenmatrix
| Feld | Einheit | LibHealComm-Quelle | Aktualisierung | Vertrauenslevel | Blizzard-API-Fallback | Aktualisierung | Vertrauenslevel |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `amount` | HP | `HealComm_Heal*`-Payload (`targets[targetGUID]`) | Sofort bei Event (Start/Update/Delay) | hoch (direkte Casterdaten) | `UnitGetIncomingHeals(unit)` | Alle 0,5 s Cache laut Blizzard-API | mittel (aggregiert, ohne Quellen) |
| `t_land` | s | `endTime` aus Event (`ms` → `s`) | Bei jedem Callback neu gesetzt | hoch (explizit) | `GetTime() + LatencyTools:GetLatency()` | On-Demand-Berechnung | niedrig (heuristisch) |
| `source` | GUID | `casterGUID` | Bei jedem Callback | hoch (eindeutig) | Nicht verfügbar | – | n. a. (Fallback kennzeichnet `fallback`) |
| `spellID` | ID | `spellID` aus Event | Bei jedem Callback | mittel (abhängig von LHC-Spell-DB) | Nicht verfügbar | – | n. a. |
| `overheal` | HP | `overhealing` falls von LHC geliefert, sonst 0 | Bei Stopp/Finalisierung | mittel (optional) | Nicht verfügbar | – | n. a. |
| `confidence` | Qualitativ | Abgeleitet in `IncomingHeals` (`high` bei Queue) | Berechnet bei `CollectUntil` | hoch (Queue-Priorität) | `CollectUntil` setzt `medium` oder `low` je nach Fallback | Bei Fallback-Berechnung | niedrig bis mittel |

## Ereignisfluss (ASCII-Sequenz)
```
HealComm_HealStarted → IncomingHeals.scheduleFromTargets → Queue: payload (amount, source, spellID, t_land)
HealComm_HealUpdated → IncomingHeals.scheduleFromTargets → Queue aktualisieren, t_land normalisieren
HealComm_HealDelayed → IncomingHeals.scheduleFromTargets → Queue aktualisieren, Landing verschieben
HealComm_HealStopped → IncomingHeals.removeEntries → Einträge des Casters entfernen
UNIT_SPELLCAST_STOP → CoreDispatcher → IncomingHeals.CleanExpired → Queue-Bereinigung (LANDING_EPSILON = 50 ms)
IncomingHeals.CollectUntil → Aggregation bis `tLand` → Rückgabe Betrag & Quellen
IncomingHealAggregator.GetIncoming → fragt Summen je Ziel an, nutzt Queue; liefert 0 HP, wenn Queue leer
Solver ruft `IncomingHeals.FetchFallback` nur bei Bedarf → API-Wert ohne Quellenangaben
Fallback-Pfad → IncomingHeals.FetchFallback → UnitGetIncomingHeals → Ergebnis ohne Quellenangaben
```

## Fallback-Priorität & Timeout
1. **Primärquelle:** LibHealComm-Queue-Einträge mit `t_land ≤ Anfragehorizont + 50 ms`. Diese liefern `confidence = high`.
2. **Fallback aktivieren:** Wenn Queue leer ist oder Summe ≤ 0 HP beträgt, wird `UnitGetIncomingHeals(unit)` abgefragt. Das Ergebnis wird mit `confidence = medium`, falls LibHealComm aktiv ist, ansonsten `confidence = low` gekennzeichnet.
3. **Timeout:** Blizzard-API-Werte nutzen einen internen Cache von 0,5 s. Nach diesem Intervall muss erneut abgefragt werden. Queue-Einträge werden über `CleanExpired` bereinigt, wobei `LANDING_EPSILON = 50 ms` (IncomingHeals) und `STALE_PADDING = 250 ms` + `EXPIRY_GRACE = 50 ms` (Aggregator) dafür sorgen, dass verspätete Events kurzzeitig toleriert werden.
4. **Priorisierung:** Sobald wieder LHC-Daten für das Ziel verfügbar sind, überschreiben sie den Fallback vollständig. Eine Rückkehr zu Queue-Daten setzt sofort `confidence = high`.

## Toggle-Spezifikation `/nod healcomm`
| Kommando | Erwartetes Verhalten | Statusabfrage | Fehlerfälle |
| --- | --- | --- | --- |
| `/nod healcomm on` | Registriert LibHealComm-Callbacks (`HealComm_Heal*`), setzt Statusflag `LHC_ACTIVE = true`, aktiviert Queue-Aufbau. | `/nod healcomm status` zeigt `Quelle: LHC` und Timestamp der Aktivierung (`GetTime()` formatiert in ms). | Wenn LibHealComm-Instanz fehlt (`libHandle == nil`): Ausgabe `Fehler: LibHealComm-4.0 nicht geladen`, Flag bleibt `false`. |
| `/nod healcomm off` | Deregistriert Callback-Handles, ruft `IncomingHeals.CleanExpired()` und `IncomingHealAggregator.CleanExpired()` mit `resetStorage`, leert Queue, setzt Statusflag `false`, erzwingt Fallback. | `/nod healcomm status` meldet `Quelle: API-Fallback` + Timestamp der Deaktivierung. | Fehlender Dispatcher → Warnung `Dispatcher nicht verfügbar`, Command beendet trotzdem Queue-Leerung. |
| `/nod healcomm status` | Liest Statusflag + letzte Quelle (`LHC` oder `API-Fallback`), gibt Timestamp der letzten Umschaltung im Format `s.ms` zurück. | – | Wenn Statusflag unbekannt: Warnung `Status nicht initialisiert`, schlägt nicht fehl. |

## Logging-Punkte
- **Info**
  - Bei Addon-Initialisierung: `IncomingHeals.Initialize` meldet gewählte Quelle (`LHC` oder `API-Fallback`).
  - Bei `/nod healcomm on|off`: Eintrag `HealComm-Quelle gewechselt` inklusive Quelle, Zielstatus und Timestamp.
- **Warnung**
  - LHC nicht geladen (`libHandle == nil`) beim Aktivieren: `WARN: LibHealComm nicht verfügbar – Fallback aktiviert`.
  - Queue leer, aber Fallback liefert >0 HP: `WARN: Fallback-Wert ohne Queue` mit Einheit, Betrag in HP und Zeitstempel.
- **Debug**
  - Payload-Mismatch (`HealComm_Heal*` ohne Zielbeträge) → `DEBUG: Unvollständige HealComm-Payload` + Eventname.
  - Prune-Operationen mit Anzahl entfernte Einträge (zur Analyse von Timingabweichungen).

## Verweis auf Module
- `Core/IncomingHeals.lua`: Queue-Aufbau aus LHC, Fallback-Aufruf, Confidence-Ermittlung.
- `Core/IncomingHealAggregator.lua`: CombatLog-Bridge, Expiry-Puffer (`STALE_PADDING = 250 ms`, `EXPIRY_GRACE = 50 ms`).
- `Core/CoreDispatcher.lua`: Liefert `UNIT_SPELLCAST_STOP`-Trigger und CombatLog-Registrierung.

## Offene Punkte
- TODO: Sobald die vollständige LibHealComm-Implementierung eingebunden ist, müssen optionale Felder (`overhealing`, Channel-Flags) konkret verifiziert und ggf. in die Tabelle aufgenommen werden.

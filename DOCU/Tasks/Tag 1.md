# Tag 1 — Datenpfad schließen (LHC + API Fallback)

**Ziel**
LHC-Eingang + Blizzard-API-Fallback in `IncomingHeals`/`IncomingHealAggregator` dokumentiert; Toggle `/nod healcomm on|off` spezifiziert.

**Scope**
Betroffene Module:
- `NOD_Heal/Core/IncomingHeals.lua`
- `NOD_Heal/Core/IncomingHealAggregator.lua`
- `NOD_Heal/Core/CoreDispatcher.lua`
- `LibHealComm-4.0/*` (lesen)

**Teilaufgaben**
- ☐ Datenquellenmatrix (LHC vs. API) als Tabelle erstellen.
- ☐ Ereignisfluss skizzieren: LHC→IncomingHeals→Aggregator (Zeitfenster, Payload, Expiry).
- ☐ Toggle-Spezifikation `/nod healcomm on|off`: erwartetes Verhalten, Statusabfrage, Fehlerfälle.
- ☐ Logging-Punkte definieren (Info/Warn bei Quelle/Wechsel).

**Referenzartefakte**
- Tabelle „LHC vs. Blizzard-API“ mit Spalten: Feld, Quelle, Aktualisierung, Vertrauenslevel. Beispielwerte:
  - `amount` → LHC: `HealComm_Heal*`-Payload (sofort); API: `UnitGetIncomingHeals` (0,5 s Cache).
  - `t_land` → LHC: `endTime` (ms → s normalisieren); API: heuristisch `GetTime()+LatencyTools`.
  - `source` → LHC: `casterGUID`; API: nicht verfügbar → als `fallback` markieren.
- ASCII-Sequenz (Event → Modul → Aktion):
  1. `HealComm_HealStarted` → `IncomingHeals.scheduleFromTargets` → Queue-Eintrag `t_land`.
  2. `HealComm_HealStopped` → `IncomingHeals.removeEntries` → Purge.
  3. `UNIT_SPELLCAST_STOP` → `CoreDispatcher` → `IncomingHeals.CleanExpired` → Übergabe an Aggregator.
  4. Aggregator ruft `CollectUntil` → nutzt Queue, sonst API-Fallback.
- Toggle-Verhalten:
  - `/nod healcomm on`: Registriert LibHealComm-Callbacks, setzt Statusflag `LHC_ACTIVE=true`.
  - `/nod healcomm off`: Deregistriert Callbacks, leert Queue, aktiviert permanenten API-Fallback.
  - `/nod healcomm status`: Gibt Quelle (`LHC`, `API-Fallback`) + Timestamp der letzten Umschaltung zurück.
  - Fehlerfälle: Fehlende LibHealComm-Instanz → Warnmeldung, Kommando schlägt mit Fehlertext fehl.
- Logging-Empfehlung: Info bei Initialisierung/Umschaltung, Warnung wenn Queue leer aber Fallback liefert >0, Debug für Payload-Mismatch.

**Akzeptanzkriterien**
- Dokument enthaltende Sequenzgrafik (ASCII oder Liste) und I/O-Tabelle (Felder, Einheiten, ms).
- Klarer Fallback-Pfad beschrieben, inkl. Priorität und Timeout.

**Risiken**
- Unvollständige LHC-Spell-DB; divergierende Payload-Schemas.

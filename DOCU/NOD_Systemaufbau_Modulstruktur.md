# Systemaufbau und Modulstruktur – NOD-Heal

## Gesamtübersicht
- Architektur folgt einem klar getrennten Backend-Kern mit optionalen UI-Modulen.
- Kommunikationsdrehscheibe ist `NODHeal.Core`, das Ereignisse, Zeitgeber und Datenzustände verteilt.
- Ziel: geringe Kopplung, schnelle Testbarkeit und einfache Austauschbarkeit einzelner Komponenten.

## Modulübersicht

### Modul: HealthSnapshot
- **Eingaben:** `UnitHealth`, `UnitHealthMax`, `UnitGetTotalAbsorbs`, `UnitIsDeadOrGhost`.
- **Ausgaben:** Effektive HP (`hp_now`, `hp_max`, `absorb_now`), Zustandsflags (tot, offline, in_range).
- **Trigger:** `UNIT_HEALTH`, `UNIT_MAXHEALTH`, `UNIT_ABSORB_AMOUNT_CHANGED`, `GROUP_ROSTER_UPDATE`.
- **Notizen:** Liefert konsolidierten Status als Grundlage für alle Solver-Berechnungen.

### Modul: CastTiming
- **Eingaben:** Zauber-ID, `UnitCastingInfo`, `UnitChannelInfo`, Haste, `GetNetStats`, `C_Spell.GetSpellQueueWindow`.
- **Ausgaben:** `t_start`, `t_end`, `t_land`, erwartete Recast-Werte.
- **Trigger:** `UNIT_SPELLCAST_START`, `UNIT_SPELLCAST_CHANNEL_START`, `UNIT_SPELLCAST_DELAYED`, `UNIT_SPELLCAST_STOP`.
- **Notizen:** Berücksichtigt SpellQueueWindow und Ping; liefert Timer für Aggregator und Solver.

### Modul: IncomingHealAggregator
- **Eingaben:** Eigene Castdaten, LibHealComm-Events (`HealComm_HealStarted`, `HealComm_HealUpdated`, `HealComm_HealStopped`), `UnitGetIncomingHeals`.
- **Ausgaben:** Liste aggregierter Heals pro Ziel inkl. Quelle, Wert, Landed-Zeit.
- **Trigger:** Cast-Events, Combat-Log, periodischer Cleanup-Timer.
- **Notizen:** Priorisiert LHC-Daten, markiert Einträge aus Blizzard-API als unsicher, entfernt Beiträge bei Abbruch.

### Modul: DamageForecast
- **Eingaben:** `COMBAT_LOG_EVENT_UNFILTERED`, Tick-Informationen, historische Schadenssamples.
- **Ausgaben:** `d_pred` (pro Ziel) über gleitende Fensterlänge, Varianzschätzung.
- **Trigger:** Combat-Log, 0.2 s Throttle.
- **Notizen:** Nutzt exponentiellen Gleitmittelwert; optional abschaltbar für Minimalprofil.

### Modul: TickScheduler
- **Eingaben:** Aura-Scans (`UnitAura`), HoT- und DoT-Metadaten.
- **Ausgaben:** Liste geplanter Tick-Ereignisse bis `t_land`.
- **Trigger:** `UNIT_AURA`, Cast-Start eigener HoTs, periodischer Refresh.
- **Notizen:** Wird nur für Ziele mit aktiven HoTs/DoTs ausgeführt; Heuristiken vermeiden teure Vollscans.

### Modul: HealValueLearning
- **Eingaben:** Eigene `SPELL_HEAL`-Events, LibHealComm-Werte, Ausrüstungssnapshots.
- **Ausgaben:** Rolling Mean, Min/Max und Standardabweichung pro Spell.
- **Trigger:** Eigene Heals landen oder kritische Treffer.
- **Notizen:** Dient als Fallback bei fehlenden Spell-Daten; liefert Konfidenz für Overheal-Bewertung.

### Modul: PredictiveSolver
- **Eingaben:** HealthSnapshot, IncomingHealAggregator, DamageForecast, HealValueLearning, TickScheduler.
- **Ausgaben:** `hp_projected`, Overheal-Prozent, Unsicherheitsflag.
- **Trigger:** CastTiming-Updates, neue Heals/Schadenswerte, `UNIT_HEALTH`-Events.
- **Notizen:** Formel: `hp_projected = clamp(hp_now - d_pred + heals_until_t + heal_value, 0, hp_max)`.

### Modul: OverlayRenderer
- **Eingaben:** `hp_now`, `hp_projected`, Overheal-Prozent, Datenquelle (sicher/unsicher).
- **Ausgaben:** UI-Segmente für aktuelle Frames (Standard UI oder eigene Frames).
- **Trigger:** Ergebnisse des PredictiveSolver, Frame-Layout-Events.
- **Notizen:** Zeichnet Precast-Layer als additive Balken; Transparenz signalisiert Prognosevertrauen.

### Modul: ClickCastBindings (später)
- **Eingaben:** Benutzerprofil, Keybinding-API, Spell-ID.
- **Ausgaben:** Gesicherte Bindings, OnClick-Handler.
- **Trigger:** GUI-Konfiguration, Profilwechsel.
- **Notizen:** Separates UI-Modul, nutzt Backend nur für Reichweiten-/Mana-Checks.

### Modul: Configuration & Persistence
- **Eingaben:** SavedVariables, Default-Profile aus `Config/Defaults.lua`.
- **Ausgaben:** Laufzeitoptionen (Throttles, Anzeigeoptionen, Feature-Toggles).
- **Trigger:** ADDON_LOADED, Profilwechsel, GUI-Bestätigungen.
- **Notizen:** Bietet Flags zum Aktivieren/Deaktivieren rechenintensiver Blöcke (DamageForecast, TickScheduler).

## Eventfluss
1. **Cast-Start** löst CastTiming und Aggregator aus.
2. **Aggregator** aktualisiert Heillisten und benachrichtigt PredictiveSolver.
3. **DamageForecast** liefert fortlaufend D_pred, das vom Solver konsumiert wird.
4. **PredictiveSolver** berechnet `hp_projected` und reicht Resultate an OverlayRenderer weiter.
5. **OverlayRenderer** zeichnet Precast-Layer, markiert unsichere Anteile und Overheal-Schwellen.
6. **Event Hooks** entfernen Prognosen bei Cast-Abbruch oder tatsächlicher Heilung.

## Erweiterungspunkte
- Zusätzliche Datenquellen (z. B. Bossmod-APIs) können in DamageForecast einspeisen.
- Machine-Learning-Ansätze für fremde Heiler lassen sich als eigenständiges Modul zwischen Aggregator und Solver schalten.
- UI-Frameworks Dritter (Grid2, VuhDo) können nur das Overlay-Modul nutzen, wenn Schnittstellen bereitstehen.
- Performance-Modus deaktiviert rechenintensive Module automatisch in Großschlachtzügen.

## Testing-Empfehlungen
- Modultests für Solver-Formeln und Aggregator-Konsistenz mit Mock-Ereignissen.
- Profiltests mit 40 simulierten Einheiten zur Sicherstellung konstanter Framezeiten.
- Latenz-Simulation (z. B. künstliche Verzögerung der Healevents) zur Validierung des Desync-Guards.

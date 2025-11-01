# Machbarkeitsanalyse – NOD-Heal (MoP Classic)

## Projektziele
- Stabiler Heilerrahmen für Mists of Pandaria Classic mit sauberer Precast-Projektion.
- Zusammenführung von aktuellen Lebenspunkten, erwarteten Schadensspitzen und eingehenden Heilungen.
- Overlay-basierte Darstellung ohne Überschreiben des Server-HP-Wertes.
- Performance-Optimierung für 40-Spieler-Raids und schwankende Netzwerkbedingungen.

## Datenquellen für Heal-Projektion

### Blizzard-API (UnitGetIncomingHeals)
- Liefert nur direkte Heilungen; HoTs und Kanalisierungen fehlen in Classic-Clients.
- Werte schwanken stark und können im Fehlerfall Null oder unrealistische Summen liefern.
- Geeignet als letzte Rückfallebene, wenn keine LibHealComm-Daten vorliegen.

### LibHealComm-4.0
- Etablierte Kommunikationsebene für Heilvorhersagen zwischen Addons.
- Nutzt Spell-Datenbanken, Talente und Buffs, um präzise Heilmengen zu schätzen.
- Benötigt Pflege für neue Zauber und Rangänderungen in MoP Classic.
- Abdeckung nur garantiert, wenn der Großteil der Heiler die Library geladen hat.

### Hybrid-Ansatz
- Priorität: LHC-Daten → Blizzard-API → heuristische Abschätzung aus Combat-Logs.
- Markiere unsichere Quellen visuell (z. B. geringere Overlay-Deckkraft).
- Optionale Lernlogik: beobachte fremde Heiler, um fehlende Werte zu interpolieren.

## Raid-Tauglichkeit und Datenvollständigkeit
- Ohne gemeinsame Library bleiben fremde Heals unsichtbar; reine API ist unzureichend.
- UI sollte Hinweis geben, wenn Prognose nur eigene Daten nutzt.
- Kombination aus Addon-Kommunikation und Fallback-API minimiert blinde Flecken.
- Cluster-basierte Abschätzungen (z. B. Durchschnittswerte pro Heiler) sind als spätere Erweiterung einplanbar.

## Performance im 40-Spieler-Raid
- Verwende throttled Updates (≈5–10 Hz) statt jedes Combat-Log-Event zu verarbeiten.
- Aktualisiere Projektionen ereignisgetrieben bei Cast-Start, Cast-Ende und eingetroffenen Heals.
- Scanne Auren selektiv: nur Spieler mit relevanten HoTs/DoTs analysieren.
- Halte Render-Overhead niedrig (einfaches Overlay, keine animierten Texturen).

## Latenz- und Timing-Handling
- Berechne T_land = Castzeit + GCD-Rest + SpellQueueWindow + aktuelle Latenz.
- Verwende GetNetStats() zur Anpassung der Vorhersage bei schlechter Verbindung.
- Implementiere einen kurzen Desync-Guard (≈0,1 s), um Flackern bei Caststart zu verhindern.
- Passe Projektion sofort an bei UNIT_SPELLCAST_STOP/INTERRUPTED und Combat-Log-Healevents.

## Kernfunktionen für die Umsetzung
- **Server Health Snapshot**: UnitHealth/UnitHealthMax, Absorbs und Dead/Ghost-Status in einem effektiven HP-Wert bündeln.
- **Precast Engine**: Laufzeiten der eigenen Zauber inkl. Haste-Modifier und Queue-Fenster bestimmen.
- **Incoming Heal Aggregator**: Eigene Casts, LibHealComm-Events und API-Werte bis T_land aufsummieren.
- **Damage Forecast**: Exponentieller Gleitmittelwert der letzten Sekunden, um D_pred bis T_land zu schätzen.
- **HoT/DoT Scheduler**: Optional ganze Ticks bis zur Landezeit berücksichtigen, sofern API-Infos verfügbar sind.
- **HealValue Learning**: Rollierenden Mittelwert pro Spell pflegen; statische Tabellen als Fallback laden.
- **Desync-Guard**: Kurze Update-Sperre bei Castbeginn, um Netzwerklatenz auszugleichen.
- **Event Hooks**: Einheitliche Handler für Cast-Abbrüche, Todesfälle, Max-HP-Änderungen und Combat-Log.

## Fazit
- Ein präzises Heal-Overlay ist in MoP Classic realisierbar, wenn LibHealComm als Primärquelle dient.
- Blizzard-API bleibt ein nützliches Sicherheitsnetz, ersetzt jedoch keine Addon-Kommunikation.
- Mit modularen Komponenten und gezieltem Throttling bleibt das System performant in 40er-Raids.
- Restunsicherheiten (Krit-Heals, plötzlicher Schaden) sind akzeptabel und können durch visuelles Feedback kenntlich gemacht werden.

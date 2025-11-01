# Tag 1 – GridFrame Feedback Report

## Purpose
Dieses Protokoll sammelt die Feedback-Einträge des GridFrame-Kerns während der Tag-1-Überarbeitung. Die Lua-Implementierung hinterlegt alle Meldungen in `NODHeal.Feedback.Grid`, sodass das Addon jederzeit nachvollziehen kann, wann der Container erstellt und welche Einheiten gerendert wurden.

## /reload (Solo)
| Schritt | Meldung |
| --- | --- |
| 1 | Rebuilding Grid Layout |
| 2 | Container frame created |
| 3 | Frame 1 assigned to unit 'player' |

## Party-Beispiel (Player + 2 Mitglieder)
| Schritt | Meldung |
| --- | --- |
| 1 | Rebuilding Grid Layout |
| 2 | Container frame created *(nur beim ersten Aufbau)* |
| 3 | Frame 1 assigned to unit 'player' |
| 4 | Frame 2 assigned to unit 'party1' |
| 5 | Frame 3 assigned to unit 'party2' |

## Raid-Beispiel (Player + 4 Mitglieder)
| Schritt | Meldung |
| --- | --- |
| 1 | Rebuilding Grid Layout |
| 2 | Container frame created *(nur beim ersten Aufbau)* |
| 3 | Frame 1 assigned to unit 'player' |
| 4 | Frame 2 assigned to unit 'raid1' |
| 5 | Frame 3 assigned to unit 'raid2' |
| 6 | Frame 4 assigned to unit 'raid3' |
| 7 | Frame 5 assigned to unit 'raid4' |
| 8 | Frame 6 assigned to unit 'raid5' |

> **Hinweis:** Beim Raid-Szenario bleibt der dedizierte `player`-Frame erhalten, auch wenn der Spieler zusätzlich unter `raidX` geführt wird. Damit erfüllt das Grid die Solo-Sichtbarkeit und liefert vollständige Feedback-Einträge für alle erzeugten Frames.

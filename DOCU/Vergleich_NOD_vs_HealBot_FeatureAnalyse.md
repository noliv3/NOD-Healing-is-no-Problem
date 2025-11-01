# Vergleich: HealBot vs. NOD-Heal-System (MoP Classic)

| Aspekt | HealBot (Status quo) | NOD-Heal (geplant) |
| --- | --- | --- |
| Eingehende Heilung | Nutzt LibHealComm für präzise Werte, zeigt Heals/Schilde auf Frames; Heiler ohne LHC bleiben unsichtbar, API-Fallback selten genutzt. | Hybrid-Aggregator priorisiert LHC, fällt auf Blizzard-API zurück und kennzeichnet Unsicherheit; perspektivisch heuristische Schätzungen für Non-LHC-Heiler. |
| Healvorhersage & Overheal | Zeigt klassische Incoming-Heal-Balken bis 100 %; kein Predictive Solver, Overheal-Bewertungen historisch nur rudimentär. | Precast-Solver kombiniert HP, eingehende Heals, Damage-Forecast und HealValue → Overlay visualisiert erwarteten HP-Stand und Overheal-Schwellen. |
| Schadensprognose | Keine integrierte Schadenstrendanalyse; Heiler beurteilen Gefahr manuell (optionale Fremd-Plugins). | Damage-Forecast berechnet D_pred aus gleitendem DPS-Mittel; optionale Deaktivierung für Minimalprofil. |
| Heal-Wert-Ermittlung | Vertraut auf LibHealComm-Formeln; keine Lernlogik, Updates nötig bei neuen Zaubern. | Rollierender Mittelwert eigener Heals, Varianzschätzung und Fallback-Tabellen; beobachtet fremde Heiler optional über Combat-Log. |
| Latenz-Handling | Sofortige Updates ohne Glättung; potenzielles Flackern bei zeitverzögerten Events. | Desync-Guard friert Overlay kurz ein, SpellQueueWindow und Ping fließen in T_land ein. |
| UI-Flexibilität | Umfangreiche Rahmenkonfiguration, integriertes Buff-/Debuff-Management, viele ClickCast-Optionen, zahlreiche Skins. | Fokus auf klare Precast-Darstellung; modulare Erweiterung für ClickCast, Debuffs und Layout-Profile geplant. |
| Performance | Bewährt in 40er-Raids, aber funktionsreich; Performance-Plugins und Optionen vorhanden. | Schlanke Module mit Throttling, optionale Abschaltung rechenintensiver Features, Profiltests für 40 Spieler vorgesehen. |
| Architektur | Historisch gewachsener Monolith mit Plugin-Support; Kernänderungen komplex. | Streng modulare Backend-Blöcke (Snapshot, Aggregator, Solver, Renderer) und austauschbare UI-Layer. |
| Abbruch/Overheal-Hinweise | Overheal-Abort-Button verfügbar; heuristische Schwelle pro Benutzer konfigurierbar. | Overlay-basierte Warnung bei erwarteter Überheilung, optionaler Cast-Abbruch-Hinweis basierend auf Solver-Ergebnis. |
| Zukunftssicherheit | Reift seit Jahren, stabile Nutzerbasis, regelmäßige Wartung. | Neuentwicklung mit Fokus auf technische Innovation; offen für Integration mit Dritt-Frames und zukünftigen Erweiterungen. |

## Kernaussagen
- HealBot bleibt ein vollwertiges Frame-Addon; NOD konzentriert sich auf den präziseren Precast-Stack.
- Kombination aus Damage-Forecast, Lernlogik und Desync-Guard verschafft NOD ein Alleinstellungsmerkmal.
- Um Akzeptanz zu erreichen, müssen Komfortfunktionen (ClickCast, Debuffs) zeitnah nachgeliefert werden, auch wenn der Fokus auf dem Solver liegt.

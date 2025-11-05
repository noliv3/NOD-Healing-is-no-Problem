# Healing-Addons – Funktionsvergleich für NOD-Integration (MoP Classic)

| Funktion | Referenz-Addons | Technische Umsetzung | Empfehlung für NOD |
| --- | --- | --- | --- |
| Eingehende Heilungsprognose | VuhDo, Grid2, LunaUnitFrames, Plexus (Plugin), HealBot | LibHealComm-Integration dominiert; Blizzard-API dient nur als Fallback. Abgebrochene Casts werden durch LHC sauber entfernt. API-Werte sind in Classic unvollständig (keine HoTs, falsche Summen). | LHC als Primärquelle einplanen, Blizzard-API als Notnagel aktivieren und unsichere Beiträge kennzeichnen. |
| HoT- und Absorb-Anzeigen | VuhDo, Grid2/Plexus, HealBot, Aptechka | Mehrere HoT-Slots pro Frame, farbige Segmente oder Icons; Absorbs erscheinen als zusätzlicher Balken. | Mindestens eigene HoTs/Schilde darstellen, modulare Slot-Konfiguration für späteres UI-Upgrade vorsehen. |
| Debuff-Icons & Dispelfilter | Grid2, VuhDo, Aptechka, LunaUnitFrames | Ecken-Icons, Rahmenfärbung, Prioritäts- und Blacklist-Systeme; Fokus auf dispellbare Effekte. | Markanter Debuff-Indikator mit Dispel-Filter und Prioritätssystem; optional Blacklist für triviale Effekte. |
| Aggro- und Bedrohungswarnung | Plexus, VuhDo, Grid2, HealBot | Rote Rahmen, Glow-Effekte, Bedrohungsbalken; Tanks erhalten Sondermarkierungen. | Einfache Aggro-Markierung verpflichtend, Tank-Status hervorheben; geringe Implementierungskosten. |
| Smart-AoE-Heal Cluster | VuhDo, Aptechka | Distanzbasierte Cluster-Berechnung, Hervorhebung der betroffenen Frames; optional Anzeige der Trefferanzahl. | Mittel- bis langfristiges Ziel; on-demand Berechnung zum Schutz der Performance vorsehen. |
| Click-Heilung & Mouseover-Bindings | VuhDo, HealBot, Grid2 + Clique, Plexus + Plugins | Umfangreiche Maus+Mod-Kombinationen, optional SmartCast (Rez out of combat). | Eigenes ClickCast-Modul planen, inklusive Tastatur-Mouseover-Unterstützung und einfachem Setup. |
| Profil-Umschaltung & Skalierung | Aptechka, Grid2, VuhDo | Automatisches Layout-Switching je nach Raidgröße, skalierende Framegrößen. | Profil-/Layout-Profile für 5/10/25/40 Spieler vorbereiten; Automatik später ergänzen. |
| Performance & Ressourcen | sRaidFrames, Grid2, Aptechka | Lightweight-Kerne, modulare Indikatoren, Update-Throttling; teilweise Feature-Drossel in 40er-Raids. | Strikte Modularität und Throttles übernehmen, Heavy-Features abschaltbar gestalten. |
| Precast-/Overheal-System | HealBot (Overheal Abort), Grid2-Plugin (veraltet) | Overheal-Schwelle löst Abbruch-Hinweis aus; klassische Addons zeigen nur Heillayer bis 100 %. | Kernfeature für NOD: Precast-Overlay mit Overheal-Warnung, optional Abbruchhinweis ähnlich HealBot. |
| Frame-Overlays & Castbars | Aptechka, LunaUnitFrames, VuhDo | Reichweitenfading, Castbars auf Frames, Spell-Trace für AoE-Heals, gegnerische Cast-Warnungen. | Pflicht: Reichweite/Tot/Offline-Anzeigen. Optional: Spell-Trace und Gegner-Cast-Alerts als spätere Innovation. |

## Erkenntnisse
- Erfolgreiche Addons kombinieren LibHealComm mit performanten UI-Elementen.
- Modularität und Throttling sind entscheidend für 40-Spieler-Raids.
- NOD kann sich durch präzisere Precast-Projektion und Damage-Forecast differenzieren, sollte aber Komfortfunktionen (ClickCast, Debuffs, Aggro) zeitnah liefern.

# NOD-Heal (Mists of Pandaria Classic)

NOD-Heal ist ein leistungsorientiertes Healing-Framework für den WoW-Client der Mists-of-Pandaria-Classic-Ära. Dieses Repository enthält die Addon-Struktur, die sukzessive zu einem modularen Vorhersage-Healsystem ausgebaut wird.

## Aktueller Stand
- Basisordnerstruktur gemäß Projektplan erstellt (`NOD_Heal/`).
- Platzhalter für Kernmodule des Backends angelegt (HealthSnapshot, CastTiming, IncomingHealAggregator, PredictiveSolver).
- TOC-Datei mit Load-Reihenfolge eingerichtet.

Weitere Implementierungen folgen in iterativen Schritten (DamageForecast, AuraTickScheduler, UI-Overlays usw.). Details zu den geplanten Backend-Funktionen befinden sich im Ordner [`DOCU/`](DOCU/).

## Entwicklung
- Addon-Code vollständig in Lua.
- Fokus auf modulare, testbare Komponenten.
- Performanceorientiertes Design für 40-Spieler-Raids.

## Nächste Schritte
1. Backend-Logik gemäß Dokumentation implementieren.
2. Overlay- und GUI-Schichten ergänzen.
3. Click-Casting-Integration ausarbeiten.

## Dokumentation
- Projektweite Richtlinien siehe [`AGENTS.md`](AGENTS.md).
- Ausführliche Backend-Referenz unter [`DOCU/NOD_Backend_Funktionsreferenz.md`](DOCU/NOD_Backend_Funktionsreferenz.md).
- Strukturierte Planungs- und Vergleichsdokumente (umbenannt für Klarheit):
  - [`DOCU/NOD_Systemaufbau_Modulstruktur.docx`](DOCU/NOD_Systemaufbau_Modulstruktur.docx) – Architektur- und Modulübersicht.
  - [`DOCU/NOD_Konzept_Funktionsliste.txt`](DOCU/NOD_Konzept_Funktionsliste.txt) – Priorisierte Funktionsliste inkl. Klassifikationen.
  - [`DOCU/NOD_Machbarkeitsanalyse_Technik_MoP.docx`](DOCU/NOD_Machbarkeitsanalyse_Technik_MoP.docx) – Technische Analyse zu LibHealComm, API-Fallbacks und Raid-Performance.
  - [`DOCU/Vergleich_NOD_vs_HealBot_FeatureAnalyse.docx`](DOCU/Vergleich_NOD_vs_HealBot_FeatureAnalyse.docx) – Gegenüberstellung HealBot vs. NOD.
  - [`DOCU/HealingAddons_Funktionsvergleich_NOD_Integration.docx`](DOCU/HealingAddons_Funktionsvergleich_NOD_Integration.docx) – Feature-Matrix aktueller Healing-Addons.
  - [`DOCU/Datei_und_Modulstruktur_NOD-Projektbaum.txt`](DOCU/Datei_und_Modulstruktur_NOD-Projektbaum.txt) – geplanter Projektbaum und Build-Checkliste.

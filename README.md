# NOD-Heal (MoP Classic)
Leichtgewichtiges Healing-Framework für **World of Warcraft – Mists of Pandaria Classic**.  
Fokus: eingehende Heilungen aggregieren, Landzeit/Zeitfenster bestimmen, kompakte Overlays anzeigen.

---

## Was es tut
- Aggregiert eingehende Heilungen (Combat Log + `UnitGetIncomingHeals` als Fallback).
- Schätzt **Landezeit** und **wirksamen Heilwert** inkl. Latenz/Spell-Queue.
- Zeigt einen unaufdringlichen **Prognose-Balken** über Einheitenrahmen.
- Unterstützt **Click-Casting** (Maus + Mods) auf sicheren Unit-Buttons.
- Läuft stabil in **5-Man**, **Raid** und Solo.

---

## Installation
1. Repo-Ordner (oder Release-ZIP) nach
   `World of Warcraft/_classic_/Interface/AddOns/` kopieren.
   - Bei Git-Klon: Verzeichnis in **`NOD_Heal`** umbenennen.
2. Client neu starten → Addon aktivieren.

**SavedVariables:** `NODHealDB` (Profil/Config, Bindings).  
**Kompatibilität:** MoP Classic (Interface `100200`).

---

## Kurzanleitung
- **Overlay**: Prognose-Balken an CompactUnitFrames/Grid.  
- **Click-Casting**: Maus + Alt/Ctrl/Shift auf die Grid-Frames.  
- **Status-Frame**: kleines Feld unten rechts (laufende Quelle/Status).

### Nützliche Slash-Befehle
- `/nod debug on|off|status` – Debug-Ausgabe umschalten.
- `/nod errors` – Fehlerpuffer anzeigen.
- `/nod qa` – Selbsttest für SavedVars, Hooks & Module.
- `/nodoptions` – Optionen (Grid-Layout, Overlay, Sortierung).
- `/nodbind` – Click-Cast-Bindings verwalten.
- `/nodsort group|class|alpha` – Grid sortieren.

---

## Features (Kurz)
- **Incoming Heals**: Aggregator + Fallback, konsolidierte Summen & Confidence.
- **Timing**: Latenz/Queue-Berücksichtigung, robuste Landzeit-Schätzung.
- **Solver**: kombiniert Snapshot/Schaden/Heals → projizierter Health-Wert.
- **UI**: Grid + Overlay, sanfte Updates, Overheal-Segment optional.
- **Härtung**: sichere Hooks, Combat-Lockdown-respektierend.
- **Dispatcher**: gemeinsamer 0,2s-Ticker für Prognosen & Grid-Refresh.

---

## Troubleshooting
- **Addon lädt nicht** → Pfad/TOC prüfen, Cache leeren, Konflikt-Addons testweise deaktivieren.
- **Keine Overlays** → Optionen prüfen, kompatible Einheitenrahmen aktivieren.
- **Bindings greifen nicht** → in Kampf keine Layout-Änderungen; nach Kampf `/reload` falls nötig.
- **Sortierung/Optionen blockiert** → Änderungen außerhalb des Kampfes anstoßen.
- **Mehr Details** → siehe `TROUBLESHOOTING.md` für systematische Checks & Log-Sammeln.

---

## Projektstruktur (Kurz)
NOD_Heal.toc # Lade-Reihenfolge, SavedVariables
Config/ # Defaults & Persistenz
Core/ # Aggregator, Solver, Timing, Dispatcher, Caches
UI/ # Grid, Overlay, ClickCast, Options, Binding-UI
Libs/ # Externe/Interne Hilfsbibliotheken (LibHealComm-4.0)
docs/legacy/ # Archivierte Analysen, QA-Reports & historisches Material

---

## Entwicklung
- Lua-Module, klare Namespaces (`NODHeal.*`).
- Ticker lastarm (~0.1–0.2 s), minimale Allokationen.
- Dokumentation/Artefakte liegen gebündelt unter `docs/legacy/`.

**Lizenz**: siehe `LICENSE` (falls vorhanden).

# DOCU/AGENTS.md — Zweck & Arbeitsregeln

## Zweck des Ordners
Der Ordner **DOCU/** enthält **Quell- und Funktionsdokumentation** für das Healing-Addon **NOD**:
- **Referenz** der Backend-Logik (Signaturen, Datenflüsse, Formeln).
- **Architektur & Modulstruktur** (Ereignisse, Abhängigkeiten, Schnittstellen).
- **Hilfedateien & Erklärungen** (Rationalen, Trade-offs, Vergleichsstudien).
- **UI-/Frame-Kataloge** in **YAML**, um Codex schnelles, zielgerichtetes Einlesen zu ermöglichen.

> **Wichtig:** In DOCU liegt **kein ausführbarer Code**. Nur Dokumentation, Schemata und Beispiele.

---

## Geltungsbereich
Diese Regeln gelten **nur** für Inhalte in `DOCU/`. Für Repository-weite Vorgaben siehe `/AGENTS.md`.

---

## Quellen-Prioritäten (Source of Truth)
Wenn Inhalte widersprüchlich sind, gilt folgende Reihenfolge:

1. `NOD_Backend_Funktionsreferenz.md` → **Backend-Referenz (maßgeblich)**
2. `NOD_Systemaufbau_Modulstruktur.md` → Architektur, Datenflüsse, Trigger/Outputs
3. YAML-Segmente in `docu/ui_frames/*.yaml` → UI-/Frame-APIs (maschinenlesbar)
4. Analysen/Studien:  
   - `NOD_Machbarkeitsanalyse_Technik_MoP.md`  
   - `Vergleich_NOD_vs_HealBot_FeatureAnalyse.md`  
   - `HealingAddons_Funktionsvergleich_NOD_Integration.md`
5. Projektbaum / Wellenplan: `Datei_und_Modulstruktur_NOD-Projektbaum.txt`
6. (Altbestand/Archiv) `NOD_GUI_FrameMapping_Archiv.txt` *(früher: `NOD_Konzept_Funktionsliste.txt`)*

---

## Regeln für Codex (sehr wichtig)
- **Nicht** den gesamten Ordner einlesen; arbeite **abschnittsbezogen**.
- **Keine Änderungen** an Code-Dateien von hier aus. DOCU ist **Read-Only** für Code.
- **Kein Volltext-Scan** großer Dateien (z. B. 30k+ Zeilen).  
  Stattdessen:
  1) **Index erzeugen** (Module/Funktionen/Headers extrahieren)  
  2) **Gezielt** den benötigten Abschnitt lesen
- **Max Chunk Size**: ≤ **800 Zeilen** pro Lesevorgang.
- **Duplikate/Redundanz** melden, **nicht** zusammenführen (Entscheidung durch Maintainer).

---

## Dateitypen in DOCU
- **Backend-Referenz:** `NOD_Backend_Funktionsreferenz.md`  
  - Enthält: Module, Funktionssignaturen, Formeln, Events, IO.
- **Architektur:** `NOD_Systemaufbau_Modulstruktur.md`  
  - Enthält: Systembaum, Datenpfade, Update-Takte.
- **UI-/Frame-APIs (YAML):** `docu/ui_frames/*.yaml`  
  - Enthält: Frames, Elemente, Funktionen, Events, Parameter für UI-Implementierung.
- **Analysen & Vergleiche:**  
  - `NOD_Machbarkeitsanalyse_Technik_MoP.md`  
  - `Vergleich_NOD_vs_HealBot_FeatureAnalyse.md`  
  - `HealingAddons_Funktionsvergleich_NOD_Integration.md`
- **Projekt-/Wellenplan:** `Datei_und_Modulstruktur_NOD-Projektbaum.txt`
- **Archiv:** `NOD_GUI_FrameMapping_Archiv.txt` *(nur Quelle für spätere Extraktionen)*

---

## Arbeitsweise mit großen Dateien
- Erzeuge zuerst einen **Funktionsindex**:  
  - Erkenne Section-Header wie `## Modul: …`, `### Funktion: …`
  - Liste **Modul → Funktionen → Eingaben/Outputs/Events**
- Greife **nur** auf die **konkreten** benötigten Abschnitte zu (keine Volltextanalyse).
- Wenn Abschnitte fehlen/uneindeutig sind: **Report erstellen**, keine Spekulation.

---

## YAML-Schema für UI/Frames (Referenz)
Alle neuen UI-Definitionen bitte in `docu/ui_frames/` nach folgendem Schema:

```yaml
FrameName:
  type: Frame | Button | StatusBar | Texture | FontString
  description: Kurzbeschreibung
  elements:
    - ChildOrRegionName
  functions:
    - Name: UpdateSomething
      params:
        - unit: string
        - force: boolean (optional)
      returns: void
      notes: kurze Hinweise
  events:
    - UNIT_HEALTH
    - PLAYER_TARGET_CHANGED
  module_hint: UI/UnitFrames.lua

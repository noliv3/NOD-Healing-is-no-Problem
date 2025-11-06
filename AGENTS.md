# Projektweite Hinweise – NOD-Heal

**Geltungsbereich:** Gilt für das gesamte Repo. Spezifischere `AGENTS.md` in Unterordnern können einzelne Punkte überschreiben.

---

## 1) Repository-Grundregeln
- **Addon-Root:** Repo-Root entspricht dem Addon; beim Release wird der Ordner als `NOD_Heal/` ausgeliefert.
- **Namespaces:** Export nur über `NODHeal.*` (siehe `Core/Init.lua`). Sonst `local`.
- **Sprache:** Pro Datei **eine** Sprache, bevorzugt **Englisch**.
- **SavedVariables:** `NODHealDB` (Config/Bindings). Schreib-/Lese-Logik nur bei `ADDON_LOADED`/Logout, keine riskanten Änderungen im Combat.

---

## 2) Coding-Style (Lua)
- Keine globalen Variablen außer Namespaces.
- Keine teuren Allokationen in `OnUpdate`; Ticker ≥ **0.1–0.2 s**.
- **Ticker-Sharing:** UI-Refreshes hängen am `CoreDispatcher.RegisterTick()` (0.2 s) statt eigener Loops.
- Guards vor jedem API-/Global-Hook:
  ```lua
  if type(CompactUnitFrame_OnLeave) == "function" then
      hooksecurefunc("CompactUnitFrame_OnLeave", handler)
  end
  ```
  Wo möglich: `frame:HookScript("OnEnter", ...)` statt Globalnamen.
- UI-Aktionen, die Attribute setzen, nur auf **eigenen** `SecureUnitButtonTemplate`-Frames.
- Logging nur via `NODHeal.Log/Logf`; Debug-Flag respektieren.

---

## 3) Ordnerstruktur (Soll)
```
NOD_Heal.toc
Config/         # Defaults & Persistenz
Core/           # Aggregator, Solver, Timing, Dispatcher, Caches
UI/             # Grid, Overlay, ClickCast, Options, Binding-UI
Libs/           # integrierte libs (LibHealComm-4.0)
docs/legacy/    # Archivierte Analysen, QA-Reports & historisches Material
```

---

## 4) Dokumentation (knapp halten)
- **README.md** beschreibt nur: Zweck, Installation, Kurz-Usage, Slash-Befehle, Struktur, Troubleshooting.
- Änderungen mit Funktionsauswirkung: **kurze Notiz** in README + optional `CHANGELOG.md`.
- Umfangreiche Analysen/Altmaterial: in `docs/legacy/` bündeln (Release-ZIP bleibt schlank).
- Keine spekulativen Aussagen (nur Umgesetztes dokumentieren).

---

## 5) Review-/Build-Checkliste (bei jedem PR)
1. **TOC** aktuell (Interface, SavedVariables, Lade-Reihenfolge).
2. **Dispatcher**-Routen/Hooks verifiziert (`Core/CoreDispatcher.lua`).
3. **SavedVariables** laden/speichern stabil (Defaults, Migration, nil-Guards).
4. **Hooks** nur auf existierende Funktionen / `HookScript`-Varianten.
5. **Combat**-Sicherheit: keine verbotenen Änderungen im Lockdown.
   - Grid/ClickCast nutzen die `CoreDispatcher.EnqueueAfterCombat`-Queue bzw. `UI.Grid`-Request-Rebuilds; neue Secure-Ops immer dort einreihen (kein Live-`SetAttribute`/`SetPoint`).
6. **Logs**: Debug-Texte hinter Flag; keine `print`-Streufeuer.
7. **README** angepasst, falls Verhalten/Kommandos geändert.
8. **Packaging**: Release-ZIP enthält nur `NOD_Heal/**`, README, LICENSE.

---

## 6) Manuelle QA (Kurz-Playbook)
- **Laden ohne Fehler**: frischer Clientstart, Addon aktiv.
- **Slash-Checks**:
  `/nod debug on|off|status`, `/nod errors`, `/nodoptions`, `/nodbind`, `/nodsort group|role|alpha`
  - Legacy `/nodsort class` wird automatisch als `role` interpretiert.
- **Self-Test**: `/nod qa` prüft SavedVars, Hooks & Module.
- QA erwartet aktiven Dispatcher-Ticker + Overlay-Kontrollen.
- **Overlay** sichtbar an CompactUnitFrames/Grid (Party/Raid).
- **Click-Cast** auf Grid-Frames (Maus + Mods) funktioniert im Kampf.
- Out-of-Range-Click-Casts beenden den Cursor sofort (Macro mit `/stopspelltargeting`).
- Tooltip dockt am Statusframe unten rechts an (Fallback UIParent).
- `/nodsort group|role|alpha` prüft Sortierung (Layout horizontal belassen).
  - Historische SavedVariables mit `class` werden auf `role` gemappt.
- **SavedVariables**: Einstellungen/Bindings persistieren über `/reload`.

---

## 7) Agents / Automatisierung (minimal & klar)
- Kein Workflow eingecheckt – Packaging aktuell manuell/über lokale Skripte.
- Falls CI ergänzt wird: Nur Baumvalidierung & Release-ZIP mit `NOD_Heal/**`, `README.md`, `LICENSE` erzeugen.
- Keine externen Secrets voraussetzen. Keine Artefakt-Flut erzeugen.

---

## 8) Dateifilter (immer ignorieren/entfernen)
- **Ignorieren** in `.gitignore` und `.codexignore`:
  ```
  reports/ coverage/ out/ build/ dist/ tmp/ .cache/ __pycache__/
  *.log *.tmp *.out *.err *.report* *.sarif
  *.pdf *.docx *.zip
  ```
- Produktiv niemals commiten: generierte Reports, Snapshots, riesige Office/PDFs.  
- Alte Doku → innerhalb `docs/legacy/` ablegen (statt löschen).

---

## 9) Commit-/PR-Konventionen
- **Commit**: `scope: kurze 7–10 Wort Zusammenfassung`
  - Beispiel: `ui/grid: throttle refresh to 0.1s`
- **PR-Beschreibung**: Problem → Lösung → Risiko/Härtung → QA-Schritte (3–5 Zeilen).
- Verweise: betroffene Dateien/Module, relevante Slash-Kommandos.

---

## 10) Do / Don’t
**Do**
- Guarded Hooks, kurze Funktionen, lokale Caches.
- Ein Log-Gateway, ein Dispatcher, klare Ownership.
- Kleine PRs, verständliche Diffs, kurze Doku.

**Don’t**
- Globale Side-Effects, unguarded `hooksecurefunc`, große `OnUpdate`.
- Combat-Lockdown brechen, `print`-Spam, spekulative README-Abschnitte.
- Reports/Artefakte ins Release packen.

---

## 11) Status (Informativ, kein Roman)
Aktiv & produktiv: HealthSnapshot, CastLandingTime, IncomingHeals (+Aggregator), HealValueEstimator, PredictiveSolver, LatencyTools, DamagePrediction, AuraTickPredictor, EffectiveHP, DesyncGuard, CoreDispatcher; UI: Grid/Overlay/ClickCast/Options/Binding-UI.

*Ziel: stabiler, leichtgewichtiger Heil-Workflow in 5-Man & Raid.*

## 12) Corner Icons (Grid & Optionen)
- Grid-Eck-Icons aktualisieren über `NODHeal.UI.Grid.UpdateAllIconLayout()` + `RefreshAllAuraIcons()`; Frames via `GetTrackedFrames()` bereitstellen.
- Optionssektion **Corner Icons** pflegt `NODHeal.Config.icons` (Enable/HoT/Debuff/Size) und stößt kampfsichere Refreshes per `C_Timer.After` an.
- HoT-Auswahl priorisiert eigene Auren (`UnitIsUnit(unitCaster, "player"/"pet")`), fällt ansonsten auf Whitelist-HoTs zurück und wird bei Login/Zielwechsel/Gruppenupdates automatisch neu bewertet.
- HoT-Grid unterstützt bis zu 12 Symbole (max. 6 pro Reihe) mit konfigurierbarer Ausrichtung/Abständen (`hotPerRow`, `hotDirection`, `spacing`, `rowSpacing`); Debuff-Ecke bleibt bewusst auf eine Reihe begrenzt.
- HoT-Erkennung läuft über `Core/HotDetector` (Combat-Log lernt `SPELL_PERIODIC_HEAL` → Persistenz in `NODHealDB.learned.hots`); Seed-Whitelist in `Config/Defaults.lua` nur klein halten, UI nutzt ausschließlich `HotDetector.IsHot(spellId)` als Quelle.
- Grid-Implementierung ruft `HotDetector.IsHot` direkt auf; Config-Whitelist dient nur noch als Fallback, sollte nicht mehr separat gepflegt werden.
- `UI/GridFrame.lua`: `getConfig()` muss oberhalb der Layout-/Aura-Helfer stehen, damit die Corner-Icons direkt nach dem Laden wieder sichtbare Texturen erhalten.
- Major-CD-Lane (`UI/GridFrame.lua`) nutzt `Core/CooldownClassifier` für DEF/EXTERNAL/SELF/ABSORB; Konfiguration via `Config.major` (Enable, Größe, Caps) und Options-Slider "Major icon size".

## 13) Death Authority / Grid States
- `Core/DeathAuthority.lua` bündelt Todes-/Ghost-/Feign-/Offline-Status. Neue Quellen immer dort einspeisen (`FlagDying`, `RefreshUnit`, CLEU), nicht direkt im UI.
- Solver & Incoming-Heals müssen `DeathAuthority.IsHealImmune` respektieren (Hard-0 für DEAD/GHOST/FEIGN), sonst laufen Overheal-Anzeigen weiter.
- `UI/GridFrame.applyStateDecor` hält Icons/Texturen/Rez-Indicator synchron mit `STATE_LABELS`. Bei Erweiterungen Zustands-Icons + Farben konsistent pflegen, Heartbeat (0,7 s) nicht enger ziehen.

## 14) Predictive Solver Calls
- `PredictiveSolver.CalculateProjectedHealth(unit[, opts])` immer mit gültigem Unit-String aufrufen; `opts.tLand` kann über `CastLandingTime.ComputeLandingTime` (UnitCasting/ChannelInfo) vorbelegt werden.
- UI & Overlay respektieren `DesyncGuard.IsFrozen(unit)` (Freeze ≈ 150 ms nach Cast-Start) und lassen währenddessen bestehende Projektionen unangetastet.
- Ergebnisfelder (`projectedHealth`, `overheal`, `hp_now`, `hp_max`) direkt nutzen; keine doppelte Addition von API-Incoming. Fallback auf Live-HP nur bei `nil`- oder Fehl-Resultaten.

## 15) QA & Debug Notes
- Major-CD-Blocklist akzeptiert Zahlen- oder String-IDs; Vergleiche normalisieren auf numerische IDs mit String-Fallback (siehe `Core/CooldownClassifier`).
- `/nod qa` ergänzt den Abschnitt "CD Lane" (seeds/learned/blocked/visible, block_match, erste 3 sichtbare CDs) sowie – falls vorhanden – "HoT Learn/Block".
- Debug-Telemetrie (`NODHeal.Telemetry`) bündelt solver_calls/s, aura_refresh/s und queue_after_combat-Größe im 5s-Intervall, ringgepuffert (100 Zeilen) und nur aktiv bei `Config.debug = true`.
- Grid-Frames nutzen `_nodShouldShow`/`_nodVisibilityQueued`: Im Kampf nur Alpha+Mouse toggeln, echtes Hide/Show wird nach Combat via Queue nachgezogen (keine unsichtbaren klickfangenden Buttons).

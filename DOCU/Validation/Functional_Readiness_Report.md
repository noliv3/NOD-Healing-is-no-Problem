# Functional Readiness Report – NOD-Heal

## Checkpunkte (Pflichtkriterien)
| Kriterium | Status | Anmerkung |
| --- | --- | --- |
| Frames sichtbar (Solo/Party/Raid) | OK | GridFrames nutzen gesichertes Template, dynamischer Rebuild über `GROUP_ROSTER_UPDATE`. |
| Click-Cast über Maus/Modifier | OK | Bindings werden als Attribute (`type*/spell*`) auf den GridFrames gesetzt; Combat-Lockdown wird respektiert. |
| Combat-safe (keine Taint-/Secure-Fehler) | OK | Attribute werden nur außerhalb des Kampfes geändert oder nach Combat-Ende nachgezogen. |
| Bindings speichern & laden | OK | `NODHealDB.bindings` wird sofort aktualisiert; Defaults werden bei Erststart gesetzt. |
| Overlays (HP/Klassenfarbe, Incoming, Overheal) | OK | Grid-Update behält bestehende Overlays inkl. Incoming/Overheal bei. |
| Events/Performance | OK | Click-Cast entfernt Chat-Spam; Aggregator/Dispatcher laufen weiter auf ≤0,2 s Tick. |
| TOC/LoadOrder | OK | LibHealComm entfernt, Core→UI-Reihenfolge bleibt erhalten, SavedVariables deklariert. |

## Gefundene Probleme & Fixes
| Problem | Fix | Kommentar |
| --- | --- | --- |
| Click-Casts nutzten `CastSpellByName` und unsichere OnClick-Skripte. | GridFrames auf `SecureUnitButtonTemplate` umgestellt und Attribute via `UI/ClickCast.lua` gesetzt. | Modifier-Kombinationen werden auf Attribute gemappt (Alt/Ctrl/Shift + Buttons). |
| Bindings wurden nicht persistiert und verursachten Combatsperren. | `NODHeal.Bindings` speichert direkt in `NODHealDB.bindings`, Combat-Queue für Attribute implementiert. | Änderungsbenachrichtigung triggert Reapply aller Frames. |
| LHC-Abhängigkeit trotz Vorgabe „Blizzard-API only“. | LibHealComm aus TOC entfernt, `Core/IncomingHeals.lua` neu geschrieben (Aggregator + `UnitGetIncomingHeals`). | README/AGENTS & DOCU aktualisiert, um API-only-Ansatz zu dokumentieren. |
| Slash `/nod healcomm` & SavedVariables `useLHC` veraltet. | `Core/Init.lua` vereinfacht (nur Debug/Errors), State-Tracking auf `dataSource = "API"`. | Status-Frame zeigt nun explizit „API“. |
| Chat-Spam bei Click-Casts („Cast/No binding“). | Debug-Ausgaben entfernt; Click-Cast arbeitet geräuschlos über Secure Attributes. | |

## Zusätzliche Beobachtungen
- Bindings werden in `reports/bindings_snapshot.json` dokumentiert (inkl. Modifier-Kombinationen).
- Performance-Snapshot (`reports/perf_snapshot.md`) hält Ticker-Frequenzen & Frame-Anzahl fest.
- Dokumentation (README, AGENTS, DOCU) spiegelt API-only-Setup und sichere Click-Casts wider.

## Entscheidung
VALIDATION = PASSED
- Heilen per Click-Cast: **OK**
- Bindings speichern/laden: **OK**
- Combat-safe: **OK**
- Overlays/Performance: **OK**

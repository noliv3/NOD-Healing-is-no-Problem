# Tag 7 — Tag & Smoke

**Ziel**
Ablaufplan für 5-Mann-„Smoke-Test“ und anschließende Versionierung `v1.1` (Dokumentation, keine Ausführung).

**Scope**
- Dungeon-Kurzszenario, Messpunkte, Log-Sammeln.
- Release-Notizen-Gliederung (Highlights, bekannte Einschränkungen).

**Teilaufgaben**
- ☐ Testschritte (Setup → Run → Collect → Review).
- ☐ Was gilt als „Go/No-Go“ (min. 4/5 Tests bestanden).
- ☐ Template für Release-Notes (README-Anhang).

**Referenzartefakte**
- Smoke-Test-Checkliste mit Phasen:
  1. **Setup**: Party bilden, `/nod debug on`, LHC-Status prüfen.
  2. **Run**: 10 Minuten Dungeon (Trash + Boss), Marker für großen Raid-Damage setzen.
  3. **Collect**: Logs sichern (`Logs/`), Screenshots Overlay, Werte aus `/nod test` für 3 Einheiten.
  4. **Review**: Tabelle Pass/Fail je Test, Abweichungen dokumentieren.
- Go/No-Go-Kriterium: mind. 4 von 5 Playbook-Fällen aus Tag 5 bestanden, kein ungefangener LUA-Fehler im `Logs/FrameXML.log`.
- Release-Notes-Template: Überschriften `Highlights`, `Bekannte Einschränkungen`, `Tests`, `Changelog v1.1`, Verweis auf `DOCU/Tasks/`.

**Akzeptanzkriterien**
- Vollständiger, wiederholbarer Smoke-Plan; klare Go/No-Go-Schwelle.

**Risiken**
- Nicht repräsentative Dungeon-Runs; unvollständige Logs.

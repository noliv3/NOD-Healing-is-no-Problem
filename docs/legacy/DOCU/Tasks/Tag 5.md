# Tag 5 — Debug & Tests (manuell)

**Ziel**
Slash-Kommandos und 5-Fälle-Playbook dokumentieren; Testdatei `DOCU/Tests.md` definieren.

**Scope**
- `/nod test <unit> <spell>` (Fake-Cast, nur dokumentiert)
- `/nod debug on|off` (Log-Verbosity)

**Teilaufgaben**
- ☐ Kommandospezifikationen inkl. erwarteter Logausgabe.
- ☐ 5 Testfälle (Solo, 5-Mann, LHC an/aus, hoher Ping, Freeze-Edge-Case).
- ☐ Ergebnis-Protokollformat (Zeit, Quelle, Erwartung/Beobachtung).

**Referenzartefakte**
- Tabelle Slash-Kommandos: Kommando, Zweck, Parameter, Beispielausgabe (`[NOD] DEBUG: ...`).
- Playbook-Fälle:
  1. Solo-Target Dummy → Erwartung „Incoming=0, Fallback aktiv“.
  2. 5-Mann Dungeon mit LHC aktiv → Erwartung „HealComm-Eintragsrate ≥1/s“.
  3. LHC deaktiviert (`/nod healcomm off`) → Vergleich API vs. Aggregator.
  4. 200+ ms Latenz (Sim) → Beobachtung `LatencyTools` Werte, Freeze-Verhalten prüfen.
  5. Freeze-Guard Edge (Interrupt kurz vor Landung) → Overlay darf nicht springen.
- Protokollformat für `DOCU/Tests.md`: Tabelle mit Spalten `Zeitstempel`, `Setup`, `Erwartung`, `Beobachtung`, `Status (☐/☑)`, `Notizen`.
- Logging-Level: `info`, `debug`, `warn`; Vorgabe „debug nur bei `/nod debug on` aktiv“.

**Akzeptanzkriterien**
- Vollständige Testliste mit klaren „Pass/Fail“ Kriterien.

**Risiken**
- Nicht deterministische Latenz; Dritt-Addon-Interferenzen.

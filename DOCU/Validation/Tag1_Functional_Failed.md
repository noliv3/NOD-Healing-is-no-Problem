# Tag 1 – Functional Validation FAILED

- Toggle-Kommandos setzen keinen Status und registrieren/deregistrieren keine Quellen; alle drei Module loggen nur den Aufruf ohne Wirkung.
- LibHealComm-Events landen ausschließlich in `IncomingHeals`; `IncomingHealAggregator.scheduleFromTargets` bleibt Stub ohne Queue-Feed, Dispatcher erhält keine Meldung.
- Umschalten zwischen LHC und API erzeugt keine Statuslogs; alle Toggle- und CleanExpired-Meldungen sind identisch und nicht unterscheidbar.
- Dokument `NOD_Datenpfad_LHC_API.md` fordert Statusflag, Timestamp-Logs und Priorisierungsschritte, die im Code nicht umgesetzt sind.

Betroffene Logik: HealComm-Toggle-Handling (`IncomingHeals`, `IncomingHealAggregator`, `CoreDispatcher`), LHC→Aggregator-Brücke, Logging-Konzept.

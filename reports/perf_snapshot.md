# Performance Snapshot – NOD-Heal Grid (2025-05)

- Grid ticker: 0.1 s (`C_Timer.NewTicker` in `UI/GridFrame.lua`).
- Dispatcher ticker: 0.2 s (`Core/CoreDispatcher.lua`).
- Sichtbare Frames: dynamisch (Solo = 1, Party = bis zu 5, Raid = bis zu 40); unsichtbare Frames werden geparkt.
- Attribute-Update-Warteschlange greift nur außerhalb des Kampfes; Combat-Reapply erfolgt einmalig nach `PLAYER_REGEN_ENABLED`.
- Keine wiederkehrenden Chat-Ausgaben oder Debug-Logs im Normalbetrieb (Debug nur bei `/nod debug on`).

# NOD-Heal Troubleshooting

This guide helps you narrow down issues quickly before you escalate them to the team.

---

## 1. Quick System Checks
1. **Client build** – Use the current Mists of Pandaria Classic client (`Interface 100200`).
2. **Addon folder name** – The directory must be `NOD_Heal` inside `Interface/AddOns`.
3. **Saved variables reset** – Temporarily move `WTF/Account/<Account>/SavedVariables/NODHeal.lua` to isolate corrupt data.
4. **Combat lockdown** – Layout changes, binding edits, or secure attribute updates must happen out of combat.

---

## 2. Common Symptoms & Fixes
### Addon missing in the list
- Verify the folder path: `World of Warcraft/_classic_/Interface/AddOns/NOD_Heal`.
- Delete cached addon lists: remove `WTF/Account/*/AddOns.txt` and restart the client.
- If the TOC version mismatches, reopen `NOD_Heal.toc` and confirm `## Interface: 100200`.

### Overlay bars are invisible
- `/nodoptions` → enable CompactUnitFrames or the custom Grid module.
- Check if another raid-frame addon hides the NOD overlay; disable it temporarily.
- Reload the UI after changing frame scale or anchor settings (`/reload`).

### Click-casting does nothing
- Use `/nodbind` and confirm each modifier/button pair is assigned.
- Ensure you exited combat before editing binds; otherwise changes are queued until `/reload`.
- Remove conflicting bindings from other addons (Clique, VuhDo) while testing.

### Self-test fails or reports stale modules
- Run `/nod qa` after login to collect module health indicators.
- Compare the module list with `Core/` to spot missing files in the install.
- Clear `NODHealDB` if desync persists after a reload.

---

## 3. Log Collection for Bug Reports
- Enable debugging: `/nod debug on`.
- Reproduce the issue for at least 30 seconds.
- Run `/nod errors` to capture the buffered Lua errors.
- Zip `Logs/`, `WTF/Account/*/SavedVariables/NODHeal.lua`, and `Interface/AddOns/NOD_Heal` before sending.

---

## 4. Preventive Maintenance
- Review bindings after each patch (`/nodbind`).
- Keep the `docs/legacy/` folder out of the live AddOns directory to avoid bloat.
- Run `scripts/pre_release_check.sh` prior to packaging a build.
- Debug logging uses a 100-entry ring buffer; only enable it when actively troubleshooting.

---

If the steps above do not resolve your issue, open a ticket with a short description, reproduction steps, and the collected logs.

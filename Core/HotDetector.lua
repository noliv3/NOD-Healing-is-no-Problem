local M = {}
NODHeal = NODHeal or {}
NODHeal.Core = NODHeal.Core or {}
NODHeal.Core.HotDetector = M

-- Klassen-Seed (kann später erweitert werden)
local CLASS_SEED = {
  DRUID   = { [774]=true,  [33763]=true, [48438]=true },   -- Rejuvenation, Lifebloom, Wild Growth
  PRIEST  = { [139]=true,  [33076]=true },                 -- Renew, Prayer of Mending (tickartig)
  SHAMAN  = { [61295]=true },                              -- Riptide
  MONK    = { [115175]=true,[119611]=true },               -- Soothing Mist, Renewing Mist
  PALADIN = { [53563]=true },                              -- Beacon of Light (Indikator)
}

-- Persistenz-Zugriff
local function getLearned()
  _G.NODHealDB = _G.NODHealDB or {}
  _G.NODHealDB.learned = _G.NODHealDB.learned or {}
  _G.NODHealDB.learned.hots = _G.NODHealDB.learned.hots or {}
  return _G.NODHealDB.learned.hots
end

local function getConfigWhitelist()
  return (NODHeal and NODHeal.Config and NODHeal.Config.icons and NODHeal.Config.icons.hotWhitelist) or {}
end

-- Öffentliche API
function M.IsHot(spellId)
  if not spellId then return false end

  -- 1) Learned DB (Runtime + SavedVariables)
  local L = getLearned()
  local Lv = L[spellId]
  if Lv == true then return true end
  if type(Lv) == "table" and (Lv.learned or Lv.seen) then return true end

  -- 2) Klassen-Seed (sofortige Sichtbarkeit)
  if UnitClass then
    local _, classTag = UnitClass("player")
    local seed = CLASS_SEED[classTag or ""] or {}
    if seed[spellId] then return true end
  end

  -- 3) Konfig-Whitelist (optional gepflegt)
  local wl = getConfigWhitelist()
  if wl[spellId] then return true end

  return false
end

-- Lernlogik: PERIODIC_HEAL -> HoT
local f = CreateFrame("Frame")
f:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
f:SetScript("OnEvent", function()
  local _, subEvent, _, _, _, _, _, _, _, _, _, spellId = CombatLogGetCurrentEventInfo()
  if subEvent == "SPELL_PERIODIC_HEAL" and spellId then
    local L = getLearned()
    if not L[spellId] then
      L[spellId] = true
    end
  end
end)

return M

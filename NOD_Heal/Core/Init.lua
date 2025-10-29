local addonName = ...

local NODHeal = _G.NODHeal or {}
NODHeal.modules = NODHeal.modules or {}
NODHeal.events = NODHeal.events or {}

function NODHeal:RegisterModule(name, module)
    if not name or type(name) ~= "string" then
        error("Module name must be a string")
    end

    self.modules[name] = module
    return module
end

function NODHeal:GetModule(name)
    return self.modules[name]
end

_G.NODHeal = NODHeal

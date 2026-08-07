local mod = get_mod("TourneyBalance")

NewDamageProfileTemplates = NewDamageProfileTemplates or {}

--- Main update hook
-- `mod.update` is a single field that VMF calls every frame. Only one file can assign it directly.
-- Any feature needing per-frame tick should register through `mod:add_update_function(fn)` instead
-- of assigning `mod.update` itself, so multiple features can coexist.
local _update_functions = {}
function mod.add_update_function(self, func)
    _update_functions[#_update_functions + 1] = func
end
mod.update = function (dt)
    for i = 1, #_update_functions do
        _update_functions[i](dt)
    end
end

--- Settings-changed hook
-- Same single-field-collision problem as `mod.update` above: VMF calls `mod.on_setting_changed`
-- directly, so only one file can assign it directly, i.e. whichever file's  `dofile` runs last
-- silently wins. Register any features through `mod:add_setting_changed_function(fn)` instead
-- of assigning `mod.on_setting_changed` itself, so multiple features can coexist.
local _setting_changed_functions = {}
function mod.add_setting_changed_function(self, func)
    _setting_changed_functions[#_setting_changed_functions + 1] = func
end
mod.on_setting_changed = function (...)
    for i = 1, #_setting_changed_functions do
        _setting_changed_functions[i](...)
    end
end

--- In-game localization
-- Replace original strings, if _quick_localize can fetch custom strings
local localization_api = require("scripts/mods/TourneyBalance/_api/_localization_api")
mod:hook("Localize", function(func, text_id)
    local str = localization_api._quick_localize(text_id)
    if str then
        return str
    end
    return func(text_id)
end)

--[[

    Balance Changes 

]]
-- THP/Stagger/Damage Related Changes
mod:dofile("scripts/mods/TourneyBalance/changes/thp_stagger_damage_changes")

-- Career Changes (Ultimates/Passives/Talents)
mod:dofile("scripts/mods/TourneyBalance/changes/career_changes")

-- Weapon Changes
mod:dofile("scripts/mods/TourneyBalance/changes/weapon_changes")

-- Damage profile linking + weapon defaults MUST run after weapon_changes: they finalize
-- and validate whatever weapon_changes registered into NewDamageProfileTemplates/Weapons,
-- and only fill in a default where weapon_changes left a field unset. Reordering these
-- ahead of weapon_changes will silently break or overwrite its customizations.
-- TODO: once weapon_changes.lua is split up, consider calling these two directly from the
-- end of that refactor instead of relying on dofile order here.
mod:dofile("scripts/mods/TourneyBalance/changes/_damage_profile_setup")
mod:dofile("scripts/mods/TourneyBalance/changes/_weapon_defaults_setup")

-- Trait Changes
mod:dofile("scripts/mods/TourneyBalance/changes/trait_changes")

-- Enemies for Spicy
mod:dofile("scripts/mods/TourneyBalance/changes/SpicyEnemies")

-- Misc standalone fixes not tied to any other category
mod:dofile("scripts/mods/TourneyBalance/changes/_misc_fixes")

--[[

    Utility

]]
-- Performance Logging System
-- Disabled: its mod.update collided with stagger_state_visualizer.lua's
-- mod:dofile("scripts/mods/TourneyBalance/logging_and_qol/performance_logging")

-- Mod Checker
mod:dofile("scripts/mods/TourneyBalance/logging_and_qol/mod_checker")

-- Basic QOL Features
mod:dofile("scripts/mods/TourneyBalance/logging_and_qol/basic_qol")

-- Ping Color (Accessibility)
mod:dofile("scripts/mods/TourneyBalance/logging_and_qol/ping_color")

-- Debugging Tools
mod:dofile("scripts/mods/TourneyBalance/debugging/stagger_state_visualizer")


--[[

    Merge Changes


]]
local function updateValues()
	for _, buffs in pairs(TalentBuffTemplates) do
		table.merge_recursive(BuffTemplates, buffs)
	end
	return
end

mod.on_enabled = function (self)
	mod:echo(mod:localize("mod_enabled"))
	updateValues()
	return
end

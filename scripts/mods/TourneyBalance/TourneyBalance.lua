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

--- IngameHud per-frame hook
-- Same problem again, but for an engine hook rather than a single mod field: mod_checker.lua and
-- 13_wh_captain.lua each used to call mod:hook_safe(IngameHud, "update", ...) independently, and
-- having this mod hook the exact same (class, method) more than once meant only one of them
-- actually ran. Register through mod:add_ingame_hud_update_function(fn) instead of calling
-- mod:hook_safe(IngameHud, "update", ...) directly, so this mod only ever installs one such hook.
local _ingame_hud_update_functions = {}
function mod.add_ingame_hud_update_function(self, func)
    _ingame_hud_update_functions[#_ingame_hud_update_functions + 1] = func
end
mod:hook_safe(IngameHud, "update", function (self)
    for i = 1, #_ingame_hud_update_functions do
        _ingame_hud_update_functions[i](self)
    end
end)

--- All-mods-loaded hook
-- Same single-field-collision problem as `mod.update`/`mod.on_setting_changed` above. This one is
-- also the right place to do cross-mod setup (e.g. get_mod("SomeOtherMod")): calling get_mod at a
-- file's own top-level load time is NOT safe, since VMF's mod load order between different mods is
-- not guaranteed - a `get_mod` there can silently return nil and get cached in a local that's never
-- refreshed, if the other mod hasn't loaded yet. By the time on_all_mods_loaded fires, every mod is
-- guaranteed loaded regardless of order. Register through mod:add_all_mods_loaded_function(fn)
-- instead of assigning mod.on_all_mods_loaded itself.
local _all_mods_loaded_functions = {}
function mod.add_all_mods_loaded_function(self, func)
    _all_mods_loaded_functions[#_all_mods_loaded_functions + 1] = func
end
mod.on_all_mods_loaded = function (...)
    for i = 1, #_all_mods_loaded_functions do
        _all_mods_loaded_functions[i](...)
    end
end

--- Game-state-changed hook
-- Same single-field-collision problem again. Register through
-- mod:add_game_state_changed_function(fn) instead of assigning mod.on_game_state_changed itself.
local _game_state_changed_functions = {}
function mod.add_game_state_changed_function(self, func)
    _game_state_changed_functions[#_game_state_changed_functions + 1] = func
end
mod.on_game_state_changed = function (...)
    for i = 1, #_game_state_changed_functions do
        _game_state_changed_functions[i](...)
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
-- Misc standalone fixes not tied to any other category
mod:dofile("scripts/mods/TourneyBalance/changes/_misc_fixes")

-- Enemies for Spicy
mod:dofile("scripts/mods/TourneyBalance/changes/00_spicy_enemies")

-- THP/Stagger/Damage Related Changes
mod:dofile("scripts/mods/TourneyBalance/changes/01_thp_stagger_damage_changes")

-- Career Changes (Ultimates/Passives/Talents)
mod:dofile("scripts/mods/TourneyBalance/changes/02_career_changes")

-- Trait & Property Changes
mod:dofile("scripts/mods/TourneyBalance/changes/03_trait_and_property_changes")

-- Balance diff export - snapshots Weapons/DamageProfileTemplates/etc. on load
-- Placed here to only export weapon changes
mod:dofile("scripts/mods/TourneyBalance/debugging/balance_diff_export")

-- Weapon Changes
mod:dofile("scripts/mods/TourneyBalance/changes/04_weapon_changes")


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

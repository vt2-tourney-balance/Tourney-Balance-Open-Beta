local mod = get_mod("TourneyBalance")
local mod_api = require("scripts/mods/TourneyBalance/_api/_mod_api")
local shared_utils = require("scripts/mods/TourneyBalance/_api/shared_utils")
local is_local = shared_utils.is_local
local buff_perks = require("scripts/unit_extensions/default_player_unit/buffs/settings/buff_perk_names")

--[[
	$BEGIN_TB
		---
		## Zealot
		### Career Ability
		- Turn green hp into white hp on ult.

		### Passives
		**Ironheart**
		- Fixed invincibility not proccing on client.

		**Chasten (new)**
		- Increases healing received by 30%.

		### Talents
		**Smite**
		- Added random crits.
		- Now grants a guaranteed critical strike every 4 hits (from 5).

		**Unbending Purpose**
		- Increased power to 10% (from 5%).
		- Additionally increases melee power by 10%.

		**Holy Fortitude**
		- Reduced healing received to 10% per stack (from 15%).

		**Devotion**
		- Now removes all movement penalties (melee attacks, slowing debuffs) instead of only the slowdown when hit. Ranged weapons still slow him down.
		- Grants immunity to knockback from ranged projectiles and Warpfire.
	$END_TB
]]

--[[

	Ultimate

]]
--Turn green hp into white hp on ult
mod:hook_safe(CareerAbilityWHZealot, "_run_ability", function(self)
    local unit = self._owner_unit
    local health_extension = ScriptUnit.extension(unit, "health_system")
    local perm_health = health_extension:current_permanent_health()
    health_extension:convert_to_temp(perm_health)
end)

--[[

    Passives

]]
-- Ironheart
local IRONHEART_INVULNERABILITY_BUFF = "victor_zealot_invulnerability_on_lethal_damage_taken"

-- Fix Zealot invulnerability desync/invincibility bug: this proc runs on both client and server, and the
-- server is always faster to evaluate the killing blow. The original code only added the buff locally via
-- buff_extension:add_buff, so the server could already consider the owner unkillable without ever telling
-- the client. The client must defer to whatever the server has already synced instead of re-evaluating the
-- killing blow itself, and the server must use mod_api.add_buff so the invulnerability buff actually replicates.
mod_api.insert_proc_function("victor_zealot_gain_invulnerability", function (owner_unit, buff, params)
    local status_extension = ScriptUnit.extension(owner_unit, "status_system")

    if not Managers.state.network.is_server and ALIVE[owner_unit] then
        local buff_extension = ScriptUnit.has_extension(owner_unit, "buff_system")

        return buff_extension:has_buff_type(IRONHEART_INVULNERABILITY_BUFF)
    end

    if ALIVE[owner_unit] and not status_extension:is_knocked_down() then
        local health_extension = ScriptUnit.extension(owner_unit, "health_system")
        local buff_extension = ScriptUnit.has_extension(owner_unit, "buff_system")
        local already_unkillable = buff_extension:has_buff_perk("invulnerable") or buff_extension:has_buff_perk("ignore_death")

        if already_unkillable then
            return false
        end

        local damage = params[2]
        local current_health = health_extension:current_health()
        local killing_blow = current_health <= damage

        if killing_blow then
            mod_api.add_buff(owner_unit, buff.template.buff_to_add)

            return true
        end
    end
end)

--[[
    Chasten - listed
]]
-- 30% healing received (moved from Holy Fortitude)
mod_api.insert_talent_buff_template("witch_hunter", "tb_victor_zealot_chasten_healing_received", {
    stat_buff = "healing_received",
    multiplier = 0.3,
})
mod_api.insert_career_passives("wh_1", {
    "tb_victor_zealot_chasten_healing_received",
})
mod_api.insert_perk_text("tb_wh_1d", "Chasten", "Increases healing received by 30%.")
mod_api.insert_career_perk_descriptions("wh_1", "tb_wh_1d")

--[[

	Talents

]]
--[[
    Smite
]]
-- Added in random crits: clears the vanilla "no_random_crits" talent perk
-- talent_settings_victor.lua:1453
Talents.witch_hunter[7].perks = nil
-- Same fix as Helborg's Tutelage
-- Only consume the stack on a critical hit, so cleave/dual-weapon follow-up hits don't eat it
mod_api.insert_proc_function("tb_remove_crit_count_buff_on_crit_hit_smite", function (owner_unit, buff, params)
    local is_critical = params[6]

    return is_critical and true or false
end)
mod_api.update_talent_buff_template("witch_hunter", "victor_zealot_crit_count_buff", {
    event = "on_hit", -- "on_critical_action"
    buff_func = "tb_remove_crit_count_buff_on_crit_hit_smite" -- "dummy_function"
})
-- Every 4 hits grant a guaranteed crit: the counter grants the crit buff and resets when it reaches max stacks
mod_api.update_talent_buff_template("witch_hunter", "victor_zealot_counter_buff", {
    max_stacks = 4, -- 5
})
mod_api.insert_text("victor_zealot_crit_count_desc", "Every 4 hits grant a guaranteed critical strike. Critical strikes can still occur randomly.")
-- (FIX) Clients get 2 stack counts per hit
local add_buff_on_first_target_hit = ProcFunctions.add_buff_on_first_target_hit
mod_api.insert_proc_function("tb_add_buff_on_first_target_hit_smite", function (owner_unit, buff, params)
    if is_local(owner_unit) then
        add_buff_on_first_target_hit(owner_unit, buff, params)
    end
end)
mod_api.update_talent_buff_template("witch_hunter", "victor_zealot_crit_count", {
    buff_func = "tb_add_buff_on_first_target_hit_smite" --"add_buff_on_first_target_hit"
})

--[[
    Unbending Purpose
]]
-- Vanilla 10% power, plus 10% melee power. Damage is calculated on the server, where this talent's buffs live.
mod_api.update_talent_buff_template("witch_hunter", "victor_zealot_power", {
    multiplier = 0.1, -- 0.05
})
mod_api.insert_talent_buff_template("witch_hunter", "tb_victor_zealot_melee_power", {
    max_stacks = 1,
    stat_buff = "power_level_melee",
    multiplier = 0.1,
})
mod_api.update_talent("wh_zealot", 2, 3, {
    description = "zealot_unbending_purpose_desc",
    description_values = {},
    buffs = {
        "victor_zealot_power",
        "tb_victor_zealot_melee_power",
    },
})
mod_api.insert_text("zealot_unbending_purpose_desc", "Increases power by 10.0% and melee power by 10.0%.")

--[[
    Holy Fortitude
]]
-- 10% healing received per stack
mod_api.update_talent_buff_template("witch_hunter", "victor_zealot_passive_healing_received_buff", {
    multiplier = 0.1 -- 0.15
})
mod_api.update_talent("wh_zealot", 4, 2, {
    description_values = {
        {
            value_type = "percent",
            value = 0.1, -- 0.15
        },
    },
})

--[[
    Devotion
]]
-- No movement penalties (melee attacks, slowing debuffs), ranged weapon actions still slow
-- Also immune to knockback from Warpfire and projectiles, like Grail Knight after Blessed Blade
local DEVOTION_NO_MOVEMENT_PENALTIES_BUFF = "tb_victor_zealot_devotion_no_movement_penalties"

mod_api.insert_talent_buff_template("witch_hunter", DEVOTION_NO_MOVEMENT_PENALTIES_BUFF, {
    max_stacks = 1,
})
mod_api.insert_talent_buff_template("witch_hunter", "tb_victor_zealot_devotion_no_knockback", {
    max_stacks = 1,
    perks = {
        buff_perks.no_ranged_knockback,
    },
})
mod_api.update_talent("wh_zealot", 5, 1, {
    description = "tb_victor_zealot_move_speed_on_damage_taken_desc",
    description_values = {},
    buffs = {
        "victor_zealot_move_speed_on_damage_taken",
        DEVOTION_NO_MOVEMENT_PENALTIES_BUFF,
        "tb_victor_zealot_devotion_no_knockback",
    },
})

-- Attacking, aiming and slowing debuffs (bile, plague, fire, etc.) all slow the player through buffs that scale the
-- movement settings. Those buffs are simply never added while Saltzpyre has Devotion, except for ranged weapon actions
-- (below). Weapon actions also use them to speed the player up (movetech, external multiplier above 1), those are kept.
local DEVOTION_MOVEMENT_SPEED_SETTINGS = {
    move_speed = true,
    crouch_move_speed = true,
    walk_move_speed = true,
}

local function tb_devotion_is_movement_penalty_buff(buff_name, template)
    -- Never gate these: they undo every lerped slowdown, so blocking them leaves the player stuck slowed
    if not template.buffs or string.find(buff_name, "^planted_return_to_normal") then
        return false
    end

    for _, sub_buff in ipairs(template.buffs) do
        local path = sub_buff.path_to_movement_setting_to_modify
        local multiplier = sub_buff.multiplier

        if path and DEVOTION_MOVEMENT_SPEED_SETTINGS[path[1]] then
            -- actions (melee swings, aiming) and debuffs use the lerped variant, the multiplier of actions is passed in externally
            local is_lerp_penalty = sub_buff.apply_buff_func == "apply_action_lerp_movement_buff" and not sub_buff.bonus and (type(multiplier) ~= "number" or multiplier <= 1)
            local is_static_penalty = sub_buff.apply_buff_func == "apply_movement_buff" and type(multiplier) == "number" and multiplier < 1

            if is_lerp_penalty or is_static_penalty then
                return true
            end
        end
    end

    return false
end

-- Ranged weapon actions keep their slowdown. Weapon action buffs are only ever added through
-- ActionUtils.update_action_buff_data, so it marks which unit is adding them.
local action_buff_owner_unit = nil

mod:hook(ActionUtils, "update_action_buff_data", function (func, action_buff_data, buff_data, owner_unit, t)
    action_buff_owner_unit = owner_unit
    func(action_buff_data, buff_data, owner_unit, t)
    action_buff_owner_unit = nil
end)

local function tb_devotion_is_ranged_action_buff(unit)
    if unit ~= action_buff_owner_unit then
        return false
    end

    local inventory_extension = ScriptUnit.has_extension(unit, "inventory_system")

    return inventory_extension and inventory_extension:get_wielded_slot_name() == "slot_ranged"
end

local function tb_devotion_allows_buff(unit, template, params)
    if mod:is_action_movement_speed_up(params) or tb_devotion_is_ranged_action_buff(unit) then
        return true
    end

    local buff_extension = ScriptUnit.has_extension(unit, "buff_system")

    return not (buff_extension and buff_extension:has_buff_type(DEVOTION_NO_MOVEMENT_PENALTIES_BUFF))
end

-- Penalty buffs are gated once through apply_condition, so the check only runs when one of them is added.
-- Done after all mods load so templates added by later files are covered too.
mod:add_all_mods_loaded_function(function ()
    local penalty_buff_names = {}

    for buff_name, template in pairs(BuffTemplates) do
        if tb_devotion_is_movement_penalty_buff(buff_name, template) then
            penalty_buff_names[#penalty_buff_names + 1] = buff_name
        end
    end

    for _, buff_name in ipairs(penalty_buff_names) do
        mod:add_buff_apply_condition(buff_name, tb_devotion_allows_buff)
    end
end)
mod_api.insert_text("tb_victor_zealot_move_speed_on_damage_taken_desc", "Taking damage increases movement speed by 30% for 2 seconds. No longer affected by movement penalties, melee weapon slowdown, and knockback from ranged projectiles and Warpfire.")

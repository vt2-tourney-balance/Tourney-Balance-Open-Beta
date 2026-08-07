local mod = get_mod("TourneyBalance")
local mod_api = require("scripts/mods/TourneyBalance/_api/_mod_api")

--[[
	$BEGIN_TB
		---
		## Witch Hunter Captain
		### Talents
		**Riposte**
		- Fix description: crits also applpy to ranged attacks.

		**Templar's Knowledge**
		- Duration increased to 15s (from 5s).
		- Elites and specials take 25% more direct damage from Saltzpyre.

		**I Shall Judge You All**
		- Permanently marks specials. Headshotting tagged enemies refreshes Animosity duration.

		**Fervency**
		- Increased duration to 10s (from 6s).
		- Added ult makes first hits 20 guaranteed melee crits.
	$END_TB
]]

--[[

	WHC Talents

]]

--[[
	Riposte
]]
mod_api.insert_text("victor_witchhunter_guaranteed_crit_on_timed_block_desc", "Blocking just as an enemy attack is about to hit causes your next melee or ranged attack within 2 seconds to be a guaranteed critical hit.")

--[[
	Templar's Knowledge
]]
-- 25% damage increase to specials and elites under thp_stagger_changes.lua
-- Duration increase
mod_api.update_talent_buff_template("witch_hunter", "victor_witchhunter_improved_damage_taken_ping", {
	duration = 15, -- 5
})
mod_api.update_talent("wh_captain", 4, 1, {
	description = "victor_witchhunter_improved_damage_taken_ping_desc",
	description_values = {},
})
mod_api.insert_text("victor_witchhunter_improved_damage_taken_ping_desc", "Witch Hunt causes enemies to take an additional 5.0% damage. Victor deals additional 25.0% direct damage to enemies affected by Witch Hunt (excluding Lords and Bosses).")

--[[
	Fervency
]]
-- Extend durationto 10s
mod_api.update_talent_buff_template("witch_hunter", "victor_witchhunter_activated_ability_guaranteed_crit_self_buff", {
	duration = 10, -- 6
})

-- Additionall 20 stacks of guaranteed melee crit hits on ult use
mod_api.insert_talent_buff_template("witch_hunter", "tb_fervency_crit_stacks", { -- 20 stacks of melee crits buff
	icon = "victor_witchhunter_activated_ability_guaranteed_crit_self_buff",
	stat_buff = "critical_strike_chance_melee",
	bonus = 1,
	max_stacks = 20,
})
mod_api.insert_talent_buff_template("witch_hunter", "tb_fervency_stack_provider", { -- provides the 20 stacks on ult
	buff_func = "add_buff_reff_buff_stack",
	buff_to_add = "tb_fervency_crit_stacks",
	amount_to_add = 20,
	event = "on_ability_activated",
})
mod_api.insert_talent_buff_template("witch_hunter", "tb_fervency_stack_consumer", { -- consumes 1 stack per enemy hit
	buff_func = "remove_buff_stack",
	event = "on_melee_hit",
	max_stacks = 1,
	remove_buff_stack_data = {
		{ buff_to_remove = "tb_fervency_crit_stacks", num_stacks = 1 },
	},
})
mod_api.update_talent("wh_captain", 6, 2, {
	buffs = {
		"tb_fervency_stack_provider",
		"tb_fervency_stack_consumer"
	},
})
mod_api.insert_text("victor_witchhunter_activated_ability_guaranteed_crit_self_buff_desc", "Animosity grants Victor guaranteed melee critical strikes for 10 seconds and the next 20 melee hits. No longer affects teammates and ranged attacks.")


--[[
	I Shall Judge You All
]]
-- I Shall Judge You All: headshotting a Witch Hunted enemy refreshes Animosity's duration
mod_api.insert_proc_function("tb_isjya_refresh_animosity_on_headshot", function (owner_unit, buff, params)
	if not Unit.alive(owner_unit) or not Managers.state.network.is_server then
		return
	end

	local hit_unit = params[1]
	local hit_zone_name = params[3]

	if hit_zone_name ~= "head" and hit_zone_name ~= "neck" then
		return
	end

	local hit_unit_buff_extension = hit_unit and ALIVE[hit_unit] and ScriptUnit.has_extension(hit_unit, "buff_system")

	if not hit_unit_buff_extension or not hit_unit_buff_extension:has_buff_type("defence_debuff_enemies") then
		return
	end

	local side = Managers.state.side.side_by_unit[owner_unit]
	local player_and_bot_units = side and side.PLAYER_AND_BOT_UNITS

	if not player_and_bot_units then
		return
	end

	local buff_system = Managers.state.entity:system("buff_system")

	for i = 1, #player_and_bot_units do
		local unit = player_and_bot_units[i]

		if HEALTH_ALIVE[unit] and ScriptUnit.extension(unit, "buff_system"):has_buff_type("victor_witchhunter_activated_ability_crit_buff") then
			buff_system:add_buff(unit, "victor_witchhunter_activated_ability_crit_buff", owner_unit)
		end
	end
end)
mod_api.insert_talent_buff_template("witch_hunter", "tb_isjya_refresh_animosity_on_headshot", {
	buff_func = "tb_isjya_refresh_animosity_on_headshot",
	event = "on_hit",
})

mod_api.update_talent("wh_captain", 6, 1, {
	buffs = {
		"tb_isjya_refresh_animosity_on_headshot",
	},
})
mod_api.insert_text("victor_captain_activated_ability_stagger_ping_debuff_desc", "Applies Witch Hunt to enemies hit by Animosity and permanently to all specials.\n\nHeadshotting enemies affected by Witch Hunt refreshes the duration of Animosity for the whole party.")

--[[ Ping All Specials on WHC ISJYA ULT ]]
local PING_DURATION = 150
local marked_enemies = {}

OutlineSettings.colors.tb_judged_special = {
	pulsate = false,
	pulse_multiplier = 50,
	color = {
		255, -- alpha, r, g, b
		mod:get("tb_special_tag_color_r"),
		mod:get("tb_special_tag_color_g"),
		mod:get("tb_special_tag_color_b") },
}
OutlineSettings.templates.tb_judged_special = {
	method = "ai_alive",
	priority = 15,
	outline_color = OutlineSettings.colors.tb_judged_special,
	flag = OutlineSettings.flags.non_wall_occluded,
}

-- Update outline color only when a setting actually changes
mod:add_setting_changed_function(function ()
	local color = OutlineSettings.colors.tb_judged_special.color

	color[2] = mod:get("tb_special_tag_color_r")
	color[3] = mod:get("tb_special_tag_color_g")
	color[4] = mod:get("tb_special_tag_color_b")

	-- Force already-tagged specials to redraw immediately with the new color, not just future tags
	for enemy_unit, data in pairs(marked_enemies) do
		if ALIVE[enemy_unit] and data.outline_id then
			local outline_extension = ScriptUnit.has_extension(enemy_unit, "outline_system")

			if outline_extension then
				outline_extension:reapply_outline()
			end
		end
	end
end)

-- Register outline colors
mod:hook_safe(DamageUtils, "create_explosion", function (world, attacker_unit, impact_position, rotation, explosion_template, scale, damage_source, is_server, is_husk, damaging_unit, attacker_power_level, is_critical_strike, source_attacker_unit)
	if damage_source ~= "career_ability" or not ALIVE[attacker_unit] then
		return
	end

	local career_extension = ScriptUnit.has_extension(attacker_unit, "career_system")

	if not career_extension or career_extension:career_name() ~= "wh_captain" then
		return
	end

	local talent_extension = ScriptUnit.has_extension(attacker_unit, "talent_system")

	if not talent_extension or not talent_extension:has_talent("victor_captain_activated_ability_stagger_ping_debuff") then
		return
	end

	local has_templars_knowledge = talent_extension:has_talent("victor_witchhunter_improved_damage_taken_ping")
	local proximity_system = Managers.state.entity:system("proximity_system")
	local t = Managers.time:time("game")

	for enemy_unit, _ in pairs(proximity_system.ai_unit_extensions_map) do
		local breed = Unit.get_data(enemy_unit, "breed")
		local is_special = breed and breed.special

		if ALIVE[enemy_unit] and is_special then
			if marked_enemies[enemy_unit] then
				marked_enemies[enemy_unit].expire_t = t + PING_DURATION
			else
				local ping_extension = ScriptUnit.has_extension(enemy_unit, "ping_system")

				if ping_extension then
					ping_extension:set_pinged(true, false, attacker_unit, false)

					local outline_extension = ScriptUnit.has_extension(enemy_unit, "outline_system")
					local outline_id = outline_extension and outline_extension:add_outline(OutlineSettings.templates.tb_judged_special)

					marked_enemies[enemy_unit] = {
						owner_unit = attacker_unit,
						expire_t = t + PING_DURATION,
						outline_id = outline_id,
					}
				end
			end

			if Managers.state.network.is_server then
				local buff_system = Managers.state.entity:system("buff_system")

				buff_system:add_buff_synced(enemy_unit, "defence_debuff_enemies", BuffSyncType.All, {
					external_optional_duration = PING_DURATION,
				})

				if has_templars_knowledge then
					buff_system:add_buff_synced(enemy_unit, "victor_witchhunter_improved_damage_taken_ping", BuffSyncType.All, {
						external_optional_duration = PING_DURATION,
					})
				end
			end
		end
	end
end)

-- Clean up expired outlines
local MARK_EXPIRY_CHECK_INTERVAL = 1
local next_mark_expiry_check_t = 0
mod:hook_safe(IngameHud, "update", function (self)
	if not next(marked_enemies) then
		return
	end

	local t = Managers.time:time("game")

	if t < next_mark_expiry_check_t then
		return
	end

	next_mark_expiry_check_t = t + MARK_EXPIRY_CHECK_INTERVAL

	for enemy_unit, data in pairs(marked_enemies) do
		if not ALIVE[enemy_unit] or t >= data.expire_t then
			if ALIVE[enemy_unit] then
				local ping_extension = ScriptUnit.has_extension(enemy_unit, "ping_system")

				if ping_extension then
					ping_extension:set_pinged(false, nil, data.owner_unit, false)
				end

				local outline_extension = ScriptUnit.has_extension(enemy_unit, "outline_system")

				if outline_extension and data.outline_id then
					outline_extension:remove_outline(data.outline_id)
				end
			end

			marked_enemies[enemy_unit] = nil
		end
	end
end)



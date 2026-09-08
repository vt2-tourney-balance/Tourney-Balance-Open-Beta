local mod = get_mod("TourneyBalance")
local mod_api = require("scripts/mods/TourneyBalance/_api/_mod_api")
local color_presets = require("scripts/mods/TourneyBalance/accessibility/_color_presets")
local shared_utils = require("scripts/mods/TourneyBalance/_api/shared_utils")
local is_server = shared_utils.is_server
local is_local = shared_utils.is_local

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
		- Apply Witch Hunt to all enemies within Animosity's range and all specials.
		- Headshotting Witch-Hunted enemies extends the duration by 1s.

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
-- Headshotting a Witch Hunted enemy extends the isjya aura's duration by 1s
mod_api.insert_proc_function("tb_isjya_refresh_animosity_on_headshot", function (owner_unit, buff, params)
	if not Unit.alive(owner_unit) or not (is_server() or is_local(owner_unit)) then
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

	local owner_buff_extension = ScriptUnit.extension(owner_unit, "buff_system")
	local aura_buff = owner_buff_extension:get_buff_type("tb_isjya_aura")

	if aura_buff and aura_buff.duration then
		local t = Managers.time:time("game")
		local remaining = math.max(0, aura_buff.start_time + aura_buff.duration - t)

		aura_buff.start_time = t
		aura_buff.duration = remaining + 1
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
mod_api.insert_text("victor_captain_activated_ability_stagger_ping_debuff_desc", "Apply Witch Hunt to all enemies within Animosity's range and all specials. Headshotting Witch-Hunted enemies extends the duration by 1s.")

--[[ Ping All Specials on WHC ISJYA ULT ]]
local PING_DURATION = 15
local marked_enemies = {}

do
	local r, g, b = color_presets.resolve_color("tb_isjya_ping_outline_color_group", "tb_special_tag_color_r", "tb_special_tag_color_g", "tb_special_tag_color_b", 227, 4, 4)

	OutlineSettings.colors.tb_judged_special = {
		pulsate = false,
		pulse_multiplier = 50,
		color = { 255, r, g, b }, -- alpha, r, g, b
	}
end
OutlineSettings.templates.tb_judged_special = {
	method = "ai_alive",
	priority = 15,
	outline_color = OutlineSettings.colors.tb_judged_special,
	flag = OutlineSettings.flags.non_wall_occluded,
}

-- Update outline color only when a setting actually changes
mod:add_setting_changed_function(function ()
	local color = OutlineSettings.colors.tb_judged_special.color
	local r, g, b = color_presets.resolve_color("tb_isjya_ping_outline_color_group", "tb_special_tag_color_r", "tb_special_tag_color_g", "tb_special_tag_color_b", 227, 4, 4)

	color[2], color[3], color[4] = r, g, b

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

-- Reveals/re-reveals every special tracked by the proximity system and applies Witch Hunt (+ Templar's Knowledge)
local function apply_isjya_special_marks(attacker_unit, has_templars_knowledge)
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
end

-- Applies Witch Hunt (+ Templar's Knowledge) to every enemy within radius of position.
local function apply_isjya_radius_debuff(attacker_unit, position, radius, has_templars_knowledge)
	if not Managers.state.network.is_server then
		return
	end

	local nearby_enemy_units = FrameTable.alloc_table()
	local proximity_system = Managers.state.entity:system("proximity_system")
	local broadphase = proximity_system.enemy_broadphase

	Broadphase.query(broadphase, position, radius, nearby_enemy_units)

	local buff_system = Managers.state.entity:system("buff_system")

	for _, enemy_unit in pairs(nearby_enemy_units) do
		if ALIVE[enemy_unit] then
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

-- isjya aura: while active, every 3s re-runs the marking/debuff
mod_api.insert_buff_function("tb_isjya_aura_pulse", function (unit, buff, params, world)
	if not HEALTH_ALIVE[unit] then
		return
	end

	local talent_extension = ScriptUnit.has_extension(unit, "talent_system")
	local has_templars_knowledge = talent_extension and talent_extension:has_talent("victor_witchhunter_improved_damage_taken_ping")

	apply_isjya_special_marks(unit, has_templars_knowledge)
	apply_isjya_radius_debuff(unit, POSITION_LOOKUP[unit], buff.range, has_templars_knowledge)
end)
local ISJYA_AURA_DURATION = 6
mod_api.insert_talent_buff_template("witch_hunter", "tb_isjya_aura", {
	icon = "victor_captain_activated_ability_stagger_ping_debuff",
	duration = ISJYA_AURA_DURATION,
	range = 10, -- Animosity's explosion radius
	update_func = "tb_isjya_aura_pulse",
	update_frequency = 3,
})

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

	apply_isjya_special_marks(attacker_unit, has_templars_knowledge)

	-- Add ISJYA aura - if recasting while the old one is still active, reset
	if Managers.state.network.is_server then
		local buff_extension = ScriptUnit.extension(attacker_unit, "buff_system")
		local existing_aura = buff_extension:get_buff_type("tb_isjya_aura")

		if existing_aura then
			-- Duration drifts upward with each headshot extension (see the
			-- headshot proc above), so a recast must reset it back to base,
			-- not just re-anchor start_time.
			existing_aura.start_time = Managers.time:time("game")
			existing_aura.duration = ISJYA_AURA_DURATION
		else
			mod_api.add_buff(attacker_unit, "tb_isjya_aura")
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



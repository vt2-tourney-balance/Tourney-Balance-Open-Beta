local mod = get_mod("TourneyBalance")
local mod_api = require("scripts/mods/TourneyBalance/_api/_mod_api")

--[[
	$BEGIN_TB
		---
		## Witch Hunter Captain
		### Passive
		**Witch-Hunt**
		- Tagging only applies Witch Hunt to man-sized enemies (not Lords, Monsters or super-armoured enemies).

		### Talents
		**Templar's Knowledge**
		- Duration increased to 15s (from 5s).
		- Increased bonus damage taken to 7% (from 5%).
		- Tagging applies Witch Hunt to all enemies except Lords and Monsters.

		**I Shall Judge You All**
		- Headshots (melee and ranged) also apply Witch Hunt (and Templar's Knowledge) to all enemies hit, including Lords and Monsters.

		**Fervency**
		- Duration increased to 6s (from 6s).

		**The Unending Hunt**
		- Decreased crit chance granted to team to 10% (from 25%)
	$END_TB
]]


--[[

	WHC Passive

]]
local WITCH_HUNT_BUFF = "defence_debuff_enemies"
local TEMPLARS_KNOWLEDGE_TALENT = "victor_witchhunter_improved_damage_taken_ping"

-- Tagging only applies Witch Hunt to man-sized enemies (no Lords, Monsters or super-armoured enemies).
-- Templar's Knowledge extends it to every enemy except Lords and Monsters.
-- Only the tag is gated: the shared buff template is untouched (Huntsman, ISJYA's explosion and headshots hit
-- everything).
local function can_be_witch_hunted(enemy_unit, has_templars_knowledge)
	local breed = Unit.get_data(enemy_unit, "breed")

	if not breed or breed.boss then
		return false
	end

	return has_templars_knowledge or not breed.primary_armor_category
end

-- Tag: vanilla adds Witch Hunt (+ Templar's Knowledge) for every WHC on the pinger's side, now gated per enemy
mod:hook_origin(PingTargetExtension, "_add_witch_hunter_buff", function (self, pinger_unit)
	if not Managers.state.network.is_server then
		return
	end

	local buff_extension = self._buff_extension

	if not buff_extension then
		return
	end

	local side = Managers.state.side.side_by_unit[pinger_unit]

	if not side then
		return
	end

	local enemy_unit = self._unit
	local player_and_bot_units = side.PLAYER_AND_BOT_UNITS

	for i = 1, #player_and_bot_units do
		local player_unit = player_and_bot_units[i]
		local career_extension = ScriptUnit.has_extension(player_unit, "career_system")

		if career_extension and career_extension:career_name() == "wh_captain" then
			local talent_extension = ScriptUnit.has_extension(player_unit, "talent_system")
			local has_templars_knowledge = talent_extension and talent_extension:has_talent(TEMPLARS_KNOWLEDGE_TALENT)

			if can_be_witch_hunted(enemy_unit, has_templars_knowledge) then
				buff_extension:add_buff(WITCH_HUNT_BUFF)

				if has_templars_knowledge then
					buff_extension:add_buff(TEMPLARS_KNOWLEDGE_TALENT)
				end
			end
		end
	end
end)
mod_api.insert_text("career_passive_desc_wh_3a_2", "Tagged man-sized enemies take an additional 20% damage. Does not stack with similar effects.")

--[[
	Templar's Knowledge
]]
-- Lets tagging apply Witch Hunt to every enemy except Lords and Monsters (see can_be_witch_hunted above)
-- Duration increase
mod_api.update_talent_buff_template("witch_hunter", "victor_witchhunter_improved_damage_taken_ping", {
	duration = 15, -- 5
	multiplier = 0.1, -- 0.05
})
mod_api.update_talent("wh_captain", 4, 1, {
	description = "victor_witchhunter_improved_damage_taken_ping_desc",
	description_values = {},
})
mod_api.insert_text("victor_witchhunter_improved_damage_taken_ping_desc", "Witch Hunt causes enemies to take an additional 10.0% damage. Tagging applies Witch Hunt to all enemies except Lords and Monsters.")

--[[
	I Shall Judge You All
]]
-- Vanilla: Animosity's explosion applies Witch Hunt (+ Templar's Knowledge) to every enemy hit.
-- Added: headshots (melee or ranged) apply Witch Hunt (+ Templar's Knowledge) to every enemy
local function is_headshot(params)
	local hit_zone_name = params[3]

	return hit_zone_name == "head" or hit_zone_name == "neck"
end

mod_api.insert_proc_function("tb_isjya_witch_hunt_on_melee_headshot", function (owner_unit, buff, params)
	local hit_unit = params[1]

	if not Managers.player.is_server or not ALIVE[owner_unit] or not ALIVE[hit_unit] or not is_headshot(params) then
		return
	end

	local hit_unit_buff_extension = ScriptUnit.has_extension(hit_unit, "buff_system")

	if not hit_unit_buff_extension then
		return
	end

	hit_unit_buff_extension:add_buff(WITCH_HUNT_BUFF)

	local talent_extension = ScriptUnit.has_extension(owner_unit, "talent_system")

	if talent_extension and talent_extension:has_talent(TEMPLARS_KNOWLEDGE_TALENT) then
		hit_unit_buff_extension:add_buff(TEMPLARS_KNOWLEDGE_TALENT)
	end
end)
mod_api.insert_talent_buff_template("witch_hunter", "tb_isjya_witch_hunt_on_melee_headshot", {
	buff_func = "tb_isjya_witch_hunt_on_melee_headshot",
	event = "on_hit",
})
mod_api.update_talent("wh_captain", 6, 1, {
	buffer = "server",
	buffs = {
		"tb_isjya_witch_hunt_on_melee_headshot",
	},
	description = "victor_captain_activated_ability_stagger_ping_debuff_desc",
	description_values = {},
})
mod_api.insert_text("victor_captain_activated_ability_stagger_ping_debuff_desc", "Apply Witch Hunt to all enemies hit by Animosity or headshots.")

--[[
	Unending Hunt
]]
-- Teammates' crit chance reduced to 25% only when the caster has Unending Hunt (6-3); the caster keeps 25%
local function is_unending_hunt_ally(unit, params)
	local caster_unit = params and params.attacker_unit

	if not caster_unit or caster_unit == unit then
		return false
	end

	local talent_extension = ScriptUnit.has_extension(caster_unit, "talent_system")

	return talent_extension and talent_extension:has_talent("victor_witchhunter_activated_ability_refund_cooldown_on_enemies_hit") or false
end

do
	local crit_buff_template = TalentBuffTemplates.witch_hunter.victor_witchhunter_activated_ability_crit_buff
	local sub_buffs = crit_buff_template.buffs
	local vanilla_sub_buff = sub_buffs[1]

	vanilla_sub_buff.apply_condition = function (unit, template, params)
		return not is_unending_hunt_ally(unit, params)
	end

	-- Distinct name so num_buff_type/max_stacks don't collide with the vanilla sub-buff
	local unending_hunt_sub_buff = table.clone(vanilla_sub_buff)
	unending_hunt_sub_buff.name = "tb_unending_hunt_crit_buff"
	unending_hunt_sub_buff.bonus = 0.10 -- 0.25
	unending_hunt_sub_buff.apply_condition = function (unit, template, params)
		return is_unending_hunt_ally(unit, params)
	end

	sub_buffs[2] = unending_hunt_sub_buff
	BuffTemplates.victor_witchhunter_activated_ability_crit_buff = crit_buff_template
end
mod_api.update_talent("wh_captain", 6, 3, {
	description = "victor_witchhunter_activated_ability_refund_cooldown_on_enemies_hit_desc",
	description_values = {},
})
mod_api.insert_text("victor_witchhunter_activated_ability_refund_cooldown_on_enemies_hit_desc", "Hitting at least 10 enemies with Animosity refunds 40.0% of its cooldown. Critical hit chance bonus for allies is reduced to 10.0%.")


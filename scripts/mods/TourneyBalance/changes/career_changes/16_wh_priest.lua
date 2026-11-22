local mod = get_mod("TourneyBalance")
local mod_api = require("scripts/mods/TourneyBalance/_api/_mod_api")

--[[
	$BEGIN_TB
		---
		## Warrior Priest
		### Career Ability
		- Reworded tooltip.
		- Lowered burn tick armor_modifier.attack vs all enemies by 50%.
		- Lowered initial explosion power_distribution.attack by 60%.
		- Lowered initial explosion armor_modifier.attack vs. non-Monster by 50%.
		- Increased initial explosion armor_modifier.attack vs. Monster by 700%.

		### Talents
		**Unstoppable Force**
		- Also grants immovable for 4s: while grounded, enemy collisions and pushes no longer displace him (unless disabled).

		**Rising Judgement**
		- Light attacks now grant a stack for every enemy hit (instead of only the first).
		- Heavy attacks can no longer be interrupted.

		**Blazing Bright**
		- Fury gain damage taken increased to 1 (from 0.6)

		**See My Wrath**
		- Smite now deals at least 40 damage to the first enemy hit by an attack (40% of the attack's damage if higher).

		**From Fury, Fortitude**
		- Team changed to Kill THP/4 as percentage of each hero's max health (from Kill THP/2 as flat health).

		**Prayer of Vengeance**
		- Increased power vs monsters to 25% (from 15%).

		**Prayer of Might**
		- No longer an aura. Instead, the Shield of Faith explosion now heavily staggers every enemy except bosses (instead of granting the party 25% stagger power).

		**Unyielding Blessing**
		- Duration reduced to 7s (from 10s).
	$END_TB
]]

--[[

	Ultimate

]]
-- Reworded - base game's own wording here was hard to parse
mod_api.insert_text("career_active_desc_wh_priest", "Saltzpyre imbues himself or an ally with a shield, rendering them immune to damage for 5 seconds. Upon expiring, the shield explodes, inflicting damage on nearby enemies. Hold to target allies.")

-- Initial explosion damage
local nuke_explosion = DamageProfileTemplates.victor_priest_activated_ability_nuke_explosion
nuke_explosion.default_target.power_distribution.attack = 0.1 -- 0.25
nuke_explosion.armor_modifier.attack = {
	0.5, -- 1, infantry
	0.1, -- 0.2, armored
	12, -- 1.5, monster
	1, -- 1, player
	0.375, -- 0.75, berserker
	0, -- 0, super armor
}

-- Burn tick
local nuke_dot_profile = table.clone(DamageProfileTemplates.burning_dot)
nuke_dot_profile.default_target.armor_modifier.attack = {
	0.5, -- 1, infantry
	0.375, -- 0.75, armored
	1.5, -- 3, monster
	1, -- 1, player
	0.5, -- 1, berserker
	0.25, -- 0.5, super armor
}
NewDamageProfileTemplates.tb_victor_priest_nuke_dot = nuke_dot_profile
BuffTemplates.victor_priest_nuke_dot.buffs[1].damage_profile = "tb_victor_priest_nuke_dot"
--BuffTemplates.victor_priest_nuke_dot.buffs[1].duration = 5
--BuffTemplates.victor_priest_nuke_dot.buffs[1].time_between_dot_damages = 0.7

--[[

	Talents

]]
--[[
	Unstoppable Force
]]
-- unmovable for 4s wrt. enemy collision and pushes
local UNMOVABLE_PERK = "tb_unmovable"

BuffTemplates.victor_priest_2_1_buff.buffs[1].perks = {
	"slayer_stamina", -- vanilla: halved push cost
	UNMOVABLE_PERK,
}

mod:hook(PlayerUnitLocomotionExtension, "add_external_velocity", function (func, self, ...)
	local unit = self.unit
	local buff_extension = ScriptUnit.has_extension(unit, "buff_system")

	if self.on_ground and buff_extension and buff_extension:has_buff_perk(UNMOVABLE_PERK) then
		local status_extension = ScriptUnit.has_extension(unit, "status_system")

		if status_extension and not status_extension:is_disabled() then
			return
		end
	end

	return func(self, ...)
end)

mod_api.update_talent("wh_priest", 2, 1, {
	description_values = {},
})
mod_api.insert_text("victor_priest_2_1_desc", "Striking 3 enemies at once grants halved push cost and immovable while on ground for 4 seconds.")

--[[
	Rising Judgement
]]
-- Light attacks grant a stack per enemy hit
mod_api.insert_proc_function("tb_victor_priest_2_2_add_stack", function (owner_unit, buff, params)
	if not ALIVE[owner_unit] then
		return
	end

	local target_number = params[4]

	if target_number > 1 and params[2] ~= "light_attack" then
		return
	end

	local buff_ids = buff.buff_ids

	if not buff_ids then
		buff_ids = {}
		buff.buff_ids = buff_ids
	end

	local buff_extension = ScriptUnit.extension(owner_unit, "buff_system")
	local buff_id = buff_extension:add_buff(buff.template.buff_to_add)

	if buff_id then -- nil at max stacks
		buff_ids[#buff_ids + 1] = buff_id
	end
end)
mod_api.update_talent_buff_template("witch_hunter", "victor_priest_2_2", {
	buff_func = "tb_victor_priest_2_2_add_stack", -- victor_priest_add_buff_first_target
})

-- Heavy attacks can't be interrupted
mod_api.insert_talent_buff_template("witch_hunter", "tb_victor_priest_2_2_uninterruptible_heavy", {
	max_stacks = 1,
	perks = {
		"uninterruptible_heavy"
	}
})
mod_api.update_talent("wh_priest", 2, 2, {
	buffs = {
		"victor_priest_2_2",
		"victor_priest_2_2_remover",
		"tb_victor_priest_2_2_uninterruptible_heavy",
	},
	description_values = {}, -- plain % in the text below
})
mod_api.insert_text("victor_priest_2_2_desc", "Hits increase the power of the next charged attack by 8%. Max stacks 5. Heavy attacks can no longer be interrupted.")

--[[
	Blazing Bright
]]
CareerConstants.wh_priest.talent_4_1_fury_gain_mult = 1 -- 0.6

--[[
	See My Wrath
]]
-- Upgraded smite stays vanilla (40% of the hit's damage), but the first enemy hit by an attack takes at least 40.
-- The smite deals buff.value * damage_multiplier on removal, so the minimum is applied by raising the stored hit
-- damage to 40 / multiplier. Hits that dealt no damage still don't smite, like vanilla.
-- Each hand of a dual weapon is its own attack (own target count), so the minimum can land once per weapon.
local SEE_MY_WRATH_TALENT = "victor_priest_4_2_new"
local SEE_MY_WRATH_MIN_SMITE_DAMAGE = 40
local SMITE_UPGRADED_MIN_HIT_DAMAGE = SEE_MY_WRATH_MIN_SMITE_DAMAGE / BuffTemplates.victor_priest_passive_smite_upgraded.buffs[1].damage_multiplier -- 40 / 0.4

-- Copy of vanilla add_buff_to_hit_enemy (buff_settings_bless.lua, only used by Righteous Fury's smite) plus the minimum
mod_api.insert_proc_function("add_buff_to_hit_enemy", function (owner_unit, buff, params)
	local hit_unit = params[1]
	local attack_type = params[7]

	if not ALIVE[owner_unit] or not ALIVE[hit_unit] or (attack_type ~= "light_attack" and attack_type ~= "heavy_attack") then
		return
	end

	local target_buff_extension = ScriptUnit.has_extension(hit_unit, "buff_system")

	if not target_buff_extension then
		return
	end

	local template = buff.template
	local buff_to_add = template.buff_to_add
	local hit_damage = params[3]
	local talent_extension = ScriptUnit.has_extension(owner_unit, "talent_system")

	if talent_extension and talent_extension:has_talent(SEE_MY_WRATH_TALENT) then
		buff_to_add = template.buff_to_add_upgraded

		if params[8] == 1 and hit_damage and hit_damage > 0 and hit_damage < SMITE_UPGRADED_MIN_HIT_DAMAGE then -- first target
			hit_damage = SMITE_UPGRADED_MIN_HIT_DAMAGE
		end
	end

	target_buff_extension:add_buff(buff_to_add, {
		external_optional_value = hit_damage,
		attacker_unit = owner_unit,
	})
end)

mod_api.update_talent("wh_priest", 4, 2, {
	description_values = {}, -- plain % in the text below
})
mod_api.insert_text("victor_priest_4_2_desc_new", "Shield of Faith grants Victor 60% Fury. Smite now deals 40% of the attack's damage, and at least 40 damage to the first enemy hit.")

--[[
	From Fury, Fortitude
]]
-- Party heal during Righteous Fury: (bloodlust / 4)% of each hero's max health, instead of a flat bloodlust * 0.5.
-- Replaces vanilla victor_priest_4_3_heal_on_kill (buff_settings_bless.lua); the Fury gain part is unchanged.
local FROM_FURY_FORTITUDE_HEAL_PERCENT_PER_BLOODLUST = 0.01 / 4

mod_api.insert_proc_function("victor_priest_4_3_heal_on_kill", function (owner_unit, buff, params)
	local owner_player = Managers.player:owner(owner_unit)

	if owner_player and not owner_player.remote then
		local talent_extension = ScriptUnit.extension(owner_unit, "talent_system")

		if talent_extension:has_talent("victor_priest_4_3") then
			local career_extension = ScriptUnit.extension(owner_unit, "career_system")
			local career_passive = career_extension:get_passive_ability_by_name("wh_priest")

			career_passive:modify_resource_percent(buff.template.percent_fury_to_gain)
		end
	end

	if not Managers.state.network.is_server then
		return
	end

	local buff_extension = ScriptUnit.extension(owner_unit, "buff_system")

	if not buff_extension or not buff_extension:has_buff_type("victor_priest_passive_aftershock") then
		return
	end

	local killing_blow_data = params[1]
	local breed = params[2]

	if not killing_blow_data or not breed or breed.is_hero then
		return
	end

	local heal_fraction = (breed.bloodlust_health or 0) * FROM_FURY_FORTITUDE_HEAL_PERCENT_PER_BLOODLUST

	if heal_fraction <= 0 then
		return
	end

	local side = Managers.state.side.side_by_unit[owner_unit]

	if not side then
		return
	end

	local player_and_bot_units = side.PLAYER_AND_BOT_UNITS

	for i = 1, #player_and_bot_units do
		local unit = player_and_bot_units[i]
		local health_extension = ALIVE[unit] and ScriptUnit.has_extension(unit, "health_system")

		if health_extension then
			DamageUtils.heal_network(unit, owner_unit, health_extension:get_max_health() * heal_fraction, "career_passive")
		end
	end
end)
mod_api.update_talent("wh_priest", 4, 3, {
	description_values = {}, -- plain % in the text below
})
mod_api.insert_text("victor_priest_4_3_desc_new", "Each kill now grants 2% Fury and during Righteous Fury restores Health to the party based on max health.")

--[[
	Prayer of Vengeance
]]
-- Party power vs monsters (armor 3, so hookrats too)
mod_api.update_talent_buff_template("witch_hunter", "victor_priest_5_1_buff", {
	multiplier = 0.25, -- 0.15
})
mod_api.update_talent("wh_priest", 5, 1, { -- update description
	description_values = {
		{
			value_type = "percent",
			value = 0.25, -- buff_tweak_data.victor_priest_5_1_buff.multiplier
		},
	},
})

--[[
	Prayer of Might
]]
-- No longer an aura. Instead the Shield of Faith explosion heavily staggers every non-boss enemy.
local TB_PRAYER_OF_MIGHT_TALENT = "victor_priest_5_2"
local NUKE_EXPLOSION_TEMPLATE = "victor_priest_activated_ability_nuke"
local NUKE_STAGGER_EXPLOSION_TEMPLATE = "tb_victor_priest_activated_ability_nuke_stagger"
local NUKE_STAGGER_DAMAGE_PROFILE = "tb_victor_priest_nuke_explosion_stagger"

mod_api.update_talent("wh_priest", 5, 2, {
	buffs = {},
	description_values = {},
})
-- Only the description; the name stays the base game's "Prayer of Might"
mod_api.insert_text(TB_PRAYER_OF_MIGHT_TALENT .. "_desc", "Blesses Shield of Faith with increased stagger power.")

-- Heavy stagger on every non-boss enemy, if is_explosion = false
local function make_heavy_stagger_profile(profile)
	local heavy_profile = table.clone(profile)
	heavy_profile.is_explosion = false
	heavy_profile.armor_modifier.impact = { -- vanilla is the same for both profiles
		10, -- 1, infantry
		10, -- 0.5, armored
		10, -- 1, monster
		1, -- 1, player
		10, -- 0.75, berserker
		10, -- 0.5, super armor
	}

	return heavy_profile
end

-- Same damage as the normal explosion (cloned after the edits above)
NewDamageProfileTemplates[NUKE_STAGGER_DAMAGE_PROFILE] = make_heavy_stagger_profile(nuke_explosion)

-- Outer ring (between max_damage_radius 3 and radius 5) uses the glance profile, which is shared with other abilities, so it gets its own copy too
local NUKE_STAGGER_GLANCE_DAMAGE_PROFILE = "tb_victor_priest_nuke_explosion_stagger_glance"
NewDamageProfileTemplates[NUKE_STAGGER_GLANCE_DAMAGE_PROFILE] = make_heavy_stagger_profile(DamageProfileTemplates[ExplosionTemplates[NUKE_EXPLOSION_TEMPLATE].explosion.damage_profile_glance]) -- overcharge_explosion_glance_ability

-- The area damage system looks the damage profile up by explosion template name, so the upgrade needs its own template.
local nuke_stagger_template = table.clone(ExplosionTemplates[NUKE_EXPLOSION_TEMPLATE])
nuke_stagger_template.name = NUKE_STAGGER_EXPLOSION_TEMPLATE
nuke_stagger_template.explosion.damage_profile = NUKE_STAGGER_DAMAGE_PROFILE
nuke_stagger_template.explosion.damage_profile_glance = NUKE_STAGGER_GLANCE_DAMAGE_PROFILE
ExplosionTemplates[NUKE_STAGGER_EXPLOSION_TEMPLATE] = nuke_stagger_template

-- NetworkLookup tables error on a missing key, so check with rawget
local explosion_lookup = NetworkLookup.explosion_templates
if not rawget(explosion_lookup, NUKE_STAGGER_EXPLOSION_TEMPLATE) then
	local index = #explosion_lookup + 1
	explosion_lookup[index] = NUKE_STAGGER_EXPLOSION_TEMPLATE
	explosion_lookup[NUKE_STAGGER_EXPLOSION_TEMPLATE] = index
end

mod:add_create_explosion_wrapper(function (func, world, attacker_unit, impact_position, rotation, explosion_template, ...)
	if explosion_template and explosion_template.name == NUKE_EXPLOSION_TEMPLATE and ALIVE[attacker_unit] then
		local talent_extension = ScriptUnit.has_extension(attacker_unit, "talent_system")

		if talent_extension and talent_extension:has_talent(TB_PRAYER_OF_MIGHT_TALENT) then
			explosion_template = ExplosionUtils.get_template(NUKE_STAGGER_EXPLOSION_TEMPLATE)
		end
	end

	return func(world, attacker_unit, impact_position, rotation, explosion_template, ...)
end)



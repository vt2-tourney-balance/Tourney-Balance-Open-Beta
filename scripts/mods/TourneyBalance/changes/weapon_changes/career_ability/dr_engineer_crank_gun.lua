local mod = get_mod("TourneyBalance")

--[[
	Outcast Engineer's Steam-Assisted Crank Gun (patch notes are with the career in career_changes/08_dr_engineer.lua)
]]
local CRANK_GUN_WEAPONS = { "bardin_engineer_career_skill_weapon", "bardin_engineer_career_skill_weapon_special" }
local TB_ENGINEER_AIMED_SPREAD = "tb_engineer_aimed"
local TB_ENGINEER_AIMED_SHOT = "tb_engineer_ability_shot_aimed"
local TB_ENGINEER_AIMED_SHOT_ARMOR_PIERCE = "tb_engineer_ability_shot_armor_pierce_aimed"
local TB_ENGINEER_AIMED_SUB_ACTIONS = { "aimed_fire", "aimed_base_fire", "aimed_armor_pierce_fire" }
-- Hitscan range of a shot; the crank gun has none set and falls back to ActionRangedBase's 30m, which made aimed shots vanish.
local TB_ENGINEER_AIMED_RANGE = 100
-- Vanilla handgun falloff
local TB_ENGINEER_AIMED_DROPOFF_RANGES = {
	dropoff_end = 50,
	dropoff_start = 30,
}

--[[
	Baseline
]]
Weapons.bardin_engineer_career_skill_weapon.dodge_count = 3 -- 1
Weapons.bardin_engineer_career_skill_weapon_special.dodge_count = 3 -- 1

-- Linked Compression Chamber's instant windup is baseline for every crank gun variant.
-- Mirrors the talent branch in ActionCareerDREngineerSpin / ActionCareerDREngineer; the talent's
-- 30% max_rps boost is applied before this runs, so talented players keep their higher cap.
local function starting_windup()
	if Managers.mechanism:current_mechanism_name() == "versus" then
		return CareerConstants.dr_engineer.talent_6_2_starting_rps_vs
	end

	return CareerConstants.dr_engineer.talent_6_2_starting_rps
end

-- The spin actions don't handle spread_template_override themselves (only ActionRangedBase does), so the right click aim
-- applies and resets it here, which makes the crosshair show the aimed spread while aiming. The same hook sets the
-- baseline starting windup, since a function can only be hooked once.
mod:hook_safe(ActionCareerDREngineerSpin, "client_owner_start_action", function (self, new_action, t)
	self._current_windup = starting_windup()

	local spread_template_override = new_action.spread_template_override

	if spread_template_override then
		local spread_extension = ScriptUnit.has_extension(self.weapon_unit, "spread_system")

		if spread_extension then
			spread_extension:override_spread_template(spread_template_override)
		end
	end
end)

mod:hook_safe(ActionCareerDREngineerSpin, "finish", function (self, reason)
	if self.current_action.spread_template_override then
		local spread_extension = ScriptUnit.has_extension(self.weapon_unit, "spread_system")

		if spread_extension then
			spread_extension:reset_spread_template()
		end
	end
end)

mod:hook_safe(ActionCareerDREngineer, "client_owner_start_action", function (self, new_action, t)
	self._current_rps = math.max(self._current_rps, self._max_rps * starting_windup())
end)

--[[
	Right click aim
]]
-- Only the left click spin sets the barrel rotation animation, so the right click aim never showed the full rotation speed.
for _, weapon_name in ipairs(CRANK_GUN_WEAPONS) do
	local action_two = Weapons[weapon_name].actions.action_two

	action_two.default.fp_speed_anim_variable = "barrel_spin_speed"
	action_two.charged.fp_speed_anim_variable = "barrel_spin_speed"
	action_two.default.spread_template_override = TB_ENGINEER_AIMED_SPREAD
	action_two.charged.spread_template_override = TB_ENGINEER_AIMED_SPREAD
end

--[[
	Gromril Plated Shots
]]
-- Copied damage profile from Handgun (vanilla). Armor order is unarmored, armored, resistant, player, berserker, super armor.
-- Has to run before the aimed armor piercing profile below is cloned from it.
local armor_pierce_profile = DamageProfileTemplates.engineer_ability_shot_armor_pierce

armor_pierce_profile.critical_strike.attack_armor_power_modifer = { 1, 1.4, 1.5, 1, 0.75, 0.6 } -- { 1, 1, 1, 1, 1, 0.5 }
armor_pierce_profile.critical_strike.impact_armor_power_modifer = { 1, 1, 1, 1, 1, 1 } -- { 1, 1, 1, 1, 1, 0.5 }
armor_pierce_profile.armor_modifier_near.attack = { 1, 1.2, 1.5, 1, 0.75, 0.5 } -- { 1, 1, 1, 1, 0.5, 0.4 }
armor_pierce_profile.armor_modifier_near.impact = { 1, 1, 1, 1, 1, 1 } -- { 1, 1, 1, 1, 1, 0.4 }
armor_pierce_profile.armor_modifier_far.attack = { 1, 1, 1, 1, 0.75, 0.25 } -- { 1, 1, 1, 1, 0.5, 0.4 }
armor_pierce_profile.armor_modifier_far.impact = { 1, 1, 1, 1, 1, 0.75 } -- { 1, 1, 1, 1, 1, 0.4 }
armor_pierce_profile.cleave_distribution.attack = 0.3 -- 0.25
armor_pierce_profile.cleave_distribution.impact = 0.3 -- 0.25
armor_pierce_profile.default_target.attack_template = "shot_sniper" -- "shot_repeating_handgun"
armor_pierce_profile.default_target.boost_curve_type = "smiter_curve" -- "linesman_curve"
armor_pierce_profile.default_target.boost_curve_coefficient = 1 -- 0.6
armor_pierce_profile.default_target.boost_curve_coefficient_headshot = 1
armor_pierce_profile.default_target.headshot_boost_boss = 0.5
armor_pierce_profile.default_target.power_distribution_near.attack = 1 -- 0.48
armor_pierce_profile.default_target.power_distribution_near.impact = 0.5 -- 0.3
armor_pierce_profile.default_target.power_distribution_far.attack = 0.8 -- 0.36
armor_pierce_profile.default_target.power_distribution_far.impact = 0.5 -- 0.25

--[[
	Aimed fire (holding right click)
]]
-- Shots fired out of the right click aim (action_two.charged -> action_one) use their own sub actions, so they get
-- their own spread and damage profile without touching the left click shots.
local pinpoint = { max_pitch = 0, max_yaw = 0 }
SpreadTemplates[TB_ENGINEER_AIMED_SPREAD] = {
	continuous = {
		still = pinpoint,
		moving = pinpoint,
		crouch_still = pinpoint,
		crouch_moving = pinpoint,
		zoomed_still = pinpoint,
		zoomed_moving = pinpoint,
		zoomed_crouch_still = pinpoint,
		zoomed_crouch_moving = pinpoint,
	},
	immediate = {
		being_hit = { immediate_pitch = 1.4, immediate_yaw = 1.4 }, -- official aim punch when taking damage
		shooting = { immediate_pitch = 0, immediate_yaw = 0 },
	},
}

local function make_aimed_damage_profile(base_profile_name)
	local profile = table.clone(DamageProfileTemplates[base_profile_name])

	profile.default_target.range_modifier_settings = TB_ENGINEER_AIMED_DROPOFF_RANGES

	return profile
end
NewDamageProfileTemplates[TB_ENGINEER_AIMED_SHOT] = make_aimed_damage_profile("engineer_ability_shot")
NewDamageProfileTemplates[TB_ENGINEER_AIMED_SHOT_ARMOR_PIERCE] = make_aimed_damage_profile("engineer_ability_shot_armor_pierce")

for _, weapon_name in ipairs(CRANK_GUN_WEAPONS) do
	local actions = Weapons[weapon_name].actions
	local action_one = actions.action_one

	local aimed_base_fire = table.shallow_copy(action_one.base_fire)
	aimed_base_fire.damage_profile = TB_ENGINEER_AIMED_SHOT
	aimed_base_fire.spread_template_override = TB_ENGINEER_AIMED_SPREAD
	aimed_base_fire.range = TB_ENGINEER_AIMED_RANGE
	action_one.aimed_base_fire = aimed_base_fire

	local aimed_armor_pierce_fire = table.shallow_copy(action_one.armor_pierce_fire)
	aimed_armor_pierce_fire.damage_profile = TB_ENGINEER_AIMED_SHOT_ARMOR_PIERCE
	aimed_armor_pierce_fire.spread_template_override = TB_ENGINEER_AIMED_SPREAD
	aimed_armor_pierce_fire.range = TB_ENGINEER_AIMED_RANGE
	action_one.aimed_armor_pierce_fire = aimed_armor_pierce_fire

	local aimed_fire = table.shallow_copy(action_one.fire)
	aimed_fire.conditional_actions = {
		{
			sub_action = "aimed_armor_pierce_fire",
			condition = action_one.fire.conditional_actions[1].condition,
		},
	}
	aimed_fire.default_action = { sub_action = "aimed_base_fire" }
	action_one.aimed_fire = aimed_fire

	for _, chain_action in ipairs(actions.action_two.charged.allowed_chain_actions) do
		if chain_action.action == "action_one" and chain_action.sub_action == "fire" then
			chain_action.sub_action = "aimed_fire"
		end
	end
end

-- Sub action names are synced by index; the base game only fills this lookup from the vanilla weapon templates.
for _, sub_action_name in ipairs(TB_ENGINEER_AIMED_SUB_ACTIONS) do
	if not rawget(NetworkLookup.sub_actions, sub_action_name) then
		local index = #NetworkLookup.sub_actions + 1

		NetworkLookup.sub_actions[index] = sub_action_name
		NetworkLookup.sub_actions[sub_action_name] = index
	end
end

local mod = get_mod("TourneyBalance")

--[[
	Outcast Engineer's Steam-Assisted Crank Gun (patch notes are with the career in career_changes/08_dr_engineer.lua)
]]
local CRANK_GUN_WEAPONS = { "bardin_engineer_career_skill_weapon", "bardin_engineer_career_skill_weapon_special" }
local TB_ENGINEER_AIMED_SPREAD = "tb_engineer_aimed"
local TB_ENGINEER_AIMED_SHOT = "tb_engineer_ability_shot_aimed"
local TB_ENGINEER_AIMED_SHOT_ARMOR_PIERCE = "tb_engineer_ability_shot_armor_pierce_aimed"
local TB_ENGINEER_AIMED_SUB_ACTIONS = { "aimed_fire", "aimed_base_fire", "aimed_armor_pierce_fire" }
-- Hitscan range of every shot; the crank gun has none set and falls back to ActionRangedBase's 30m, which made bullets vanish.
local TB_ENGINEER_BULLET_RANGE = 100
local TB_ENGINEER_FIRE_SUB_ACTIONS = { "base_fire", "fast_fire", "armor_pierce_fire" }

--[[
	Baseline
]]
-- Linked Compression Chamber's instant windup is baseline for every crank gun variant.
local function starting_windup()
	if Managers.mechanism:current_mechanism_name() == "versus" then
		return CareerConstants.dr_engineer.talent_6_2_starting_rps_vs
	end

	return CareerConstants.dr_engineer.talent_6_2_starting_rps
end

mod:hook_safe(ActionCareerDREngineerSpin, "client_owner_start_action", function (self, new_action, t)
	self._current_windup = starting_windup()

	local spread_template_override = new_action.spread_template_override
	local spread_extension = spread_template_override and ScriptUnit.has_extension(self.weapon_unit, "spread_system")

	if spread_extension then
		spread_extension:override_spread_template(spread_template_override)
	end
end)

mod:hook_safe(ActionCareerDREngineerSpin, "finish", function (self, reason)
	local spread_extension = self.current_action.spread_template_override and ScriptUnit.has_extension(self.weapon_unit, "spread_system")

	if spread_extension then
		spread_extension:reset_spread_template()
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
armor_pierce_profile.armor_modifier_far.attack = { 1, 1, 1, 1, 0.75, 0.4 } -- { 1, 1, 1, 1, 0.5, 0.4 }
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

NewDamageProfileTemplates[TB_ENGINEER_AIMED_SHOT] = table.clone(DamageProfileTemplates.engineer_ability_shot)
NewDamageProfileTemplates[TB_ENGINEER_AIMED_SHOT_ARMOR_PIERCE] = table.clone(DamageProfileTemplates.engineer_ability_shot_armor_pierce)

local function make_aimed_sub_action(source_action, damage_profile)
	local aimed_action = table.shallow_copy(source_action)

	aimed_action.damage_profile = damage_profile
	aimed_action.spread_template_override = TB_ENGINEER_AIMED_SPREAD

	return aimed_action
end

for _, weapon_name in ipairs(CRANK_GUN_WEAPONS) do
	local actions = Weapons[weapon_name].actions
	local action_one = actions.action_one

	-- Before the aimed sub actions are copied from them, so those get the range too.
	for _, sub_action_name in ipairs(TB_ENGINEER_FIRE_SUB_ACTIONS) do
		local sub_action = action_one[sub_action_name]

		if sub_action then
			sub_action.range = TB_ENGINEER_BULLET_RANGE
		end
	end

	action_one.aimed_base_fire = make_aimed_sub_action(action_one.base_fire, TB_ENGINEER_AIMED_SHOT)
	action_one.aimed_armor_pierce_fire = make_aimed_sub_action(action_one.armor_pierce_fire, TB_ENGINEER_AIMED_SHOT_ARMOR_PIERCE)

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

local mod = get_mod("TourneyBalance")

-- handgun_template_2
Weapons.handgun_template_2.actions.action_one.default.total_time = 0.35 -- official: 0.5
Weapons.handgun_template_2.actions.action_one.default.damage_profile = "tb_bardin_handgun_shot" -- official: "shot_sniper"
Weapons.handgun_template_2.actions.action_one.zoomed_shot.allowed_chain_actions[1].start_time = 0.35 -- official: 0.6
Weapons.handgun_template_2.actions.action_one.zoomed_shot.damage_profile = "tb_bardin_handgun_shot" -- official: "shot_sniper"
Weapons.handgun_template_2.actions.action_one.zoomed_shot.total_time = 0.35 -- official: 0.8

NewDamageProfileTemplates.tb_bardin_handgun_shot = { -- official: shot_sniper
	charge_value = "instant_projectile",
	critical_strike = {
		attack_armor_power_modifer = {
			1,
			1.4,
			1.5,
			1,
			0.75,
			0.6,
		},
		impact_armor_power_modifer = {
			1,
			1,
			1,
			1,
			1,
			1,
		},
	},
	no_stagger_damage_reduction_ranged = true,
	armor_modifier_near = {
		attack = {
			1.01, -- official: 1, 1.465
			1.04, -- official: 1.2
			2.17, -- official: 1.5
			1,
			0.75,
			0.5,
		},
		impact = {
			1,
			1,
			1,
			1,
			1,
			1,
		},
	},
	armor_modifier_far = {
		attack = {
			1,
			1,
			1,
			1,
			0.75,
			0.25,
		},
		impact = {
			1,
			1,
			1,
			1,
			1,
			0.75,
		},
	},
	cleave_distribution = {
		attack = 0.3,
		impact = 0.3,
	},
	shield_break = true,
	default_target = {
		attack_template = "shot_sniper",
		boost_curve_type = "smiter_curve",
		boost_curve_coefficient_headshot = 1,
		boost_curve_coefficient = 1,
		headshot_boost_boss = 0.5,
		power_distribution_near = {
			attack = 1,
			impact = 0.5,
		},
		power_distribution_far = {
			attack = 0.8,
			impact = 0.5,
		},
		range_modifier_settings = {
			dropoff_end = 1e+02, -- official: 5e+01
			dropoff_start = 5e+01, -- official: 3e+01
		},
	},
	targets = {
	},
}
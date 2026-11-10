local mod = get_mod("TourneyBalance")

--[[
	2h Hammer (Kruber/Bardin)
]]
Weapons.two_handed_hammers_template_1.actions.action_one.heavy_attack_right.damage_profile = "tb_2h_hammer_heavy"
Weapons.two_handed_hammers_template_1.actions.action_one.heavy_attack_left.damage_profile = "tb_2h_hammer_heavy"
Weapons.two_handed_hammers_template_1.actions.action_one.light_attack_left.damage_profile = "tb_two_handed_hammer_light_1" -- official: "medium_blunt_smiter_2h_hammer"
Weapons.two_handed_hammers_template_1.actions.action_one.light_attack_right.damage_profile = "tb_two_handed_hammer_light_2" -- official: "medium_blunt_smiter_2h_hammer"
Weapons.two_handed_hammers_template_1.actions.action_one.light_attack_left_up.damage_profile = "tb_two_handed_hammer_light_3" -- official: "medium_blunt_smiter_2h_hammer_upper"
Weapons.two_handed_hammers_template_1.actions.action_one.light_attack_push_left_up.damage_profile = "tb_two_handed_hammer_push_attack" -- official: "heavy_blunt_tank_light", prev TB: "tb_2h_hammer_heavy"
Weapons.two_handed_hammers_template_1.actions.action_one.heavy_attack_right.anim_time_scale = 1.2
Weapons.two_handed_hammers_template_1.actions.action_one.heavy_attack_left.anim_time_scale = 1.2
Weapons.two_handed_hammers_template_1.actions.action_one.heavy_attack_right.hit_mass_count = HEAVY_LINESMAN_HIT_MASS_COUNT
Weapons.two_handed_hammers_template_1.actions.action_one.heavy_attack_left.hit_mass_count = HEAVY_LINESMAN_HIT_MASS_COUNT

NewDamageProfileTemplates.tb_2h_hammer_heavy = {
	stagger_duration_modifier = 1.8,
	critical_strike = {
		attack_armor_power_modifer = {
			1.3,
			0.6,
			2,
			1,
			1
		},
		impact_armor_power_modifer = {
			1,
			1,
			1,
			1,
			1
		}
	},
	charge_value = "heavy_attack",
	cleave_distribution = {
		attack = 0.3,
		impact = 0.8
	},
	default_target = {
		boost_curve_type = "tank_curve",
		attack_template = "blunt_tank",
		power_distribution = {
			attack = 0.05,
			impact = 0.125
		}
	},
	targets = {
		{
			boost_curve_type = "tank_curve",
			attack_template = "heavy_blunt_tank",
			power_distribution = {
				attack = 0.275,
				impact = 0.3
			},
			armor_modifier = {
				attack = {
					1.5,
					0.5,
					2,
					1,
					0.75
				},
				impact = {
					1.5,
					1,
					1,
					1,
					0.75
				}
			}
		},
		{
			boost_curve_type = "tank_curve",
			attack_template = "heavy_blunt_tank",
			power_distribution = {
				attack = 0.15,
				impact = 0.225
			}
		},
		{
			boost_curve_type = "tank_curve",
			attack_template = "blunt_tank",
			power_distribution = {
				attack = 0.075,
				impact = 0.2
			}
		}
	},
	armor_modifier = {
		attack = {
			1,
			0,
			1.5,
			1,
			0.75
		},
		impact = {
			1,
			1,
			1,
			1,
			0.75
		}
	}
}

NewDamageProfileTemplates.tb_two_handed_hammer_light_1 = { -- official: medium_blunt_smiter_2h_hammer
	armor_modifier = {
		attack = {
			1.1, -- official: 1
			0.8,
			2,
			1,
			0.75,
			1.1, -- official: 1
		},
		impact = {
			1,
			0.8,
			1,
			1,
			0.75,
		},
	},
	charge_value = "light_attack",
	critical_strike = "critical_strike_blunt_smiter_2h_hammer_H",
	cleave_distribution = "cleave_distribution_smiter_default",
	shield_break = true,
	default_target = {
		attack_template = "blunt_smiter",
		boost_curve_type = "smiter_curve",
		boost_curve_coefficient = 2,
		power_distribution = {
			attack = 0.4,
			impact = 0.25,
		},
	},
	targets = {
		[2] = {
			attack_template = "light_blunt_tank",
			boost_curve_type = "tank_curve",
			power_distribution = {
				attack = 0.1,
				impact = 0.1,
			},
		},
	},
}

NewDamageProfileTemplates.tb_two_handed_hammer_light_2 = { -- official: medium_blunt_smiter_2h_hammer
	armor_modifier = {
		attack = {
			1.1, -- official: 1
			0.8,
			2,
			1,
			0.75,
			1.15, -- official: 1
		},
		impact = {
			1,
			0.8,
			1,
			1,
			0.75,
		},
	},
	charge_value = "light_attack",
	critical_strike = "critical_strike_blunt_smiter_2h_hammer_H",
	cleave_distribution = "cleave_distribution_smiter_default",
	shield_break = true,
	default_target = {
		attack_template = "blunt_smiter",
		boost_curve_type = "smiter_curve",
		boost_curve_coefficient = 2,
		power_distribution = {
			attack = 0.4,
			impact = 0.25,
		},
	},
	targets = {
		[2] = {
			attack_template = "light_blunt_tank",
			boost_curve_type = "tank_curve",
			power_distribution = {
				attack = 0.1,
				impact = 0.1,
			},
		},
	},
}

NewDamageProfileTemplates.tb_two_handed_hammer_light_3 = { -- official: medium_blunt_smiter_2h_hammer_upper
	armor_modifier = {
		attack = {
			1,
			0.8,
			2,
			1,
			0.75,
			1.1, -- official: 1
		},
		impact = {
			1,
			0.8,
			1,
			1,
			0.75,
		},
	},
	charge_value = "light_attack",
	critical_strike = "critical_strike_blunt_smiter_2h_hammer_H",
	cleave_distribution = "cleave_distribution_smiter_default",
	shield_break = true,
	default_target = {
		attack_template = "blunt_tank_uppercut",
		boost_curve_type = "smiter_curve",
		boost_curve_coefficient = 2,
		power_distribution = {
			attack = 0.6, -- official: 0.4
			impact = 0.25,
		},
	},
	targets = {
		[2] = {
			attack_template = "light_blunt_tank",
			boost_curve_type = "tank_curve",
			power_distribution = {
				attack = 0.1,
				impact = 0.1,
			},
		},
	},
}

NewDamageProfileTemplates.tb_two_handed_hammer_push_attack = { -- official: heavy_blunt_tank_light
	armor_modifier = {
		attack = {
			1,
			0,
			1.5,
			1,
			0.75,
		},
		impact = {
			1,
			1,
			1,
			1,
			0.75,
		},
	},
	charge_value = "heavy_attack", -- official: "light_attack"
	critical_strike = {
		attack_armor_power_modifer = {
			2.6, -- official: 1
			2.6, -- official: 0.6
			3, -- official: 2
			1,
			1,
		},
		impact_armor_power_modifer = {
			1,
			1,
			1,
			1,
			1,
		},
	},
	stagger_duration_modifier = 1.8,
	cleave_distribution = {
		attack = 0.3,
		impact = 0.8,
	},
	default_target = {
		attack_template = "blunt_tank",
		boost_curve_type = "tank_curve",
		power_distribution = {
			attack = 0.05,
			impact = 0.125,
		},
	},
	targets = {
		{
			attack_template = "heavy_blunt_tank",
			boost_curve_type = "tank_curve",
			boost_curve_coefficient_headshot = 0, -- official: none
			armor_modifier = {
				attack = {
					2.3, -- official: 1
					2.3, -- official: 0.5
					2,
					1,
					0.75,
				},
				impact = {
					1.5,
					1,
					1,
					1,
					0.75,
				},
			},
			power_distribution = {
				attack = 0.275,
				impact = 0.3,
			},
		},
		{
			attack_template = "heavy_blunt_tank",
			boost_curve_type = "tank_curve",
			power_distribution = {
				attack = 0.15,
				impact = 0.225,
			},
		},
		{
			attack_template = "blunt_tank",
			boost_curve_type = "tank_curve",
			power_distribution = {
				attack = 0.075,
				impact = 0.2,
			},
		},
	},
}


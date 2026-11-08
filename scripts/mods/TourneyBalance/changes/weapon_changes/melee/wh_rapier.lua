local mod = get_mod("TourneyBalance")

-- Weapon editor export (TourneyBalance)

-- fencing_sword_template_1
Weapons.fencing_sword_template_1.actions.action_one.light_attack_left_last.damage_profile = "tb_fencing_sword_light_attack_left_last" -- official: "light_slashing_linesman_fencer"

-- tb_fencing_sword_light_attack_left_last: new profile (forked from light_slashing_linesman_fencer), add this block
-- used by Weapons.fencing_sword_template_1.actions.action_one.light_attack_left_last.damage_profile
-- changed: cleave_distribution.attack 0.25 -> 0.419
NewDamageProfileTemplates.tb_fencing_sword_light_attack_left_last = { -- official: light_slashing_linesman_fencer
	armor_modifier = "armor_modifier_linesman_fencer_L",
	charge_value = "light_attack",
	critical_strike = "critical_strike_linesman_fencer_L",
	cleave_distribution = {
		attack = 0.419, -- official: 0.25
		impact = 0.2,
	},
	default_target = "default_target_linesman_fencer_L",
	targets = "targets_linesman_fencer_L",
}
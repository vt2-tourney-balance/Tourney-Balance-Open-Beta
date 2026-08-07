local mod = get_mod("TourneyBalance")
local mod_api = require("scripts/mods/TourneyBalance/_api/_mod_api")

--[[
	$BEGIN_TB
		title	: 	Grail Knight Changes
		ult		: 	-
		passives:  	-
		talent22:  	Virtue of Knightly Temper - Reduced instant slay damage multiplier for non-Lords-and-Bosses to 3 (from 4)
		talent43:	Virtue of the Penitent - Increased required kills as follows
					Recruit		: 100 (from 50)
					Veteran		: 150 (from 60)
					Champion	: 250 (from 75)
					Legend		: 300 (from 85)
					Cataclysm	: 350 (from 100)
					Cataclysm 2	: 400 (from 100)
					Cataclysm 3	: 500 (from 100)
		talent62:	Virtue of the Impetuous Knight
		talent63:	Virtue of Confidence - Removed infinite damage cleave, but keep infinite stagger cleave.
					Virtue of Confidence - Added heavy linesman modifier.
					Virtue of Confidence - Lowered damage window start time to 0.05s (from 0.15s)
					Virtue of Confidence - Damage cleave distribution lowered to 0.5 (from 100)
	$END_TB	
]]

--[[

	Talents

]]

--[[
	Virtue of Knightly Temper
]]
mod_api.update_talent_buff_template("empire_soldier", "markus_questing_knight_crit_can_insta_kill",  {
	damage_multiplier = 3 --4
})
mod_api.insert_text("markus_questing_knight_crit_can_insta_kill_desc", "Critical Strikes instantly slay enemies if their current health is less than 3 times the amount of damage of the Critical Strike. Half effect versus Lords and Monsters.")

--[[
	Virtue of the Penitent
]]
local side_quest_challenge = {
	reward = "markus_questing_knight_passive_strength_potion",
	type = "kill_enemies",
	amount = {
		1,
		100, --50
		150, --60
		250, --75
		300, --85
		350, --100
		400, --100
		500  --100
	}
}
mod:hook_origin(PassiveAbilityQuestingKnight, "_get_side_quest_challenge", function(self)
	return side_quest_challenge
end)


--[[
	Virtue of Stoicism
]]
-- 25% as thp instead of 50%
mod_api.update_talent_buff_template("empire_soldier", "markus_questing_knight_health_refund_over_time", {
	heal_amount_fraction = 0.25 -- 0.5
})
mod_api.update_talent("es_questingknight", 5, 1, {
    description = "markus_questing_knight_health_refund_over_time_desc",
    description_values = {},
})
mod_api.insert_text("markus_questing_knight_health_refund_over_time_desc", "25% of damage taken is regenerated as temporary health after 5 seconds.")

--[[
	Virtue of the Impetuous Knight
]]
-- Duration increased to 25s
mod_api.update_talent_buff_template("empire_soldier", "markus_questing_knight_ability_buff_on_kill_movement_speed", {
    duration = 25 --15
})
mod_api.update_talent("es_questingknight", 6, 2, {
    buffs = {
        "tb_cd_grail",
		"markus_questing_knight_ability_buff_on_kill"
    }
})
-- Additional 30% cdr
mod_api.insert_talent_buff_template("empire_soldier", "tb_cd_grail", {
	stat_buff = "activated_cooldown",
	multiplier = -0.3,
	max_stacks = 1
})
mod_api.insert_text("markus_questing_knight_ability_buff_on_kill_desc", "Killing an enemy with Blessed Blade increases movement speed by 35%% for 25 seconds. Reduces cooldown by 30%%.")

--[[
	Virtue of Confidence

-- TODO: move to weapon changes and leave reference here.
]]
-- Remove infinite damage cleave, but keep infinite stagger cleave
-- old damage numbers but heavy linesman instead (potentially too good against berzerkers)
-- start window shorter for better visual feedback
Weapons.markus_questingknight_career_skill_weapon.actions.action_career_release.default_tank.unlimited_cleave = false
Weapons.markus_questingknight_career_skill_weapon.actions.action_career_release.default_tank.hit_mass_count = HEAVY_LINESMAN_HIT_MASS_COUNT
Weapons.markus_questingknight_career_skill_weapon.actions.action_career_release.default_tank.damage_window_start = 0.05 --0.15
DamageProfileTemplates.questing_knight_career_sword_tank.cleave_distribution.attack = 0.5 --100



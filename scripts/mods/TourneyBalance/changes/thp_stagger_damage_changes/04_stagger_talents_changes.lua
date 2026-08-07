local mod = get_mod("TourneyBalance")
local mod_api = require("scripts/mods/TourneyBalance/_api/_mod_api")
local buff_perks = require("scripts/unit_extensions/default_player_unit/buffs/settings/buff_perk_names")
local stagger_types = require("scripts/utils/stagger_types")

--[[
	$BEGIN_TB
		---
		## Stagger Talents
		### Careers
		**Mercenary**
		- Replaced Mainstay with Assassin.

		**Huntsman**
		- Replaced Bulwark with Assassin.

		**Slayer**
		- Replaced Smiter with Assassin.

		**Waystalker**
		- Replaced Mainstay with Smiter.

		**Sister of the Thorn**
		- Replaced Smiter with Bulwark.

		**Witch Hunter Captain**
		- Replaced Mainstay with Smiter.

		**Zealot**
		- Replaced Mainstay with Assassin.

		**Pyromancer**
		- Replaced Mainst with Assassin.

		### Talents
		**Assassin**
		- Removed damage bonus to apply on crits.

		**Bulwark**
		- Added 10% Stagger Power.
		- Increased damage debuff duration to 10s (from 2s).
		- Damage debuff can be applied with any attack.

		**Enhanced Power**
		- Increased power to 10% (from 7.5%).

		**Mainstay**
		- Reduced damage bonus on stagger count 1 to 20% (from 40%).
		- Reduced damage bonus on stagger count 2 to 40% (from 60%).
		- Added melee hits apply 1 stagger count, regardless of actual stagger from the attack.
		- Stagger count only applied to first 5 enemies hit and caps at 2 stagger counts.

		**Smiter**
		- Reformatted description.
	$END_TB
]]

--[[

	Stagger Talents

]]
--[[
	Assassin
]]
-- Assassin Buff copy
mod_api.insert_buff_template("tb_finesse_unbalance", {
	max_display_multiplier = 0.4,
	name = "finesse_unbalance",
	display_multiplier = 0.2,
	perks = { buff_perks.finesse_stagger_damage }
})

--[[
	Bulwark
]]
-- Bulwark Damage Debuff
mod_api.insert_buff_template("tb_tank_unbalance_buff", {
	refresh_durations = true,
	name = "tank_unbalance_buff",
	stat_buff = "unbalanced_damage_taken",
	max_stacks = 1,
	duration = 10,
	bonus = 0.10,
})
-- Apply Bulwark Damage Debuff from any attack
mod_api.insert_proc_function("tb_unbalance_debuff_on_stagger", function (owner_unit, buff, params)
	local hit_unit = params[1]
	local is_dummy = Unit.get_data(hit_unit, "is_dummy")
	--local stagger_type = params[4]
	--local buff_type = params[7]

	if Unit.alive(owner_unit) and (is_dummy or Unit.alive(hit_unit)) then --and (buff_type == "MELEE_1H" or buff_type == "MELEE_2H" or stagger_type == stagger_types.explosion) then
		local buff_extension = ScriptUnit.extension(hit_unit, "buff_system")

		if buff_extension then
			buff_extension:add_buff("tb_tank_unbalance_buff")
		end
	end
end )
-- Bulwark Buff
mod_api.insert_buff_template("tb_tank_unbalance", {
	max_display_multiplier = 0.4,
	name = "tank_unbalance",
	event_buff = true,
	buff_func = "tb_unbalance_debuff_on_stagger",
	event = "on_stagger",
	display_multiplier = 0.2,
	stat_buff = "power_level_impact",
	multiplier = 0.10
})

--[[
	Enhanced Power
]]
mod_api.insert_buff_template("tb_power_level_unbalance", {
	max_stacks = 1,
	name = "power_level_unbalance",
	stat_buff = "power_level",
	multiplier = 0.1 -- 0.075
})

--[[
	Mainstay
]]
-- Mainstay Buff copy
mod_api.insert_buff_template("tb_linesman_unbalance", {
	name = "linesman_unbalance",
	perks = { buff_perks.linesman_stagger_damage }
})
-- Mainstay stagger marks
mod_api.insert_buff_template("tb_mainstay_stagger_mark_buff", {
	refresh_durations = true,
	name = "mainstay_stagger_mark_buff",
	stat_buff = "dummy_stagger",
	max_stacks = 2,
	duration = 2,
	bonus = 1,
})

--[[
	Smiter
]]
-- Smiter Buff copy
mod_api.insert_buff_template("tb_smiter_unbalance", {
	max_display_multiplier = 0.4,
	name = "smiter_unbalance",
	display_multiplier = 0.2,
	perks = { buff_perks.smiter_stagger_damage }
})


--[[

	Text Localization

]]
--mod_api.insert_text("assassin_name", "Assassin")
--mod_api.insert_text("bulwark_name", "Bulwark")
--mod_api.insert_text("enhanced_power_name", "Enhanced Power")
--mod_api.insert_text("mainstay_name", "Mainstay")
--mod_api.insert_text("smiter_name", "Smiter")
mod_api.insert_text("tb_finesse_unbalance_desc", 		"Headshots inflict 40% bonus damage.\n\nDeal 20% more damage to staggered enemies, increased to 40% against enemies afflicted by more than one stagger effect.")
mod_api.insert_text("tb_linesman_unbalance_desc", 		"Melee hits against the first 5 enemy add another count of stagger for 2s.\n\nDeal 20% more damage to staggered enemies, increased to 40% against enemies afflicted by more than one stagger effect.")
mod_api.insert_text("tb_power_level_unbalance_desc",	"Increases total Power Level by 10%. This is calculated before other buffs are applied.")
mod_api.insert_text("tb_tank_unbalance_desc", 			"Gain 10% stagger power. Enemies that you stagger with any attack take 10% more damage from all sources for 10 seconds.\n\nDeal 20% more damage to staggered enemies, increased to 40% against targets afflicted by more than one stagger effect.")
mod_api.insert_text("tb_smiter_unbalance_desc", 		"The first enemy hit always counts as staggered.\n\nDeal 20% more damage to staggered enemies, increased to 40% against enemies afflicted by more than one stagger effect.")

-- Replacing Stagger Talents
local FINESSE = 1
local TANK = 2
local ENHANCED_POWER = 3
local MAINSTAY = 4
local SMITER = 5
local TALENT_OPTIONS = {
	[FINESSE] = { -- Assassin
		--name = "assassin_name",
		description = "tb_finesse_unbalance_desc",
		buffs = { "tb_finesse_unbalance" },
		description_values = {},
	},
	[TANK] = { -- Bulwark
		--name = "bulwark_name",
		description = "tb_tank_unbalance_desc",
		buffs = { "tb_tank_unbalance" },
		description_values = {},
	},
	[ENHANCED_POWER] = { -- Enhanced Power
		--name = "enhanced_power_name",
		description = "tb_power_level_unbalance_desc",
		buffs = { "tb_power_level_unbalance" },
		description_values = {},
	},
	[MAINSTAY] = { -- Mainstay
		--name = "mainstay_name",
		description = "tb_linesman_unbalance_desc",
		buffs = { "tb_linesman_unbalance" },
		description_values = {},
	},
	[SMITER] = { -- Smiter
		--name = "smiter_name",
		description = "tb_smiter_unbalance_desc",
		buffs = { "tb_smiter_unbalance" },
		description_values = {},
	},
}
-- career_name, talent 3-1, talent 3-2, talent 3-3
local talent_third_row = {
	{ "es_mercenary", 		FINESSE, 	SMITER, 	ENHANCED_POWER }, -- Mainstay > Finesse
	{ "es_huntsman", 		FINESSE, 	SMITER, 	ENHANCED_POWER }, -- Bulwark > Finesse
	{ "es_knight", 			TANK, 		MAINSTAY, 	ENHANCED_POWER },
	{ "es_questingknight", 	TANK, 		SMITER, 	ENHANCED_POWER },

	{ "dr_ranger", 			TANK,		MAINSTAY, 	ENHANCED_POWER },
	{ "dr_ironbreaker", 	TANK, 		SMITER, 	ENHANCED_POWER },
	{ "dr_slayer", 			FINESSE, 	MAINSTAY, 	ENHANCED_POWER }, -- Smiter > Finesse
	{ "dr_engineer", 		TANK, 		MAINSTAY, 	ENHANCED_POWER },

	{ "we_waywatcher", 		SMITER, 	FINESSE, 	ENHANCED_POWER }, -- Mainstay > Smiter
	{ "we_maidenguard", 	SMITER, 	MAINSTAY, 	ENHANCED_POWER },
	{ "we_shade", 			SMITER, 	FINESSE, 	ENHANCED_POWER },
	{ "we_thornsister", 	TANK, 		MAINSTAY, 	ENHANCED_POWER }, -- Smiter > Bulwark

	{ "wh_captain", 		SMITER, 	FINESSE, 	ENHANCED_POWER }, -- Mainstay > Smiter
	{ "wh_bountyhunter", 	SMITER, 	FINESSE, 	ENHANCED_POWER },
	{ "wh_zealot", 			SMITER, 	FINESSE, 	ENHANCED_POWER }, -- Mainstay > Finesse
	{ "wh_priest", 			SMITER, 	MAINSTAY, 	ENHANCED_POWER },

	{ "bw_adept", 			TANK, 		SMITER, 	ENHANCED_POWER },
	{ "bw_scholar", 		SMITER, 	FINESSE, 	ENHANCED_POWER }, -- Mainstay > Assassin
	{ "bw_unchained", 		TANK, 		MAINSTAY, 	ENHANCED_POWER },
	{ "bw_necromancer", 	MAINSTAY, 	SMITER, 	ENHANCED_POWER },
}

for i = 1, #talent_third_row do
	local entry = talent_third_row[i]
	local career = entry[1]

	for slot = 1, 3 do
		mod_api.update_talent(career, 3, slot, TALENT_OPTIONS[entry[slot + 1]])
	end
end



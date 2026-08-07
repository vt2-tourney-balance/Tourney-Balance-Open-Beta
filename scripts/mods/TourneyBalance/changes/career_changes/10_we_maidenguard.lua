local mod = get_mod("TourneyBalance")
local mod_api = require("scripts/mods/TourneyBalance/_api/_mod_api")
local is_local = require("scripts/mods/TourneyBalance/_api/shared_utils").is_server

--[[
	$BEGIN_TB
		title	: 	Handmaiden Changes
		ult		: 	Increased hitbox width for non-bleed ult to 5.0 (from 1.5)
		passives:  	Renewal - Stam regen aura range increased to 20 (from 5).
                    Bendy (NEW) - Increase healing received by 40%.
		talent21:   Focused Spirit - Changed to 30% melee power (from 15% power).
                    Focused Spirit - Decreased reset duration to 4s (from 10s).
		talent22:   Oak Stance - Increased crit chance to 10% (from 5%).
                    Oak Stance - Added 30% crit power.
		talent23:   Asrai Alacrity - Increased stacks gained to 3 (from 2)
		talent42:   Dance of Blades - Increased power to 15% (from 10%) and duration to 3.5s (from 2s).
		talent51:   Heart of Oak - Increased health bonus to 20% (from 15%).
		talent53:   Quiver of Plenty - Increased ammo bonus to 70% (from 40%).
	$END_TB	
]]

--[[

	Ultimate

]]
-- Increased hitbox for non-bleed ult (for Power from Pain)
mod:hook(CareerAbilityWEMaidenGuard, "_run_ability", function (func, self, ...)
    func(self, ...)

    local owner_unit = self._owner_unit
    local talent_extension = ScriptUnit.extension(owner_unit, "talent_system")
    local bleed = talent_extension:has_talent("kerillian_maidenguard_activated_ability_damage")

    if bleed then
        local status_extension = self._status_extension
        -- hitbox is a rectangular cube / cuboid with given width, height and length, and offset_forward changes its position relative to character's
        status_extension.do_lunge.damage.width = 1.5    --1.5    --width of hitbox
        status_extension.do_lunge.damage.depth_padding = 0.4   --0.4    --length of hitbox
        status_extension.do_lunge.damage.offset_forward = 0   --0    --position of hitbox
    else
        local status_extension = self._status_extension
        -- hitbox is a rectangular cube / cuboid with given width, height and length, and offset_forward changes its position relative to character's
        status_extension.do_lunge.damage.width = 5.0    --1.5    --width of hitbox
        status_extension.do_lunge.damage.depth_padding = 5.0   --0.4    --length of hitbox
        status_extension.do_lunge.damage.offset_forward = 0   --0    --position of hitbox
    end
end)

--[[

    Passives

]]
--[[
    Bendy - NEW PERK
]]
mod_api.insert_talent_buff_template("wood_elf", "kerillian_maidenguard_passive_damage_reduction", {
	stat_buff = "healing_received",
	multiplier = 0.4,
})
mod_api.insert_career_passives("we_2", {
    "kerillian_maidenguard_passive_damage_reduction"
})
mod_api.insert_perk_text("tb_we_2d", "Bendy", "Increases healing received by 40%")
mod_api.insert_career_perk_descriptions("we_2", "tb_we_2d")

--[[
    Renewal
]]
mod_api.update_talent_buff_template("wood_elf", "kerillian_maidenguard_passive_stamina_regen_aura", {
	range = 20 -- 5
})

--[[

	Talents

]]
--[[
    Focused Spirit
]]
-- Fix friendly fire reset buff
mod_api.insert_proc_function("maidenguard_reset_unharmed_buff", function (owner_unit, buff, params)
    local attacker_unit = params[1]
    local damage_amount = params[2]
    local damaged = true

    if damage_amount and damage_amount == 0 then
        damaged = false
    end

    -- Check for friendly fire
    local side = Managers.state.side.side_by_unit[owner_unit]
    local player_and_bot_units = side.PLAYER_AND_BOT_UNITS
    local shot_by_friendly = false
    local allies = (player_and_bot_units and #player_and_bot_units) or 0

    for i = 1, allies, 1 do
        local ally_unit =  player_and_bot_units[i]
        if ally_unit == attacker_unit then
            shot_by_friendly = true
        end
    end

    if ALIVE[owner_unit] and not shot_by_friendly and damaged then
        local buff_extension = ScriptUnit.has_extension(owner_unit, "buff_system")
        local buff_name = "kerillian_maidenguard_power_level_on_unharmed_cooldown"
        local network_manager = Managers.state.network
        local network_transmit = network_manager.network_transmit
        local unit_object_id = network_manager:unit_game_object_id(owner_unit)
        local buff_template_name_id = NetworkLookup.buff_templates[buff_name]

        if is_server() then
            buff_extension:insert_buff(buff_name, {
                attacker_unit = owner_unit
            })
        else
            network_transmit:send_rpc_server("rpc_insert_buff", unit_object_id, buff_template_name_id, unit_object_id, 0, true)
        end

        return true
    end
end)
mod_api.update_talent_buff_template("wood_elf", "kerillian_maidenguard_power_level_on_unharmed", {
    multiplier = 0.30, -- 0.15%
	stat_buff = "power_level_melee", -- power_level
})
mod_api.update_talent_buff_template("wood_elf", "kerillian_maidenguard_power_level_on_unharmed_cooldown", {
    duration = 4 -- 10
})
mod_api.insert_text("erillian_maidenguard_power_level_on_unharmed_desc", "After not taking damage for 4 seconds, increases Kerillian's melee power by 30.0%. Reset upon taking damage, friendly fire will not reset the buff.")


--[[
    Oak Stance
]]
mod_api.update_talent_buff_template("wood_elf", "kerillian_maidenguard_crit_chance", {
	bonus = 0.1 -- 0.05
})
-- Additional 30% crit power
mod_api.insert_talent_buff_template("wood_elf", "tb_kerilllian_maidenguard_crit_power", {
	stat_buff = "critical_strike_effectiveness",
	multiplier = 0.3,
	max_stacks = 1
})
mod_api.update_talent("we_maidenguard", 2, 2, {
    buffs = {
        "tb_kerilllian_maidenguard_crit_power",
		"kerillian_maidenguard_crit_chance"
    },
})
mod_api.insert_text("kerillian_maidenguard_crit_chance_desc", "Increases critical strike chance by 10.0% and critical strike damage by 30.0%.")


--[[
    Asrai Alacrity
]]
mod_api.update_talent_buff_template("wood_elf", "kerillian_maidenguard_speed_on_push", {
    amount_to_add = 3, -- 2
    max_sub_buff_stacks = 3, -- 2
})
mod_api.update_talent_buff_template("wood_elf", "kerillian_maidenguard_speed_on_block", {
    amount_to_add = 3, -- 2
    max_sub_buff_stacks = 3, -- 2
})
mod_api.update_talent_buff_template("wood_elf", "kerillian_maidenguard_speed_on_block_dummy_buff", {
    max_stacks = 3 -- 2
})
mod_api.insert_text("kerillian_maidenguard_speed_on_block_desc", "Blocking an attack or pushing an enemy grants the next three strikes 30%% attack speed and 10%% power.")


--[[
    Dance of Blades
]]
-- Now grants 15% power lasting for 3.5 seconds.
mod_api.update_talent_buff_template("wood_elf", "kerillian_maidenguard_power_on_dodge", {
	duration = 3.5, -- 2
	multiplier = 0.15 -- 0.1
})
mod_api.insert_text("kerillian_maidenguard_versatile_dodge_desc", "Dodging while blocking increases dodge range by 20%. Dodging while not blocking increases Kerillian's power by 15% for 3.5 seconds.")

--[[
    Heart of Oak
]]
mod_api.update_talent_buff_template("wood_elf", "kerillian_maidenguard_max_health", {
	multiplier = 0.2 -- 0.15
})
mod_api.insert_text("kerillian_maidenguard_max_health_desc", "Increases max health by 20.0%.")


--[[
    Quiver of Plenty
]]
mod_api.update_talent_buff_template("wood_elf", "kerillian_maidenguard_max_ammo", {
	multiplier = 0.7 -- 0.4
})
mod_api.insert_text("kerillian_maidenguard_max_ammo_desc", "Increases ammunition amount by 70.0%.")



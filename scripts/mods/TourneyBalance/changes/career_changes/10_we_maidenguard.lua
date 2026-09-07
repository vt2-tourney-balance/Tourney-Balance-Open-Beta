local mod = get_mod("TourneyBalance")
local mod_api = require("scripts/mods/TourneyBalance/_api/_mod_api")
local is_server = require("scripts/mods/TourneyBalance/_api/shared_utils").is_server

--[[
	$BEGIN_TB
		---
		## Handmaiden
		### Career Ability
		- Increased hitbox width for non-bleed ult to 5.0 (from 1.5).

		### Passives
		**Dance of Season**
		- Added effect: Blocking starts immediately, even mid-attack (the attack animation still plays out).

		**Renewal**
		- Stam regen aura range increased to 20 (from 5).

		**Oak Guard (listed)**
		- Previously unlisted passive (increases maximum stamina by 1, half a stamina shield) is now shown in the perk list.
		- Added effect: Pushing enemies taunts them for 2 seconds.

		### Talents
		**Focused Spirit**
		- Changed to 30% melee power (from 15% power).
		- Decreased reset duration to 4s (from 10s).

		**Oak Stance**
		- Increased crit chance to 10% (from 5%).
		- Added 30% crit power.

		**Asrai Alacrity**
		- Increased stacks gained to 3 (from 2).

		**Dance of Blades**
		- Dodging starts immediately: dodging can now be canceled into another dodge (1s internal cooldown), or started while airborne (jumping or falling), with real air momentum, not just the visual sidestep.
		- Increased power to 15% (from 10%) and duration to 6s (from 2s).

		**Heart of Oak**
		- Increased health bonus to 20% (from 15%).
		- Added 40% increased healing received.

		**Quiver of Plenty**
		- Increased ammo bonus to 70% (from 40%).
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
    Oak Guard - previously unlisted vanilla perk (+1 max stamina), now listed with an added taunt-on-push effect
]]
mod_api.insert_proc_function("tb_maidenguard_taunt_on_push", function (owner_unit, buff, params)
    if not is_server() then
        return
    end

    local hit_unit = params[1]

    if not hit_unit or not HEALTH_ALIVE[hit_unit] then
        return
    end

    local ai_extension = ScriptUnit.has_extension(hit_unit, "ai_system")

    if not ai_extension then
        return
    end

    local breed = ai_extension:breed()

    if breed.ignore_taunts or breed.boss then
        return
    end

    local blackboard = ai_extension:blackboard()
    local t = Managers.time:time("game")

    blackboard.taunt_unit = owner_unit
    blackboard.taunt_end_time = t + buff.template.taunt_duration
    blackboard.target_unit = owner_unit
    blackboard.target_unit_found_time = t
end)
mod_api.insert_talent_buff_template("wood_elf", "tb_kerillian_maidenguard_taunt_on_push", {
    buff_func = "tb_maidenguard_taunt_on_push",
    event = "on_push",
    taunt_duration = 2,
})
mod_api.insert_career_passives("we_2", {
    "tb_kerillian_maidenguard_taunt_on_push"
})
mod_api.insert_perk_text("tb_we_2d", "Oak Guard", "Increases maximum stamina by 1 (half a stamina shield). Pushing enemies taunts them for 5 seconds.")
mod_api.insert_career_perk_descriptions("we_2", "tb_we_2d")

--[[
    Renewal
]]
mod_api.update_talent_buff_template("wood_elf", "kerillian_maidenguard_passive_stamina_regen_aura", {
	range = 20 -- 5
})

--[[
    Dance of Season - the base passive that already grants +15% dodge range/speed, now also with instant block
]]
-- Blocking starts immediately: raise the "blocking" status the instant block is pressed, independent of the
-- current weapon action, so the current attack's animation keeps playing while damage mitigation is already active.
-- Always active for the career (not tied to a talent pick), matching the other always-on base passives.
local function tb_instant_block_wielding_blockable_melee(inventory_extension)
    local equipment = inventory_extension:equipment()
    local wielded = equipment.wielded
    local weapon_template_name = wielded and (wielded.template or wielded.temporary_template)
    local weapon_template = weapon_template_name and WeaponUtils.get_weapon_template(weapon_template_name)
    local action_two = weapon_template and weapon_template.actions and weapon_template.actions.action_two

    return action_two ~= nil and action_two.default ~= nil and action_two.default.kind == "block"
end

local function tb_instant_block_set_blocking(unit, status_extension, blocking, t)
    status_extension:set_blocking(blocking)

    if blocking then
        status_extension.timed_block = t + 0.5
    end

    local network_manager = Managers.state.network
    local game = network_manager:game()
    local go_id = game and network_manager:unit_game_object_id(unit)

    if go_id then
        if is_server() then
            network_manager.network_transmit:send_rpc_clients("rpc_set_blocking", go_id, blocking)
        else
            network_manager.network_transmit:send_rpc_server("rpc_set_blocking", go_id, blocking)
        end
    end
end

-- Let the real weapon action system go first every frame, so its own (vanilla) handling of things like
-- push chaining back into block on continued hold happens completely untouched. Our forced early block
-- only ever fills the remaining gap: input held, wielding a blockable melee weapon, but the real system still
-- hasn't (e.g. because it's mid-attack and not yet at a chainable point).
mod:hook(CharacterStateHelper, "update_weapon_actions", function (func, t, unit, input_extension, inventory_extension, health_extension)
    func(t, unit, input_extension, inventory_extension, health_extension)

    local career_extension = ScriptUnit.has_extension(unit, "career_system")

    if career_extension and career_extension:career_name() == "we_maidenguard" and tb_instant_block_wielding_blockable_melee(inventory_extension) then
        local status_extension = ScriptUnit.extension(unit, "status_system")
        local wants_block = input_extension:get("action_two_hold")

        if wants_block and not status_extension.blocking then
            tb_instant_block_set_blocking(unit, status_extension, true, t)

            status_extension._tb_instant_block_forced_block = true
        elseif status_extension._tb_instant_block_forced_block and not wants_block then
            tb_instant_block_set_blocking(unit, status_extension, false, t)

            status_extension._tb_instant_block_forced_block = false
        end
    end
end)

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
mod_api.update_talent("we_maidenguard", 2, 1, {
    description = "kerillian_maidenguard_power_level_on_unharmed_desc",
    description_values = {},
})
mod_api.insert_text("kerillian_maidenguard_power_level_on_unharmed_desc", "After not taking damage for 4 seconds, increases Kerillian's melee power by 30.0%. Reset upon taking damage, friendly fire will not reset the buff.")


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
    description = "kerillian_maidenguard_crit_chance_desc",
    description_values = {},
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
mod_api.insert_text("kerillian_maidenguard_speed_on_block_desc", "Blocking an attack or pushing an enemy grants the next 3 strikes 30%% attack speed and 10%% power.")


--[[
    Dance of Blades
]]
-- Now grants 15% power lasting for 6 seconds.
mod_api.update_talent_buff_template("wood_elf", "kerillian_maidenguard_power_on_dodge", {
	duration = 6, -- 2
	multiplier = 0.15 -- 0.1
})
mod_api.update_talent("we_maidenguard", 4, 2, {
    description = "kerillian_maidenguard_versatile_dodge_desc",
    description_values = {},
})
mod_api.insert_text("kerillian_maidenguard_versatile_dodge_desc", "Dodging while blocking increases dodge range by 20%. Dodging while not blocking increases Kerillian's power by 15% for 6 seconds. Dodging starts immediately (1s ICD).")

local function tb_always_on_ground()
    return true
end

local DANCE_OF_BLADES_CANCEL_COOLDOWN = 1

-- Dodging starts immediately: let a dodge input interrupt an in-progress dodge (dodge-cancel), gated by its own
-- 1s internal cooldown so it can't be chained every frame -- only the cancel-into-a-new-dodge path is gated;
-- starting a dodge fresh from walking/standing/falling/jumping is untouched.
mod:hook(PlayerCharacterStateDodging, "update", function (func, self, unit, input, dt, context, t)
    local talent_extension = ScriptUnit.extension(unit, "talent_system")
    local has_dance_of_blades = talent_extension:has_talent("kerillian_maidenguard_versatile_dodge")

    if has_dance_of_blades and not self.csm.state_next then
        local status_extension = self.status_extension
        local cancel_ready = t >= (status_extension._tb_dance_of_blades_cancel_cd or 0)

        if cancel_ready then
            local start_dodge, dodge_direction = CharacterStateHelper.check_to_start_dodge(unit, self.input_extension, status_extension, t)

            if start_dodge then
                local params = self.temp_params

                params.dodge_direction = dodge_direction

                status_extension._tb_dance_of_blades_cancel_cd = t + DANCE_OF_BLADES_CANCEL_COOLDOWN

                self.csm:change_state("dodging", params)

                return
            end
        end
    end

    if not has_dance_of_blades then
        return func(self, unit, input, dt, context, t)
    end

    --[[
        Vanilla dodging also lets a jump input near the end of the dodge cancel it straight into a real jump ("dodge-jump").
        Uncomment below to prevent mid air dodge-jumps.
    ]]
    local locomotion_extension = self.locomotion_extension
    local real_is_on_ground = locomotion_extension.is_on_ground
    --local real_jump_allowed = locomotion_extension.jump_allowed
    --local really_on_ground = real_is_on_ground(locomotion_extension)

    locomotion_extension.is_on_ground = tb_always_on_ground
    --locomotion_extension.jump_allowed = function (self)
    --    return really_on_ground and real_jump_allowed(self)
    --end

    local ok, err = pcall(func, self, unit, input, dt, context, t)

    locomotion_extension.is_on_ground = real_is_on_ground
    --locomotion_extension.jump_allowed = real_jump_allowed

    if not ok then
        error(err, 0)
    end
end)

-- Let a dodge be started while airborne too: both while going up ("jumping", the brief takeoff phase right after
-- leaving the ground) and on the way back down ("falling", the rest of the arc).
for _, state_class in ipairs({ PlayerCharacterStateJumping, PlayerCharacterStateFalling }) do
    mod:hook(state_class, "update", function (func, self, unit, input, dt, context, t)
        local talent_extension = ScriptUnit.extension(unit, "talent_system")

        if talent_extension:has_talent("kerillian_maidenguard_versatile_dodge") and not self.csm.state_next then
            local start_dodge, dodge_direction = CharacterStateHelper.check_to_start_dodge(unit, self.input_extension, self.status_extension, t)

            if start_dodge then
                local params = self.temp_params

                params.dodge_direction = dodge_direction

                self.csm:change_state("dodging", params)

                return
            end
        end

        return func(self, unit, input, dt, context, t)
    end)
end

--[[
    Heart of Oak
]]
mod_api.update_talent_buff_template("wood_elf", "kerillian_maidenguard_max_health", {
	multiplier = 0.2 -- 0.15
})
-- Also grants 40% increased healing received
mod_api.insert_talent_buff_template("wood_elf", "tb_kerillian_maidenguard_heart_of_oak_healing_received", {
	stat_buff = "healing_received",
	multiplier = 0.4,
})
mod_api.update_talent("we_maidenguard", 5, 1, {
    description = "kerillian_maidenguard_max_health_desc",
    description_values = {},
    buffs = {
        "kerillian_maidenguard_max_health",
        "tb_kerillian_maidenguard_heart_of_oak_healing_received",
    },
})
mod_api.insert_text("kerillian_maidenguard_max_health_desc", "Increases max health by 20.0% and healing received by 40.0%.")

--[[
    Birch Stance
]]
mod_api.update_talent("we_maidenguard", 5, 2, {
    description = "kerillian_maidenguard_block_cost_desc",
    description_values = {},
})
mod_api.insert_text("kerillian_maidenguard_block_cost_desc", "Reduces block cost by 30.0%.")


--[[
    Quiver of Plenty
]]
mod_api.update_talent_buff_template("wood_elf", "kerillian_maidenguard_max_ammo", {
	multiplier = 0.7 -- 0.4
})
mod_api.update_talent("we_maidenguard", 5, 3, {
    description = "kerillian_maidenguard_max_ammo_desc",
    description_values = {},
})
mod_api.insert_text("kerillian_maidenguard_max_ammo_desc", "Increases ammunition amount by 70.0%.")



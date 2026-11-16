local mod = get_mod("TourneyBalance")
local mod_api = require("scripts/mods/TourneyBalance/_api/_mod_api")

-- Boon of Shallya 40%
local trait_data = WeaponTraits.traits.necklace_increased_healing_received
if trait_data and trait_data.description_values and trait_data.description_values[1] then
    trait_data.description_values[1].value = 0.4
end
local buff_data = BuffTemplates.trait_necklace_increased_healing_received
if buff_data and buff_data.buffs and buff_data.buffs[1] then
    buff_data.buffs[1].multiplier = 0.4
end

--[[
    Natural Bond
]]
-- health regen no longer replaces temp health (affects Chaos Wastes regen boon).
BuffFunctionTemplates.functions.update_heal_ticks = function (unit, buff, params)
    local t = params.t
    local buff_template = buff.template
    local next_heal_tick = buff.next_heal_tick or 0
    local health_extension = ScriptUnit.extension(unit, "health_system")

    if health_extension:current_permanent_health_percent() >= 1 then
        return
    end

    if next_heal_tick < t then
        if Managers.state.network.is_server and HEALTH_ALIVE[unit] then
            local heal_amount = buff_template.heal_amount

            -- Give THP first so it doesn't grant GHP + THP resulting in double regen
            DamageUtils.heal_network(unit, unit, heal_amount, "heal_from_proc")
            DamageUtils.heal_network(unit, unit, heal_amount, "career_passive")
        end

        buff.next_heal_tick = t + buff_template.time_between_heals
    end
end
-- description_values: heal_amount (1), time_between_heals (5)
mod_api.insert_text("description_trait_necklace_no_healing_health_regen_2", "Regenerates %s health every %s seconds. Cannot be healed by healing items. Health regeneration does not replace temporary health.")

--[[
    Healer's Touch (necklace) / Home Brewer (charm)
]]
-- 25% chance to craft item (heal/potion) used by you or ally
local CRAFT_PROC_CHANCE = 0.25
local CRAFT_NETWORK_ID = "tb_consumable_used"
local CRAFT_TRAITS = {
    -- slot -> trait key, buff name, description key
    slot_healthkit = { "necklace_not_consume_healing", "trait_necklace_not_consume_healing", "tb_description_trait_necklace_craft_healing" },
    slot_potion = { "ring_not_consume_potion", "trait_ring_not_consume_potion", "tb_description_trait_ring_craft_potion" },
}
local CRAFT_TRAIT_BUFF_BY_SLOT = {}

for slot_name, trait in pairs(CRAFT_TRAITS) do
    local trait_key, buff_name, description = trait[1], trait[2], trait[3]
    local trait_data = WeaponTraits.traits[trait_key]

    trait_data.buffer = "both" -- server needs to see remote wearers (vanilla "client")
    trait_data.advanced_description = description -- vanilla key is shared with the Chaos Wastes boon
    BuffTemplates[buff_name].buffs[1].stat_buff = nil -- vanilla "not_consume_medpack" / "not_consume_potion"
    CRAFT_TRAIT_BUFF_BY_SLOT[slot_name] = buff_name
end

-- description_values: proc_chance (25%)
mod_api.insert_text("tb_description_trait_necklace_craft_healing", "%s chance to craft the healing item used by you or an ally.")
mod_api.insert_text("tb_description_trait_ring_craft_potion", "%s chance to craft the potion used by you or an ally.")

-- Server: roll for every wearer on the user's side
local function server_roll_crafting(side, item_name)
    local item_data = rawget(ItemMasterList, item_name)
    local slot_name = item_data and item_data.slot_type and "slot_" .. item_data.slot_type
    local trait_buff = slot_name and CRAFT_TRAIT_BUFF_BY_SLOT[slot_name]
    local item_name_id = trait_buff and rawget(NetworkLookup.item_names, item_name)

    if not item_name_id then
        return
    end

    local network_manager = Managers.state.network
    local inventory_system = Managers.state.entity:system("inventory_system")
    local slot_id = NetworkLookup.equipment_slots[slot_name]
    local player_and_bot_units = side.PLAYER_AND_BOT_UNITS

    for i = 1, #player_and_bot_units do
        local wearer_unit = player_and_bot_units[i]
        local buff_extension = ALIVE[wearer_unit] and ScriptUnit.has_extension(wearer_unit, "buff_system")

        if buff_extension and buff_extension:has_buff_type(trait_buff) and math.random() < CRAFT_PROC_CHANCE then
            local wearer_go_id = network_manager:unit_game_object_id(wearer_unit)

            if wearer_go_id then
                -- Gives it to the owner (stored as an additional item where the career allows), or spawns it as a pickup at
                -- the given position if the slot is full
                inventory_system:rpc_give_equipment(nil, NetworkConstants.invalid_game_object_id, wearer_go_id, slot_id, item_name_id, POSITION_LOOKUP[wearer_unit])
            end
        end
    end
end

-- The used item only leaves its slot on the ammo extension's next update, so a wearer who used it themselves would
-- still have a full slot (and get the craft dropped on the ground). Rolls are delayed until the slot is free.
local CRAFT_DELAY = 0.5
local pending_crafts = {} -- server only, { user's side, item_name, roll_t }

local function server_on_consumable_used(user_unit, item_name)
    local side = Managers.state.side.side_by_unit[user_unit]

    if side then
        pending_crafts[#pending_crafts + 1] = { side, item_name, Managers.time:time("game") + CRAFT_DELAY }
    end
end

mod:add_update_function(function (dt)
    local num_pending = #pending_crafts

    if num_pending == 0 then
        return
    end

    local network_manager = Managers.state.network

    if not network_manager or not network_manager.is_server then
        table.clear(pending_crafts)

        return
    end

    local t = Managers.time:time("game")

    for i = num_pending, 1, -1 do
        local craft = pending_crafts[i]

        if t >= craft[3] then
            table.remove(pending_crafts, i)
            server_roll_crafting(craft[1], craft[2])
        end
    end
end)

mod:network_register(CRAFT_NETWORK_ID, function (sender_peer_id, item_name)
    local network_manager = Managers.state.network

    if not network_manager or not network_manager.is_server or type(item_name) ~= "string" then
        return
    end

    local player = Managers.player:player_from_peer_id(sender_peer_id)
    local user_unit = player and player.player_unit

    if ALIVE[user_unit] then
        server_on_consumable_used(user_unit, item_name)
    end
end)

-- User's machine (host for bots)
local function on_consumable_used(user_unit, item_name)
    local network_manager = Managers.state.network

    if not network_manager or not item_name then
        return
    end

    if network_manager.is_server then
        server_on_consumable_used(user_unit, item_name)
    else
        mod:network_send(CRAFT_NETWORK_ID, network_manager.network_transmit.server_peer_id, item_name)
    end
end

local function after_consume_action(self, ammo_extension, ammo_before, ...)
    if ammo_before and ammo_extension:ammo_count() < ammo_before then
        on_consumable_used(self.owner_unit, self.item_name)
    end

    return ...
end

-- Healing draught / potions used on yourself
for _, action_class in ipairs({ ActionHealingDraught, ActionPotion }) do
    mod:hook(action_class, "finish", function (func, self, ...)
        local ammo_extension = self.ammo_extension
        local ammo_before = ammo_extension and ammo_extension:ammo_count()

        return after_consume_action(self, ammo_extension, ammo_before, func(self, ...))
    end)
end

-- Medical supplies, on yourself or an ally (interactor's machine)
mod:hook(InteractionDefinitions.heal.client, "stop", function (func, world, interactor_unit, interactable_unit, data, config, t, result)
    local interactor_data = data.interactor_data
    local slot_name = interactor_data and interactor_data.item_slot_name
    local inventory_extension = slot_name and result == InteractionResult.SUCCESS and ScriptUnit.has_extension(interactor_unit, "inventory_system")
    local slot_data = inventory_extension and inventory_extension:get_slot_data(slot_name)
    local ammo_extension = slot_data and inventory_extension:get_item_slot_extension(slot_name, "ammo_system")
    local ammo_before = ammo_extension and ammo_extension:ammo_count()
    local item_name = slot_data and slot_data.item_data and slot_data.item_data.name

    func(world, interactor_unit, interactable_unit, data, config, t, result)

    if ammo_before and ammo_extension:ammo_count() < ammo_before then
        on_consumable_used(interactor_unit, item_name)
    end
end)

--[[
    Revive Speed
]]
-- property also speeds up pulling allies up from ledges, freeing them from Packmaster hooks
-- and rescuing them from respawn points. Uses its own stat so faster_revive talents (Maidenguard) don't apply.
StatBuffApplicationMethods.faster_rescue = "stacking_multiplier"

local revive_speed_buffs = BuffTemplates.properties_revive_speed.buffs
revive_speed_buffs[2] = {
    name = "properties_revive_speed_rescue",
    stat_buff = "faster_rescue",
    variable_multiplier = table.clone(revive_speed_buffs[1].variable_multiplier),
}

local function rescue_config(interactor_unit, config)
    local buff_extension = Unit.alive(interactor_unit) and ScriptUnit.has_extension(interactor_unit, "buff_system")
    if not buff_extension then
        return config
    end
    local duration = buff_extension:apply_buffs_to_value(config.duration, "faster_rescue")
    return setmetatable({ duration = duration }, { __index = config })
end

for _, interaction_name in ipairs({ "pull_up", "release_from_hook", "assisted_respawn" }) do
    local interaction = InteractionDefinitions[interaction_name]

    mod:hook(interaction.server, "start", function(func, world, interactor_unit, interactable_unit, data, config, t)
        return func(world, interactor_unit, interactable_unit, data, rescue_config(interactor_unit, config), t)
    end)

    mod:hook(interaction.client, "start", function(func, world, interactor_unit, interactable_unit, data, config, t)
        local modified_config = rescue_config(interactor_unit, config)
        data.rescue_duration = modified_config.duration
        return func(world, interactor_unit, interactable_unit, data, modified_config, t)
    end)

    mod:hook(interaction.client, "get_progress", function(func, data, config, t)
        local duration = data.rescue_duration or config.duration
        if duration == 0 then
            return 0
        end
        return data.start_time == nil and 0 or math.min(1, (t - data.start_time) / duration)
    end)
end
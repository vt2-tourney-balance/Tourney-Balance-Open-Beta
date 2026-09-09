local mod = get_mod("TourneyBalance")

-- Boon of Shallya 40%
local trait_data = WeaponTraits.traits.necklace_increased_healing_received
if trait_data and trait_data.description_values and trait_data.description_values[1] then
    trait_data.description_values[1].value = 0.4
end
local buff_data = BuffTemplates.trait_necklace_increased_healing_received
if buff_data and buff_data.buffs and buff_data.buffs[1] then
    buff_data.buffs[1].multiplier = 0.4
end

-- Natural Bond: health regen no longer replaces temp health (affects Chaos Wastes regen boon).
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
local mod = get_mod("TourneyBalance")


-- Scrounger (ammo on crit) shouldn't proc from Trueshot Volley/ability-fired arrows
mod:hook(ProcFunctions, "ammo_fraction_gain_on_crit_trait", function (func, owner_unit, buff, params)
	local ranged_buff_type = params[5]

	if ranged_buff_type == "RANGED_ABILITY" then
		return
	end

	return func(owner_unit, buff, params)
end)

-- Boon of Shallya 40%
local trait_data = WeaponTraits.traits.necklace_increased_healing_received
if trait_data and trait_data.description_values and trait_data.description_values[1] then
    trait_data.description_values[1].value = 0.4
end
local buff_data = BuffTemplates.trait_necklace_increased_healing_received
if buff_data and buff_data.buffs and buff_data.buffs[1] then
    buff_data.buffs[1].multiplier = 0.4
end
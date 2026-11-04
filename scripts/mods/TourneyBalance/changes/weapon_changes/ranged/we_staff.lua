local mod = get_mod("TourneyBalance")

--[[
    Deepwood Staff
]]
VortexTemplates.spirit_storm.time_of_life = { 5,5 }

-- Lift overcharge. The bar is 40 and explodes on reaching it, so 12 per lift gives 3 lifts before the 4th explodes,
-- or 4 lifts before the 5th with Thermal Equalizer (-20% overcharge: 9.6 per lift, 4 lifts = 38.4).
Weapons.staff_life.actions.action_one.cast_vortex.overcharge_amount = 12 -- 10

-- Overcharge explosion (Thornsister career overcharge data)
-- Remove the safety net: vanilla caps a shot that would reach max overcharge at max - 0.1 (no explosion)
OverchargeData.we_thornsister.critical_overcharge_margin = math.huge
-- Exploding costs 100% of max health (from 40%)
-- OverchargeData.we_thornsister.percent_health_lost = 1 -- 0.4

--Staff can lift chemists
--Weapons.staff_life.actions.action_two.default.prioritized_breeds.chaos_plague_sorcerer = 1
--Breeds.chaos_plague_sorcerer.controllable = true



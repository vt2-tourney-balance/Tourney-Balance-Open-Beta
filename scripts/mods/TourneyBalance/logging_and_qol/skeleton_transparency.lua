local mod = get_mod("TourneyBalance")

--[[
	Skeleton transparency (mod setting "skeleton_transparency", percent)

	Makes the Necromancer's skeletons see-through, the way a friendly player looks while invisible: through the fade
	system's minimum fade, which only changes how the unit is drawn. Every peer sets it for itself, the skeletons of
	other players included.
]]
local SKELETON_BREEDS = {
	pet_skeleton = true,
	pet_skeleton_armored = true,
	pet_skeleton_dual_wield = true,
	pet_skeleton_with_shield = true,
}
local CHECK_INTERVAL = 0.25
local PRUNE_INTERVAL = 10
local BREED_TIMEOUT = 5 -- a unit's breed may not be set yet when its fade extension is added

-- The setting is how visible the skeletons are (100% fully visible, 0% invisible), the fade system wants how faded
local function get_fade()
	return 1 - math.clamp((mod:get("skeleton_transparency") or 65) / 100, 0, 1)
end

local fade = get_fade()
local skeletons = {}
local pending = {}
local next_check_t = 0
local next_prune_t = 0

local function apply_fade(unit)
	local entity_manager = Managers.state.entity
	local fade_system = entity_manager and entity_manager:system("fade_system")

	if fade_system then
		fade_system:set_min_fade(unit, fade)
	end
end

-- Units get a fade extension when they spawn, or come out of the freezer
mod:hook_safe(FadeSystem, "on_add_extension", function (self, world, unit, extension_name)
	if extension_name == "AIUnitFadeExtension" then
		pending[unit] = Managers.time:time("main") + BREED_TIMEOUT
	end
end)
mod:hook_safe(FadeSystem, "unfreeze", function (self, unit)
	if skeletons[unit] then
		apply_fade(unit)
	end
end)

mod:add_update_function(function (dt)
	local entity_manager = Managers.state and Managers.state.entity

	if not entity_manager or not Managers.time then
		return
	end

	local t = Managers.time:time("main")

	if t < next_check_t then
		return
	end

	next_check_t = t + CHECK_INTERVAL

	for unit, deadline in pairs(pending) do
		if not Unit.alive(unit) then
			pending[unit] = nil
		else
			local breed = Unit.get_data(unit, "breed")

			if breed then
				pending[unit] = nil

				if SKELETON_BREEDS[breed.name] then
					skeletons[unit] = true

					apply_fade(unit)
				end
			elseif t > deadline then
				pending[unit] = nil
			end
		end
	end

	if t >= next_prune_t then
		next_prune_t = t + PRUNE_INTERVAL

		for unit in pairs(skeletons) do
			if not Unit.alive(unit) then
				skeletons[unit] = nil
			end
		end
	end
end)

mod:add_setting_changed_function(function ()
	fade = get_fade()

	for unit in pairs(skeletons) do
		if Unit.alive(unit) then
			apply_fade(unit)
		else
			skeletons[unit] = nil
		end
	end
end)

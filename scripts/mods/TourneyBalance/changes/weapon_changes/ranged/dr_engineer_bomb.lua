local mod = get_mod("TourneyBalance")

--[[
    Engineer Bomb - Replace with smoke bomb model
]]
local TB_ENGINEER_BOMB_UNIT = "units/weapons/player/wpn_emp_grenade_02_t1/wpn_emp_grenade_02_t1"
local TB_ENGINEER_BOMB_PROJECTILE_UNITS = "tb_engineer_grenade"
local engineer_bomb = Weapons.engineer_grenade_t1

-- Held model
ItemMasterList.grenade_engineer.right_hand_unit = TB_ENGINEER_BOMB_UNIT -- wpn_emp_grenade_01_t1
engineer_bomb.right_hand_unit = TB_ENGINEER_BOMB_UNIT -- wpn_emp_grenade_01_t1

-- Thrown model
ProjectileUnits[TB_ENGINEER_BOMB_PROJECTILE_UNITS] = {
	projectile_unit_name = TB_ENGINEER_BOMB_UNIT .. "_3p",
}
ProjectileUnitsFromUnitName[TB_ENGINEER_BOMB_UNIT .. "_3p"] = TB_ENGINEER_BOMB_PROJECTILE_UNITS

-- engineer_grenade_t1 is deep clone of the frag template
engineer_bomb.actions.action_one.throw.projectile_info.projectile_units_template = TB_ENGINEER_BOMB_PROJECTILE_UNITS -- grenade
engineer_bomb.required_projectile_unit_templates.grenade = nil
engineer_bomb.required_projectile_unit_templates[TB_ENGINEER_BOMB_PROJECTILE_UNITS] = false

-- Ground pickup: 
-- No smoke bomb pickup unit, so hides meshes and link the smoke bomb _3p unit locally
local TB_ENGINEER_BOMB_PICKUP = "engineer_grenade_t1"
local TB_ENGINEER_BOMB_UNIT_3P = TB_ENGINEER_BOMB_UNIT .. "_3p"
-- Height offset
local TB_ENGINEER_BOMB_PICKUP_HEIGHT_OFFSET = 0.1
-- Scale
local TB_ENGINEER_BOMB_PICKUP_SCALE = 1.3

-- Normally only loaded while someone holds or throws one; a Parting Gift drop can appear while nobody does.
if not Managers.package:has_loaded(TB_ENGINEER_BOMB_UNIT_3P, "global") then
	Managers.package:load(TB_ENGINEER_BOMB_UNIT_3P, "global")
end

mod:hook_safe(PickupUnitExtension, "extensions_ready", function (self)
	if self.pickup_name ~= TB_ENGINEER_BOMB_PICKUP or not Application.can_get("unit", TB_ENGINEER_BOMB_UNIT_3P) then
		return
	end

	local unit = self.unit
	local world = self.world
	local visual_unit = World.spawn_unit(world, TB_ENGINEER_BOMB_UNIT_3P, Unit.world_position(unit, 0), Unit.world_rotation(unit, 0))

	-- Hidden before linking, so the visibility change can't reach the child.
	Unit.set_unit_visibility(unit, false)
	World.link_unit(world, visual_unit, 0, unit, 0)
	Unit.set_local_position(visual_unit, 0, Vector3(0, 0, TB_ENGINEER_BOMB_PICKUP_HEIGHT_OFFSET))
	Unit.set_local_scale(visual_unit, 0, Vector3(TB_ENGINEER_BOMB_PICKUP_SCALE, TB_ENGINEER_BOMB_PICKUP_SCALE, TB_ENGINEER_BOMB_PICKUP_SCALE))

	self._tb_visual_unit = visual_unit

	-- Pickup outlines only cover the pickup unit's own meshes ("unit"); include the linked model.
	local outline_extension = ScriptUnit.has_extension(unit, "outline_system")

	if outline_extension then
		outline_extension.apply_method = "unit_and_childs"
	end
end)
mod:hook_safe(PickupUnitExtension, "hide", function (self)
	local visual_unit = self._tb_visual_unit

	if visual_unit and Unit.alive(visual_unit) then
		Unit.set_unit_visibility(visual_unit, false)
	end
end)
mod:hook_safe(PickupUnitExtension, "destroy", function (self)
	local visual_unit = self._tb_visual_unit

	if visual_unit and Unit.alive(visual_unit) then
		World.destroy_unit(self.world, visual_unit)
	end

	self._tb_visual_unit = nil
end)

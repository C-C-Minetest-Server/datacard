-- datacard/init.lua
-- Portable data storage for Digilines
--[[
	MIT License

	Copyright (c) 2022, 2024  1F616EMO

	Permission is hereby granted, free of charge, to any person obtaining a copy
	of this software and associated documentation files (the "Software"), to deal
	in the Software without restriction, including without limitation the rights
	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
	copies of the Software, and to permit persons to whom the Software is
	furnished to do so, subject to the following conditions:

	The above copyright notice and this permission notice shall be included in all
	copies or substantial portions of the Software.

	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
	SOFTWARE.
]]

local S = core.get_translator("datacard")

local function determine_size(obj)
	local objtype = type(obj)
	if objtype == "function" or objtype == "userdata" then
		return 1e100
	elseif objtype == "nil" then
		return 1
	elseif objtype == "table" then
		local size = 2 -- Table init with 2 size elem
		for x, y in pairs(obj) do
			size = size + 1 -- every key-value pair: 1 size elem
			size = size + determine_size(x) + determine_size(y)
		end
		return size
	end
	return #(tostring(obj))
end

local cards = {
	{ "mk1", S("Datacard Mk1"), 200 },
	{ "mk2", S("Datacard Mk2"), 400 },
	{ "mk3", S("Datacard Mk3"), 800 },
}
for _, y in pairs(cards) do
	core.register_craftitem("datacard:datacard_" .. y[1], {
		description = y[2],
		inventory_image = "datacard_" .. y[1] .. ".png",
		groups = { datacard_capacity = y[3] },
		on_drop = function() end,
		stack_max = 1,
	})
end

local function store_data(itemstack, data)
	local name = itemstack:get_name()
	local datasize = determine_size(data)
	local capacity = core.get_item_group(name, "datacard_capacity")
	local item_description = core.registered_items[name] and core.registered_items[name].description or
		"Unknown Datacard"

	if datasize > capacity then
		return false, "TOO_BIG"
	end

	local serialized_data = core.serialize(data)
	if data then -- check
		local check_data = core.deserialize(serialized_data)
		if not check_data then
			return false, "ERR_SERIALIZE"
		end
	end

	local meta = itemstack:get_meta()
	meta:set_string("data", serialized_data)
	meta:set_int("size", datasize)
	meta:set_string("description", S("@1 (@2/@3 Datablock used)", item_description, datasize, capacity))
	return true, itemstack
end

local function read_data(itemstack)
	local meta = itemstack:get_meta()
	local serialized_data = meta:get_string("data")
	if serialized_data == "" then
		return nil
	end
	return core.deserialize(serialized_data, true)
end

local function get_size(itemstack)
	local name = itemstack:get_name()
	local meta = itemstack:get_meta()
	local datasize = meta:get_int("size")
	local capacity = core.get_item_group(name, "datacard_capacity")
	return datasize, capacity
end

-- Diskdrive
local function on_construct(pos)
	local meta = core.get_meta(pos)
	local inv = meta:get_inventory()
	inv:set_size("disk", 1)
	meta:set_string("formspec", "field[channel;Channel;${channel}]")
	meta:set_string("infotext", S("Empty Datacard Diskdrive"))
end

local function on_punch(pos, node, puncher, pointed_thing)
	local meta = core.get_meta(pos)
	local channel = meta:get_string("channel")
	local inv = meta:get_inventory()
	local stack = puncher:get_wielded_item()
	local puncher_inv = puncher:get_inventory()
	local itemname = stack:get_name()
	local pname = puncher:get_player_name()

	local orig_in_drive = inv:get_stack("disk", 1)
	if orig_in_drive:get_count() ~= 0 then
		if core.is_protected(pos, pname) and not core.check_player_privs(pname, { protection_bypass = true }) then
			core.record_protection_violation(pos, pname)
			return
		end
		if puncher_inv:room_for_item("main", orig_in_drive) then
			puncher_inv:add_item("main", orig_in_drive)
		else
			local item = core.add_item(pos, orig_in_drive)
			if not item then return end
			item:add_velocity(core.facedir_to_dir(node.param2) * -2)
		end
		inv:set_stack("disk", 1, "")
		if channel ~= "" then
			digilines.receptor_send(pos, digilines.rules.default, channel, {
				responce_type = "eject",
			})
		end
		node.name = "datacard:diskdrive_empty"
		core.swap_node(pos, node)
		meta:set_string("infotext", S("Empty Datacard Diskdrive"))
	end

	if core.get_item_group(itemname, "datacard_capacity") ~= 0 then
		if core.is_protected(pos, pname) and not core.check_player_privs(pnamename, { protection_bypass = true }) then
			core.record_protection_violation(pos, pname)
			return
		end
		local disk = stack:take_item(1)
		puncher:set_wielded_item(stack)
		inv:set_stack("disk", 1, disk)
		if channel ~= "" then
			digilines.receptor_send(pos, digilines.rules.default, channel, {
				responce_type = "inject",
			})
		end
		node.name = "datacard:diskdrive_working"
		core.swap_node(pos, node)
		meta:set_string("infotext", S("Working Datacard Diskdrive"))
	end
end

local function on_receive_fields(pos, _, fields, sender)
	local name = sender:get_player_name()
	if core.is_protected(pos, name) and not core.check_player_privs(name, { protection_bypass = true }) then
		core.record_protection_violation(pos, name)
		return
	end
	if (fields.channel) then
		core.get_meta(pos):set_string("channel", fields.channel)
	end
end

local function on_digiline_receive(pos, _, channel, msg)
	local meta = core.get_meta(pos)
	local inv = meta:get_inventory()
	local setchan = meta:get_string("channel")
	if setchan ~= channel then return end

	if type(msg) ~= "table" then return end
	local msgtype = string.lower(msg.type or "")
	if msgtype == "read" then
		local disk = inv:get_stack("disk", 1)
		if disk:get_count() ~= 0 then
			local data = read_data(disk)
			local used, capacity = get_size(disk)
			digilines.receptor_send(pos, digilines.rules.default, channel, {
				responce_type = msg.type,
				status = true,
				data = data,
				used = used,
				capacity = capacity,

				id = msg.id,
			})
		else
			digilines.receptor_send(pos, digilines.rules.default, channel, {
				responce_type = msg.type,
				success = false,
				error = "NO_DISK",

				id = msg.id,
			})
		end
	elseif msgtype == "write" then
		local disk = inv:get_stack("disk", 1)
		if disk:get_count() ~= 0 then
			local status, stack = store_data(disk, msg.data)
			if status then
				inv:set_stack("disk", 1, stack)
				local used, capacity = get_size(stack)
				digilines.receptor_send(pos, digilines.rules.default, channel, {
					responce_type = msg.type,
					success = true,
					used = used,
					capacity = capacity,

					id = msg.id,
				})
			else
				digilines.receptor_send(pos, digilines.rules.default, channel, {
					responce_type = msg.type,
					success = false,
					error = stack,

					id = msg.id,
				})
			end
		else
			digilines.receptor_send(pos, digilines.rules.default, channel, {
				responce_type = msg.type,
				success = false,
				error = "NO_DISK",

				id = msg.id,
			})
		end
	elseif msgtype == "eject" then
		local disk = inv:get_stack("disk", 1)
		print(disk)
		if disk:get_count() ~= 0 then
			local item = core.add_item(pos, disk)
			if not item then return end
			local node = core.get_node(pos)
			item:add_velocity(core.facedir_to_dir(node.param2) * -2)

			inv:set_stack("disk", 1, "")

			if setchan ~= "" then
				digilines.receptor_send(pos, digilines.rules.default, setchan, {
					responce_type = "eject",

					id = msg.id,
				})
			end

			core.swap_node(pos, { name = "datacard:diskdrive_empty" })
			meta:set_string("infotext", S("Empty Datacard Diskdrive"))
		else
			digilines.receptor_send(pos, digilines.rules.default, channel, {
				responce_type = msg.type,
				success = false,
				error = "NO_DISK",

				id = msg.id,
			})
		end
	else
		digilines.receptor_send(pos, digilines.rules.default, channel, {
			responce_type = msg.type,
			success = false,
			error = "UNKNOWN_CMD",

			id = msg.id,
		})
	end
end
local function can_dig(pos, player)
	local meta = core.get_meta(pos)
	local inv = meta:get_inventory()
	return inv:is_empty("disk")
end
local function on_place(itemstack, placer, pointed_thing)
	return core.rotate_and_place(itemstack, placer, pointed_thing, false, "force_floor")
end


core.register_node("datacard:diskdrive_empty", {
	description = S("Datacard Diskdrive"),
	tiles = { -- +Y, -Y, +X, -X, +Z, -Z
		"device_terminal_top.png", "device_terminal_top.png",
		"device_computer_side.png", "device_computer_side.png",
		"device_computer_side.png", "device_diskdrive_front_on_1.png"
	},
	on_construct = on_construct,
	on_punch = on_punch,
	on_receive_fields = on_receive_fields,
	digilines = {
		receptor = {},
		effector = {
			action = on_digiline_receive
		},
	},
	groups = { cracky = 1, level = 2 },
	sounds = default.node_sound_metal_defaults(),
	can_dig = can_dig,
	on_place = on_place,
	paramtype2 = "facedir",
})

core.register_node("datacard:diskdrive_working", {
	description = S("Datacard Diskdrive") .. " (You Hacker You!)",
	tiles = { -- +Y, -Y, +X, -X, +Z, -Z
		"device_terminal_top.png", "device_terminal_top.png",
		"device_computer_side.png", "device_computer_side.png",
		"device_computer_side.png", "device_diskdrive_front_on_2.png"
	},
	on_construct = on_construct,
	on_punch = on_punch,
	on_receive_fields = on_receive_fields,
	digilines = {
		receptor = {},
		effector = {
			action = on_digiline_receive
		},
	},
	groups = { cracky = 1, level = 2, not_in_creative_inventory = 1 },
	drop = "datacard:diskdrive_empty",
	sounds = default.node_sound_metal_defaults(),
	can_dig = can_dig,
	on_place = on_place,
	paramtype2 = "facedir",
})

-- Crafting
if core.get_modpath("technic") then
	core.register_craft({
		recipe = {
			{ "default:tin_ingot", "",                            "default:tin_ingot" },
			{ "default:tin_ingot", "technic:control_logic_unit",  "default:tin_ingot" },
			{ "default:tin_ingot", "digilines:wire_std_00000000", "default:tin_ingot" },
		},
		output = "datacard:datacard_mk1"
	})
	core.register_craft({
		type = "shapeless",
		recipe = { "datacard:datacard_mk1", "datacard:datacard_mk1" },
		output = "datacard:datacard_mk2"
	})
	core.register_craft({
		type = "shapeless",
		recipe = { "datacard:datacard_mk2", "datacard:datacard_mk2" },
		output = "datacard:datacard_mk3"
	})
	core.register_craft({
		type = "shapeless",
		recipe = { "datacard:datacard_mk1", "datacard:datacard_mk1", "datacard:datacard_mk1", "datacard:datacard_mk1" },
		output = "datacard:datacard_mk3"
	})

	for _, y in ipairs({ "mesecons_luacontroller:luacontroller0000", "mesecons_microcontroller:microcontroller0000" }) do
		if core.registered_nodes[y] then
			local groups = table.copy(core.registered_nodes[y].groups or {})
			groups.datacard_craft_controller = 1
			core.override_item(y, { groups = groups })
		end
	end

	core.register_craft({
		recipe = {
			{ "default:tin_ingot", "",                                "default:tin_ingot" },
			{ "default:tin_ingot", "group:datacard_craft_controller", "default:tin_ingot" },
			{ "default:tin_ingot", "digilines:wire_std_00000000",     "default:tin_ingot" },
		},
		output = "datacard:diskdrive_empty"
	})
end

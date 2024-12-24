---- module inserter
-- @gui Module

local Gui = require("modules.exp_legacy.expcore.gui") --- @dep expcore.gui
local Event = require("modules/exp_legacy/utils/event") --- @dep utils.event
local Roles = require("modules.exp_legacy.expcore.roles") --- @dep expcore.roles
local config = require("modules.exp_legacy.config.module") --- @dep config.module
local Selection = require("modules.exp_legacy.modules.control.selection") --- @dep modules.control.selection
local SelectionModuleArea = "ModuleArea"

--- align an aabb to the grid by expanding it
local function aabb_align_expand(aabb)
    return {
        left_top = {
            x = math.floor(aabb.left_top.x),
            y = math.floor(aabb.left_top.y),
        },
        right_bottom = {
            x = math.ceil(aabb.right_bottom.x),
            y = math.ceil(aabb.right_bottom.y),
        },
    }
end

local module_container
local machine_name = {}

for k, _ in pairs(config.machine_set) do
    if script.active_mods[k] then
        for k2, v in pairs(config.machine_set[k]) do
            config.machine[k2] = v
            table.insert(machine_name, k2)
        end
    end
end

local prod_module_names = {}

local function get_module_name()
    for name, item in pairs(prototypes.item) do
        if item.module_effects and item.module_effects.productivity and item.module_effects.productivity > 0 then
            prod_module_names[#prod_module_names + 1] = name
        end
    end
end

local elem_filter = {
    name = { {
        filter = "name",
        name = machine_name,
    } },
    normal = { {
        filter = "type",
        type = "module",
    }, {
        filter = "name",
        name = prod_module_names,
        mode = "and",
        invert = true,
    } },
    prod = { {
        filter = "type",
        type = "module",
    } },
}

local function clear_module(player, area, machine, planner)
    local force = player.force
    local surface = player.surface -- Allow remote view

    for _, entity in pairs(surface.find_entities_filtered{ area = area, name = machine, force = force }) do
        surface.upgrade_area{ area = { left_top = entity.position, right_bottom = entity.position }, force = force, player = player, item = planner }
    end
end

local function apply_module(player, area, machine, planner)
    local force = player.force
    local surface = player.surface

    for _, entity in pairs(surface.find_entities_filtered{ area = area, name = machine, force = force }) do
        if entity.prototype.get_crafting_speed() then
            local m_current_recipe = entity.get_recipe()
            local m_current_recipe_prototype = m_current_recipe.prototype

            if m_current_recipe_prototype.maximum_productivity or (m_current_recipe_prototype.allowed_effects and m_current_recipe_prototype.allowed_effects["productivity"]) then
                surface.upgrade_area{ area = { left_top = entity.position, right_bottom = entity.position }, force = force, player = player, item = planner["n"] }
            else
                surface.upgrade_area{ area = { left_top = entity.position, right_bottom = entity.position }, force = force, player = player, item = planner["p"] }
            end
        else
            surface.upgrade_area{ area = { left_top = entity.position, right_bottom = entity.position }, force = force, player = player, item = planner["n"] }
        end
    end
end

--- when an area is selected to add protection to the area
Selection.on_selection(SelectionModuleArea, function(event)
    local area = aabb_align_expand(event.area)
    local player = game.players[event.player_index]
    local frame = Gui.get_left_element(player, module_container)
    local scroll_table = frame.container.scroll.table

    local inventory = game.create_inventory(1)
    inventory.insert{ name = "upgrade-planner" }
    local upgrade_planner_set_empty = inventory[1]

    local l = 1

    for k, v in pairs(prototypes.get_item_filtered({ { filter = "type", type = "module" }, { filter = "hidden", mode = "and", invert = true } })) do
        upgrade_planner_set_empty.set_mapper(l, "from", { type = "item", name = k, tier = v.tier })
        upgrade_planner_set_empty.set_mapper(l, "to", { type = "item", name = "empty-module-slot" })
        l = l + 1
    end

    for i = 1, config.default_module_row_count do
        local mma = scroll_table["module_mm_" .. i .. "_0"].elem_value

        if mma then
            local mm = {
                ["n"] = {},
                ["p"] = {},
            }

            for j = 1, prototypes.entity[mma].module_inventory_size, 1 do
                local mmo = scroll_table["module_mm_" .. i .. "_" .. j].elem_value

                if mmo then
                    if mm["n"][mmo] then
                        mm["n"][mmo] = mm["n"][mmo] + 1
                        mm["p"][mmo] = mm["p"][mmo] + 1
                    else
                        mm["n"][mmo] = 1
                        mm["p"][mmo] = 1
                    end
                end
            end

            for k, v in pairs(mm["p"]) do
                if k:find("productivity") then
                    local module_name = k:gsub("productivity", "efficiency")
                    mm["p"][module_name] = (mm["p"][module_name] or 0) + v
                    mm["p"][k] = nil
                end
            end

            if mm then
                clear_module(player, area, mma, upgrade_planner_set_empty)

                local inventory_2 = game.create_inventory(2)
                inventory_2.insert{ name = "upgrade-planner", count = 2 }
                local upgrade_planner_n = inventory_2[1]
                local upgrade_planner_p = inventory_2[2]

                l = 1

                for k, v in pairs(mm["n"]) do
                    upgrade_planner_n.set_mapper(1, "to", { type = "item", name = k, count = v, tier = 1 })
                    l = l + 1
                end

                l = 1

                for k, v in pairs(mm["p"]) do
                    upgrade_planner_p.set_mapper(1, "to", { type = "item", name = k, count = v, tier = 1 })
                    l = l + 1
                end

                apply_module(player, area, mma, { ["n"] = upgrade_planner_n, ["p"] = upgrade_planner_p })

                inventory_2.destroy()
            end
        end
    end

    inventory.destroy()
end)

local function row_set(player, element)
    local frame = Gui.get_left_element(player, module_container)
    local scroll_table = frame.container.scroll.table

    if scroll_table[element .. "0"].elem_value then
        for i = 1, config.module_slot_max do
            if i <= prototypes.entity[scroll_table[element .. "0"].elem_value].module_inventory_size then
                if config.machine[scroll_table[element .. "0"].elem_value].prod then
                    scroll_table[element .. i].elem_filters = elem_filter.prod
                else
                    scroll_table[element .. i].elem_filters = elem_filter.normal
                end

                scroll_table[element .. i].enabled = true
                scroll_table[element .. i].elem_value = config.machine[scroll_table[element .. "0"].elem_value].module
            else
                scroll_table[element .. i].enabled = false
                scroll_table[element .. i].elem_value = nil
            end
        end
    else
        local mf = elem_filter.normal

        for i = 1, config.module_slot_max do
            scroll_table[element .. i].enabled = false
            scroll_table[element .. i].elem_filters = mf
            scroll_table[element .. i].elem_value = nil
        end
    end
end

local button_apply =
    Gui.element{
        type = "button",
        caption = "Apply",
        style = "button",
    }:on_click(function(player)
        if Selection.is_selecting(player, SelectionModuleArea) then
            Selection.stop(player)
        else
            Selection.start(player, SelectionModuleArea)
        end
    end)

module_container =
    Gui.element(function(definition, parent)
        local container = Gui.container(parent, definition.name, (config.module_slot_max + 2) * 36)
        Gui.header(container, "Module Inserter", "", true)

        local scroll_table = Gui.scroll_table(container, (config.module_slot_max + 2) * 36, config.module_slot_max + 1)

        for i = 1, config.default_module_row_count do
            scroll_table.add{
                name = "module_mm_" .. i .. "_0",
                type = "choose-elem-button",
                elem_type = "entity",
                elem_filters = elem_filter.name,
                style = "slot_button",
            }

            for j = 1, config.module_slot_max do
                scroll_table.add{
                    name = "module_mm_" .. i .. "_" .. j,
                    type = "choose-elem-button",
                    elem_type = "item",
                    elem_filters = elem_filter.normal,
                    style = "slot_button",
                    enabled = false,
                }
            end
        end

        button_apply(container)

        return container.parent
    end)
    :static_name(Gui.unique_static_name)
    :add_to_left_flow()

Gui.left_toolbar_button("item/productivity-module-3", { "module.main-tooltip" }, module_container, function(player)
    return Roles.player_allowed(player, "gui/module")
end)

Event.add(defines.events.on_gui_elem_changed, function(event)
    if event.element.name:sub(1, 10) == "module_mm_" then
        if event.element.name:sub(-1) == "0" then
            row_set(game.players[event.player_index], "module_mm_" .. event.element.name:sub(-3):sub(1, 1) .. "_")
        end
    end
end)

Event.add(defines.events.on_player_joined_game, get_module_name)

Event.add(defines.events.on_entity_settings_pasted, function(event)
    local source = event.source
    local destination = event.destination
    local player = game.players[event.player_index]

    if not player then
        return
    end

    if not source or not source.valid then
        return
    end

    if not destination or not destination.valid then
        return
    end

    -- rotate machine also
    if config.copy_paste_rotation then
        if (source.name == destination.name or source.prototype.fast_replaceable_group == destination.prototype.fast_replaceable_group) then
            if source.supports_direction and destination.supports_direction and source.type ~= "transport-belt" then
                local destination_box = destination.bounding_box

                local ltx = destination_box.left_top.x
                local lty = destination_box.left_top.y
                local rbx = destination_box.right_bottom.x
                local rby = destination_box.right_bottom.y

                local old_direction = destination.direction
                destination.direction = source.direction

                if ltx ~= destination_box.left_top.x or lty ~= destination_box.left_top.y or rbx ~= destination_box.right_bottom.x or rby ~= destination_box.right_bottom.y then
                    destination.direction = old_direction
                end
            end
        end
    end

    --[[
    TODO handle later as may need using global to reduce creation of upgrade plans

    if config.copy_paste_module then
        if source.name ~= destination.name then
            return
        end

        local source_inventory = source.get_module_inventory()

        if not source_inventory then
            return
        end

        local source_inventory_content = source_inventory.get_contents()

        if not source_inventory_content then
            return
        end

        clear_module(player, destination.bounding_box, destination.name)

        if next(source_inventory_content) ~= nil then
            apply_module(player, destination.bounding_box, destination.name, { ["n"] = source_inventory_content, ["p"] = source_inventory_content })
        end
    end
    ]]
end)

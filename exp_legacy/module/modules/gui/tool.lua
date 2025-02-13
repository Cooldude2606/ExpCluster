--[[-- Gui Module - Tool
    @gui Tool
    @alias tool_container
]]

local ExpUtil = require("modules/exp_util")
local Gui = require("modules/exp_legacy/expcore/gui") --- @dep expcore.gui
local Roles = require("modules.exp_legacy.expcore.roles") --- @dep expcore.roles
local Event = require("modules/exp_legacy/utils/event") --- @dep utils.event
local Selection = require("modules/exp_legacy/modules/control/selection") --- @dep modules.control.selection
local addon_train = require("modules/exp_scenario/commands/trains")
local addon_research = require("modules/exp_scenario/commands/research")

local tool_container

local SelectionArtyArea = "ExpCommand_Artillery"
local SelectionWaterfillArea = "ExpCommand_Waterfill"

local style = {
    label = {
        width = 160
    },
    button = {
        width = 80
    }
}

--- Arty label
-- @element tool_gui_arty_l
local tool_gui_arty_l =
    Gui.element{
        type = "label",
        name = "tool_arty_l",
        caption = { "tool.artillery" },
        tooltip = { "tool.artillery-tooltip" },
        style = "heading_2_label"
    }:style(
        style.label
    )

--- Arty button
-- @element tool_gui_arty_b
local tool_gui_arty_b =
    Gui.element{
        type = "button",
        name = "tool_arty_b",
        caption = { "tool.apply" }
    }:style(
        style.button
    ):on_click(function(player, _, _)
        if Selection.is_selecting(player, SelectionArtyArea) then
            Selection.stop(player)

        else
            Selection.start(player, SelectionArtyArea)
            player.print{ "tool.entered-area-selection" }
        end
    end)

--- Waterfill label
-- @element tool_gui_waterfill_l
local tool_gui_waterfill_l =
    Gui.element{
        type = "label",
        name = "tool_waterfill_l",
        caption = { "tool.waterfill" },
        tooltip = { "tool.waterfill-tooltip" },
        style = "heading_2_label"
    }:style(
        style.label
    )

--- Waterfill button
-- @element tool_gui_waterfill_b
local tool_gui_waterfill_b =
    Gui.element{
        type = "button",
        name = "tool_waterfill_b",
        caption = { "tool.apply" }
    }:style(
        style.button
    ):on_click(function(player, _, _)
        if Selection.is_selecting(player, SelectionWaterfillArea) then
            Selection.stop(player)
            return player.print{ "exp-commands_waterfill.exit" }
        elseif player.get_item_count("cliff-explosives") == 0 then
            return player.print{ "exp-commands_waterfill.requires-explosives" }
        else
            Selection.start(player, SelectionWaterfillArea)
            return player.print{ "exp-commands_waterfill.enter" }
        end
    end)

--- Train label
-- @element tool_gui_train_l
local tool_gui_train_l =
    Gui.element{
        type = "label",
        name = "tool_train_l",
        caption = { "tool.train" },
        tooltip = { "tool.train-tooltip" },
        style = "heading_2_label"
    }:style(
        style.label
    )

--- Train button
-- @element tool_gui_train_b
local tool_gui_train_b =
    Gui.element{
        type = "button",
        name = "tool_train_b",
        caption = { "tool.apply" }
    }:style(
        style.button
    ):on_click(function(player, _, _)
        addon_train.manual(player)
    end)

--- Research label
-- @element tool_gui_research_l
local tool_gui_research_l =
    Gui.element{
        type = "label",
        name = "tool_research_l",
        caption = { "tool.research" },
        tooltip = { "tool.research-tooltip" },
        style = "heading_2_label"
    }:style(
        style.label
    )

--- Research button
-- @element tool_gui_research_b
local tool_gui_research_b =
    Gui.element{
        type = "button",
        name = "tool_research_b",
        caption = { "tool.apply" }
    }:style(
        style.button
    ):on_click(function(player, _, _)
        local enabled = addon_research.set_auto_research()

        if enabled then
            addon_research.res_queue(player.force, true)
        end

        local player_name = ExpUtil.format_player_name_locale(player)
        game.print{ "exp-commands_research.auto-research", player_name, enabled }
    end)

--- Spawn label
-- @element tool_gui_spawn_l
local tool_gui_spawn_l =
    Gui.element{
        type = "label",
        name = "tool_spawn_l",
        caption = { "tool.spawn" },
        tooltip = { "tool.spawn-tooltip" },
        style = "heading_2_label"
    }:style(
        style.label
    )

--- Spawn button
-- @element tool_gui_spawn_b
local tool_gui_spawn_b =
    Gui.element{
        type = "button",
        name = "tool_spawn_b",
        caption = { "tool.apply" }
    }:style(
        style.button
    ):on_click(function(player, _, _)
        if not player.character
        or player.character.health <= 0
        or not ExpUtil.teleport_player(player, game.surfaces.nauvis, { 0, 0 }, "dismount") then
            return player.print{ "exp-commands_teleport.unavailable" }
        end
    end)

local function tool_perm(player)
    local frame = Gui.get_left_element(player, tool_container)
    local disp = frame.container["tool_st"].disp.table
    local allowed

    allowed = Roles.player_allowed(player, "command/artillery")
    disp[tool_gui_arty_l.name].visible = allowed
    disp[tool_gui_arty_b.name].visible = allowed

    allowed = Roles.player_allowed(player, "command/waterfill")
    disp[tool_gui_waterfill_l.name].visible = allowed
    disp[tool_gui_waterfill_b.name].visible = allowed

    allowed = Roles.player_allowed(player, "command/set-trains-to-automatic")
    disp[tool_gui_train_l.name].visible = allowed
    disp[tool_gui_train_b.name].visible = allowed

    allowed = Roles.player_allowed(player, "command/set-auto-research")
    disp[tool_gui_research_l.name].visible = allowed
    disp[tool_gui_research_b.name].visible = allowed

    allowed = Roles.player_allowed(player, "command/spawn")
    disp[tool_gui_spawn_l.name].visible = allowed
    disp[tool_gui_spawn_b.name].visible = allowed
end

--- A vertical flow containing all the tool
-- @element tool_set
local tool_set =
    Gui.element(function(_, parent, name)
        local tool_set = parent.add{ type = "flow", direction = "vertical", name = name }
        local disp = Gui.scroll_table(tool_set, 240, 2, "disp")

        tool_gui_arty_l(disp)
        tool_gui_arty_b(disp)

        tool_gui_waterfill_l(disp)
        tool_gui_waterfill_b(disp)

        tool_gui_train_l(disp)
        tool_gui_train_b(disp)

        tool_gui_research_l(disp)
        tool_gui_research_b(disp)

        tool_gui_spawn_l(disp)
        tool_gui_spawn_b(disp)

        return tool_set
    end)

--- The main container for the tool gui
-- @element tool_container
tool_container =
    Gui.element(function(definition, parent)
        local player = Gui.get_player_from_element(parent)
        local container = Gui.container(parent, definition.name, 240)

        tool_set(container, "tool_st")

        tool_perm(player)

        return container.parent
    end)
    :static_name(Gui.unique_static_name)
    :add_to_left_flow()

--- Button on the top flow used to toggle the tool container
-- @element toggle_left_element
Gui.left_toolbar_button("item/repair-pack", { "tool.main-tooltip" }, tool_container, function(player)
    return Roles.player_allowed(player, "gui/tool")
end)

Event.add(Roles.events.on_role_assigned, function(event)
    tool_perm(game.players[event.player_index])
end)

Event.add(Roles.events.on_role_unassigned, function(event)
    tool_perm(game.players[event.player_index])
end)

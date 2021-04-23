--[[-- Control Module - Selection
    - Controls players who have a selection planner, mostly event handlers
    @control Selection
    @alias Selection
]]

local Event = require 'utils.event' --- @dep utils.event
local Global = require 'utils.global' --- @dep utils.global
local Selection = {}

local selection_tool = { name='selection-tool' }

local selections = {}
Global.register({
    selections = selections
}, function(tbl)
    selections = tbl.selections
end)

--- Let a player select an area by providing a selection planner
function Selection.start(player, single_use, ...)
    game.print('Start selection')
    -- Assign the arguments if the player is valid
    if not player or not player.valid then return end
    game.print('Valid Player')
    selections[player.index] = {
        arguments = { ... },
        single_use = single_use == true,
        character = player.character
    }

    -- Give a selection tool if one is not in use
    if player.cursor_stack.is_selection_tool then return end
    game.print('Give item')
    player.clear_cursor() -- Clear the current item
    player.cursor_stack.set_stack(selection_tool)

    -- Make a slot to place the selection tool even if inventory is full
    if not player.character then return end
    game.print('Give slot')
    player.character_inventory_slots_bonus = player.character_inventory_slots_bonus + 1
    player.hand_location = { inventory = defines.inventory.character_main, slot = #player.get_main_inventory() }
end

--- Stop a player selection by removing the selection planner
function Selection.stop(player)
    if not selections[player.index] then return end
    local character = selections[player.index].character
    selections[player.index] = nil

    -- Remove the selection tool
    if player.cursor_stack.is_selection_tool then
        player.cursor_stack.clear()
    else
        player.remove_item(selection_tool)
    end

    -- Remove the extra slot
    if character and character == player.character then
        player.character_inventory_slots_bonus = player.character_inventory_slots_bonus - 1
        player.hand_location = nil
    end
end

--- Get the selection arguments for a player
function Selection.get_arguments(player)
    if not selections[player.index] then return end
    return selections[player.index].arguments
end

--- Alias to Event.add(defines.events.on_player_selected_area)
function Selection.on_selection(handler)
    return Event.add(defines.events.on_player_selected_area, handler)
end

--- Alias to Event.add(defines.events.on_player_alt_selected_area)
function Selection.on_alt_selection(handler)
    return Event.add(defines.events.on_player_alt_selected_area, handler)
end

--- Stop selection after an event such as death or leaving the game
local function stop_after_event(event)
    local player = game.get_player(event.player_index)
    Selection.stop(player)
end

Event.add(defines.events.on_pre_player_left_game, stop_after_event)
Event.add(defines.events.on_pre_player_died, stop_after_event)

--- Stop selection if the selection tool is removed from the cursor
Event.add(defines.events.on_player_cursor_stack_changed, function(event)
    local player = game.get_player(event.player_index)
    if player.cursor_stack.is_selection_tool then return end
    Selection.stop(player)
end)

--- Stop selection after a single use if the option was used
local function stop_after_use(event)
    if not selections[event.player_index] then return end
    if not selections[event.player_index].single_use then return end
    stop_after_event(event)
end

Event.add(defines.events.on_player_selected_area, stop_after_use)
Event.add(defines.events.on_player_alt_selected_area, stop_after_use)

return Selection
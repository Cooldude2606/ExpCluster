
local Storage = require("modules/exp_util/storage")

local ExpElement = require("./prototype")

--- @alias ExpGui.VisibleCallback fun(player: LuaPlayer, element: LuaGuiElement): boolean

--- @class ExpGui.player_elements
--- @field top table<string, LuaGuiElement>
--- @field left table<string, LuaGuiElement>
--- @field relative table<string, LuaGuiElement>

--- @type table<uint, ExpGui.player_elements>
local player_elements = {}
Storage.register(player_elements, function(tbl)
    player_elements = tbl
end)

--- @class ExpGui
local ExpGui = {
    element = ExpElement,
    top_elements = {}, --- @type table<ExpElement, ExpGui.VisibleCallback | boolean>
    left_elements = {}, --- @type table<ExpElement, ExpGui.VisibleCallback | boolean>
    relative_elements = {}, --- @type table<ExpElement, ExpGui.VisibleCallback | boolean>
}

local mod_gui = require("mod-gui")
ExpGui.get_top_flow = mod_gui.get_button_flow
ExpGui.get_left_flow = mod_gui.get_frame_flow

--- Get a player from an element or gui event
--- @param input LuaGuiElement | { player_index: uint }
--- @return LuaPlayer
function ExpGui.get_player(input)
    return assert(game.get_player(input.player_index))
end

--- Toggle the enable state of an element
--- @param element LuaGuiElement
--- @param state boolean?
function ExpGui.toggle_enabled_state(element, state)
    if not element or not element.valid then return end
    if state == nil then
        state = not element.enabled
    end
    element.enabled = state
end

--- Toggle the visibility of an element
--- @param element LuaGuiElement
--- @param state boolean?
function ExpGui.toggle_visible_state(element, state)
    if not element or not element.valid then return end
    if state == nil then
        state = not element.visible
    end
    element.visible = state
end

--- Destroy an element if it exists and is valid
--- @param element LuaGuiElement?
function ExpGui.destroy_if_valid(element)
    if not element or not element.valid then return end
    element.destroy()
end

--- Register a element define to be drawn to the top flow on join
--- @param define ExpElement
--- @param visible ExpGui.VisibleCallback | boolean | nil
function ExpGui.add_top_element(define, visible)
    assert(ExpGui.top_elements[define.name] == nil, "Element is already added to the top flow")
    ExpGui.top_elements[define] = visible or false
end

--- Register a element define to be drawn to the left flow on join
--- @param define ExpElement
--- @param visible ExpGui.VisibleCallback | boolean | nil
function ExpGui.add_left_element(define, visible)
    assert(ExpGui.left_elements[define.name] == nil, "Element is already added to the left flow")
    ExpGui.left_elements[define] = visible or false

end

--- Register a element define to be drawn to the relative flow on join
--- @param define ExpElement
--- @param visible ExpGui.VisibleCallback | boolean | nil
function ExpGui.add_relative_element(define, visible)
    assert(ExpGui.relative_elements[define.name] == nil, "Element is already added to the relative flow")
    ExpGui.relative_elements[define] = visible or false
end

--- Register a element define to be drawn to the top flow on join
--- @param define ExpElement
--- @param player LuaPlayer
--- @return LuaGuiElement
function ExpGui.get_top_element(define, player)
    return player_elements[player.index].top[define.name]
end

--- Register a element define to be drawn to the left flow on join
--- @param define ExpElement
--- @param player LuaPlayer
--- @return LuaGuiElement
function ExpGui.get_left_element(define, player)
    return player_elements[player.index].left[define.name]
end

--- Register a element define to be drawn to the relative flow on join
--- @param define ExpElement
--- @param player LuaPlayer
--- @return LuaGuiElement
function ExpGui.get_relative_element(define, player)
    return player_elements[player.index].relative[define.name]
end

--- Ensure all the correct elements are visible and exist
--- @param player LuaPlayer
--- @param element_defines table<ExpElement, ExpGui.VisibleCallback | boolean>
--- @param elements LuaGuiElement[]
--- @param parent LuaGuiElement
local function ensure_elements(player, element_defines, elements, parent)
    local done = {}
    for define, visible in pairs(element_defines) do
        local element = elements[define.name]
        if not element then
            element = define(parent)
        end

        if type(visible) == "function" then
            visible = visible(player, element)
        end
        element.visible = visible
        done[define.name] = true
    end

    for name, element in pairs(elements) do
        if not done[name] then
            element.destroy()
            elements[name] = nil
        end
    end
end

--- Ensure all elements have been created
--- @param event EventData.on_player_created | EventData.on_player_joined_game
function ExpGui._ensure_elements(event)
    local player = assert(game.get_player(event.player_index))
    local elements = player_elements[event.player_index]
    ensure_elements(player, ExpGui.top_elements, elements.top, player.gui.top)
    ensure_elements(player, ExpGui.left_elements, elements.left, player.gui.left)
    ensure_elements(player, ExpGui.relative_elements, elements.relative, player.gui.relative)
end

--- Rerun the visible check for relative elements
--- @param event EventData.on_gui_opened
local function on_gui_opened(event)
    local player = ExpGui.get_player(event)
    local original_element = event.element

    for define, visible in pairs(ExpGui.relative_elements) do
        local element = ExpGui.get_relative_element(define, player)

        if type(visible) == "function" then
            visible = visible(player, element)
        end
        element.visible = visible

        if visible then
            event.element = element
            --- @diagnostic disable-next-line invisible
            define:_raise_event(event)
        end
    end

    event.element = original_element
end

local e = defines.events
local events = {
    [e.on_player_created] = ExpGui._ensure_elements,
    [e.on_player_joined_game] = ExpGui._ensure_elements,
    [e.on_gui_opened] = on_gui_opened,
}

ExpGui.events = events
return ExpGui

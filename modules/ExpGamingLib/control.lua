--[[
Explosive Gaming

This file can be used with permission but this and the credit below must remain in the file.
Contact a member of management on our discord to seek permission to use our code.
Any changes that you may make to the code are yours but that does not make the script yours.
Discord: https://discord.gg/r6dC2uK
]]
--Please Only Edit Below This Line-----------------------------------------------------------

--- Adds some common functions used though out all ExpGaming modules
-- @module ExpGamingLib
-- @alias ExpLib
-- @author Cooldude2606
local module_verbose = false -- there is no verbose in this file so true will do nothing
local ExpLib = {}

--- Loads a table into _G even when sandboxed; will not overwrite values or append to tables; will not work during runtime to avoid desyncs
-- @usage unpack_to_G{key1='foo',key2='bar'}
-- @tparam table tbl table to be unpacked
function ExpLib.unpack_to_G(tbl)
    if not type(tbl) == 'table' or game then return end
    for key,value in pairs(tbl) do
        if not _G[key] then rawset(_G,key,value) end
    end
end

--- Used to get the current ENV with all _G keys removed; useful when saving function to global
-- @usage get_env() returns current ENV with _G keys removed
-- @treturn table the env table with _G keys removed
function ExpLib.get_env()
    local level = 2
    local env = setmetatable({},{__index=_G})
    while true do
        if not debug.getinfo(level-1) then break end
        local i = 1
        while true do
            local name, value = debug.getlocal(level,i)
            if not name then break else env[name] = value end
            i=i+1
        end
        level=level+1
        if debug.getinfo(level-1).namewhat == 'global' then break end
    end
    return env
end

--- Compear types faster for faster valadation of prams
-- @usage is_type('foo','string') -- return true
-- @usage is_type('foo') -- return false
-- @param v the value to be tested
-- @tparam[opt=nil] string test_type the type to test for if not given then it tests for nil
-- @treturn bolean is v of type test_type
function ExpLib.is_type(v,test_type)
    return test_type and v and type(v) == test_type or not test_type and not v or false 
end

--- Will return a value of any type to the player/server console, allows colour for in-game players
-- @usage player_return('Hello, World!') -- returns 'Hello, World!' to game.player or server console
-- @usage player_return('Hello, World!','green') -- returns 'Hello, World!' to game.player with colour green or server console
-- @usage player_return('Hello, World!',nil,player) -- returns 'Hello, World!' to the given player
-- @param rtn any value of any type that will be returned to the player or console
-- @tparam[opt=defines.colour.white] ?defines.color|string colour the colour of the text for the player, ingroned when printing to console
-- @tparam[opt=game.player] LuaPlayer player  the player that return will go to, if no game.player then returns to server
function ExpLib.player_return(rtn,colour,player)
    local colour = ExpLib.is_type(colour) == 'table' and colour or defines.textcolor[colour] ~= defines.color.white and defines.textcolor[colour] or defines.color[colour]
    local player = player or game.player
    local function _return(callback,rtn)
        if ExpLib.is_type(rtn,'table') then 
            -- test for: userdata, locale string, table with __tostring meta method, any other table
            if ExpLib.is_type(rtn.__self,'userdata') then callback('Cant Display Userdata',colour)
            elseif ExpLib.is_type(rtn[1],'string') and string.find(rtn[1],'.+[.].+') and not string.find(rtn[1],'%s') then callback(rtn,colour)
            elseif getmetatable(rtn) ~= nil and not tostring(rtn):find('table: 0x') then callback(tostring(rtn),colour)
            else callback(table.tostring(rtn),colour) end
            -- test for: function
        elseif ExpLib.is_type(rtn,'function') then callback('Cant Display Functions',colour)
        -- else just call tostring
        else callback(tostring(rtn),colour) end
    end
    if player then
        -- allows any vaild player identifier to be used
        local player = Game.get_player(player)
        if not player then error('Invalid Player given to player_return',2) end
        -- plays a nice sound that is different to normal message sound
        player.play_sound{path='utility/scenario_message'}
        _return(player.print,rtn)
    else _return(rcon.print,rtn) end
end

--- Convert ticks to hours
-- @usage tick_to_hour(216001) -- return 1
-- @tparam number tick tick to convert to hours
-- @treturn number the number of whole hours from this tick
function ExpLib.tick_to_hour(tick)
    if not ExpLib.is_type(tick,'number') then return 0 end
    return math.floor(tick/(216000*game.speed))
end

--- Convert ticks to minutes
-- @usage tick_to_hour(3601) -- return 1
-- @tparam number tick tick to convert to minutes
-- @treturn number the number of whole minutes from this tick
function ExpLib.tick_to_min (tick)
    if not ExpLib.is_type(tick,'number') then return 0 end
    return math.floor(tick/(3600*game.speed))
end

--- Converts a tick into a clean format for end user
-- @usage tick_to_display_format(3600) -- return '1.00 M'
-- @usage tick_to_display_format(234000) -- return '1 H 5 M'
-- @tparam number tick the tick to convert
-- @treturn string the formated string
function ExpLib.tick_to_display_format(tick)
    if not ExpLib.is_type(tick,'number') then return '0H 0M' end
    if ExpLib.tick_to_min(tick) < 10 then
		return string.format('%.2f M',tick/(3600*game.speed))
	else
        return string.format('%d H %d M',
            ExpLib.tick_to_hour(tick),
            ExpLib.tick_to_min(tick)-60*ExpLib.tick_to_hour(tick)
        )
	end
end

--- Used as a way to view the structure of a gui, used for debuging
-- @usage Gui_tree(root) returns all children of gui recusivly
-- @tparam LuaGuiElement root the root to start the tree from
-- @treturn table the table that describes the gui
function ExpLib.gui_tree(root)
    if not ExpLib.is_type(root,'table') or not root.valid then error('Invalid Gui Element given to gui_tree',2) end
    local tree = {}
    for _,child in pairs(root.children) do
        if #child.children > 0 then
            if child.name then tree[child.name] = ExpLib.gui_tree(child)
            else table.insert(tree,ExpLib.gui_tree(child)) end
        else
            if child.name then tree[child.name] = child.type
            else table.insert(tree,child.type) end
        end
    end
    return tree
end

-- unpacks lib to _G on module init
function ExpLib.on_init(self)
    self:unpack_to_G()
end

return ExpLib
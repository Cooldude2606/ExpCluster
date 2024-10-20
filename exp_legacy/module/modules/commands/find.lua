--[[-- Commands Module - Find
    - Adds a command that zooms in on the given player
    @commands Find
]]

local Commands = require("modules.exp_legacy.expcore.commands") --- @dep expcore.commands
require("modules.exp_legacy.config.expcore.command_general_parse")

--- Find a player on your map.
-- @command find-on-map
-- @tparam LuaPlayer the player to find on the map
Commands.new_command("find-on-map", { "expcom-find.description" }, "Find a player on your map.")
    :add_param("player", false, "player-online")
    :add_alias("find", "zoom-to")
    :register(function(player, action_player)
        local position = action_player.physical_position
        player.zoom_to_world(position, 1.75)
        return Commands.success -- prevents command complete message from showing
    end)

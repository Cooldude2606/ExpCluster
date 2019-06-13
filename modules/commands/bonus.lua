local Commands = require 'expcore.commands'
local Roles = require 'expcore.roles'
local Event = require 'utils.event'
local Game = require 'utils.game'
local Store = require 'expcore.store'
local config = require 'config.bonuses'
require 'config.expcore-commands.parse_general'

local bonus_store =
Store.register(function(value,category)
    local player = Game.get_player_from_any(category)
    for bonus,min_max in pairs(config) do
        local increase = min_max[2]*value
        player[bonus] = min_max[1]+increase
    end
end)

Commands.new_command('bonus','Changes the amount of bonus you receive')
:add_param('amount','integer-range',0,50)
:register(function(player,amount)
    local percent = amount/100
    Store.set(bonus_store,player.name,percent)
end)

Event.add(defines.events.on_player_respawned,function(event)
    local player = Game.get_player_by_index(event.player_index)
    local value = Store.get(bonus_store,player.name)
    if value then
        for bonus,min_max in pairs(config) do
            local increase = min_max[2]*value
            player[bonus] = min_max[1]+increase
        end
    end
end)

Event.add(defines.events.on_pre_player_died,function(event)
    local player = Game.get_player_by_index(event.player_index)
    if Roles.player_has_flag(player,'instance-respawn') then
        player.ticks_to_respawn = 120
        -- manually dispatch death event because it is not fired when ticks_to_respawn is set pre death
        Event.dispatch{
            name=defines.events.on_player_died,
            tick=event.tick,
            player_index=event.player_index,
            cause = event.cause
        }
    end
end)

local function role_update(event)
    local player = Game.get_player_by_index(event.player_index)
    if not Roles.player_allowed(player,'command/bonus') then
        Store.clear(bonus_store,player.name)
    end
end

Event.add(Roles.events.on_role_assigned,role_update)
Event.add(Roles.events.on_role_unassigned,role_update)
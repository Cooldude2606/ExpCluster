--- Config for the different action buttons that show on the player list;
-- each button has the button define(s) given along side an auth function, and optional reason callback;
-- if a reason callback is used then Store.set(action_name_store,player.name,'BUTTON_NAME') should be called during on_click;
-- buttons can be removed from the gui by commenting them out of the config at the bottom of this file;
-- the key used for the name of the button is the permission name used by the role system;
-- @config Player-List

local Gui = require 'expcore.gui' --- @dep expcore.gui
local Roles = require 'expcore.roles' --- @dep expcore.roles
local Store = require 'expcore.store' --- @dep expcore.store
local Game = require 'utils.game' --- @dep utils.game
local Reports = require 'modules.control.reports' --- @dep modules.control.reports
local Warnings = require 'modules.control.warnings' --- @dep modules.control.warnings
local Jail = require 'modules.control.jail' --- @dep modules.control.jail
local Colors = require 'resources.color_presets' --- @dep resources.color_presets
local format_chat_player_name = ext_require('expcore.common','format_chat_player_name') --- @dep expcore.common

local action_player_store = 'gui.left.player-list.action-player'
local action_name_store = 'gui.left.player-list.action-name'

-- common style used by all action buttons
local function tool_button_style(style)
    Gui.set_padding_style(style,-1,-1,-1,-1)
    style.height = 28
    style.width = 28
end

-- auth that will only allow when on player's of lower roles
local function auth_lower_role(player,action_player_name)
    local player_highest = Roles.get_player_highest_role(player)
    local action_player_highest = Roles.get_player_highest_role(action_player_name)
    if player_highest.index < action_player_highest.index then
        return true
    end
end

-- gets the action player and a coloured name for the action to be used on
local function get_action_player_name(player)
    local action_player_name = Store.get(action_player_store,player.name)
    local action_player = Game.get_player_from_any(action_player_name)
    local action_player_name_color = format_chat_player_name(action_player)
    return action_player,action_player_name_color
end

-- telports one player to another
local function teleport(from_player,to_player)
    local surface = to_player.surface
    local position = surface.find_non_colliding_position('character',to_player.position,32,1)
    if not position then return false end -- return false if no new position
    if from_player.driving then from_player.driving = false end -- kicks a player out a vehicle if in one
    from_player.teleport(position,surface)
    return true
end

--- Teleports the user to the action player
-- @element goto_player
local goto_player =
Gui.new_button()
:set_sprites('utility/export')
:set_tooltip{'player-list.goto-player'}
:set_style('tool_button',tool_button_style)
:on_click(function(player,element)
    local action_player_name = get_action_player_name(player)
    local action_player = Game.get_player_from_any(action_player_name)
    if not player.character or not action_player.character then
        player.print({'expcore-commands.reject-player-alive'},Colors.orange_red)
    else
        teleport(player,action_player)
    end
end)

--- Teleports the action player to the user
-- @element bring_player
local bring_player =
Gui.new_button()
:set_sprites('utility/import')
:set_tooltip{'player-list.bring-player'}
:set_style('tool_button',tool_button_style)
:on_click(function(player,element)
    local action_player_name = get_action_player_name(player)
    local action_player = Game.get_player_from_any(action_player_name)
    if not player.character or not action_player.character then
        player.print({'expcore-commands.reject-player-alive'},Colors.orange_red)
    else
        teleport(action_player,player)
    end
end)

--- Kills the action player, if there are alive
-- @element kill_player
local kill_player =
Gui.new_button()
:set_sprites('utility/too_far')
:set_tooltip{'player-list.kill-player'}
:set_style('tool_button',tool_button_style)
:on_click(function(player,element)
    local action_player_name = get_action_player_name(player)
    local action_player = Game.get_player_from_any(action_player_name)
    if action_player.character then
        action_player.character.die()
    else
        player.print({'expcom-kill.already-dead'},Colors.orange_red)
    end
end)

--- Reports the action player, requires a reason to be given
-- @element report_player
local report_player =
Gui.new_button()
:set_sprites('utility/spawn_flag')
:set_tooltip{'player-list.report-player'}
:set_style('tool_button',tool_button_style)
:on_click(function(player,element)
    local action_player_name = get_action_player_name(player)
    if Reports.is_reported(action_player_name,player.name) then
        player.print({'expcom-report.already-reported'},Colors.orange_red)
    else
        Store.set(action_name_store,player.name,'command/report')
    end
end)

local function report_player_callback(player,reason)
    local action_player_name,action_player_name_color = get_action_player_name(player)
    local by_player_name_color = format_chat_player_name(player)
    game.print{'expcom-report.non-admin',action_player_name_color,reason}
    Roles.print_to_roles_higher('Trainee',{'expcom-report.admin',action_player_name_color,by_player_name_color,reason})
    Reports.report_player(action_player_name,player.name,reason)
end

--- Gives the action player a warning, requires a reason
-- @element warn_player
local warn_player =
Gui.new_button()
:set_sprites('utility/spawn_flag')
:set_tooltip{'player-list.warn-player'}
:set_style('tool_button',tool_button_style)
:on_click(function(player,element)
    Store.set(action_name_store,player.name,'command/give-warning')
end)

local function warn_player_callback(player,reason)
    local action_player_name,action_player_name_color = get_action_player_name(player)
    local by_player_name_color = format_chat_player_name(player)
    game.print{'expcom-warnings.received',action_player_name_color,by_player_name_color,reason}
    Warnings.add_warning(action_player_name,player.name,reason)
end

--- Jails the action player, requires a reason
-- @element jail_player
local jail_player =
Gui.new_button()
:set_sprites('utility/item_editor_icon')
:set_tooltip{'player-list.jail-player'}
:set_style('tool_button',tool_button_style)
:on_click(function(player,element)
    local action_player_name,action_player_name_color = get_action_player_name(player)
    if Jail.is_jailed(action_player_name) then
        player.print({'expcom-jail.already-jailed',action_player_name_color},Colors.orange_red)
    else
        Store.set(action_name_store,player.name,'command/jail')
    end
end)

local function jail_player_callback(player,reason)
    local action_player_name,action_player_name_color = get_action_player_name(player)
    local by_player_name_color = format_chat_player_name(player)
    game.print{'expcom-jail.give',action_player_name_color,by_player_name_color,reason}
    Jail.jail_player(action_player_name,player.name,reason)
end

--- Temp bans the action player, requires a reason
-- @element temp_ban_player
local temp_ban_player =
Gui.new_button()
:set_sprites('utility/clock')
:set_tooltip{'player-list.temp-ban-player'}
:set_style('tool_button',tool_button_style)
:on_click(function(player,element)
    local action_player_name,action_player_name_color = get_action_player_name(player)
    if Jail.is_jailed(action_player_name) then
        player.print({'expcom-jail.already-banned',action_player_name_color},Colors.orange_red)
    else
        Store.set(action_name_store,player.name,'command/temp-ban')
    end
end)

local function temp_ban_player_callback(player,reason)
    local action_player,action_player_name_color = get_action_player_name(player)
    local by_player_name_color = format_chat_player_name(player)
    game.print{'expcom-jail.temp-ban',action_player_name_color,by_player_name_color,reason}
    Jail.temp_ban_player(action_player,player.name,reason)
end

--- Kicks the action player, requires a reason
-- @element kick_player
local kick_player =
Gui.new_button()
:set_sprites('utility/warning_icon')
:set_tooltip{'player-list.kick-player'}
:set_style('tool_button',tool_button_style)
:on_click(function(player,element)
    Store.set(action_name_store,player.name,'command/kick')
end)

local function kick_player_callback(player,reason)
    local action_player = get_action_player_name(player)
    game.kick_player(action_player,reason)
end

--- Bans the action player, requires a reason
-- @element ban_player
local ban_player =
Gui.new_button()
:set_sprites('utility/danger_icon')
:set_tooltip{'player-list.ban-player'}
:set_style('tool_button',tool_button_style)
:on_click(function(player,element)
    Store.set(action_name_store,player.name,'command/ban')
end)

local function ban_player_callback(player,reason)
    local action_player = get_action_player_name(player)
    game.ban_player(action_player,reason)
end

return {
    ['command/teleport'] = {
        auth=function(player,action_player)
            return player.name ~= action_player.name
        end, -- cant teleport to your self
        goto_player,
        bring_player
    },
    ['command/kill'] = {
        auth=function(player,action_player)
            if player.name == action_player.name then
                return true
            elseif Roles.player_allowed(player,'command/kill/always') then
                return auth_lower_role(player,action_player)
            end
        end, -- player must be lower role, or your self
        kill_player
    },
    ['command/report'] = {
        auth=function(player,action_player)
            if not Roles.player_allowed(player,'command/give-warning') then
                return not Roles.player_has_flag(action_player,'report-immune')
            end
        end, -- can report any player that isn't immune and you aren't able to give warnings
        reason_callback=report_player_callback,
        report_player
    },
    ['command/give-warning'] = {
        auth=auth_lower_role, -- warn a lower user, replaces report
        reason_callback=warn_player_callback,
        warn_player
    },
    ['command/jail'] = {
        auth=auth_lower_role,
        reason_callback=jail_player_callback,
        jail_player
    },
    ['command/temp-ban'] = {
        auth=auth_lower_role,
        reason_callback=temp_ban_player_callback,
        temp_ban_player
    },
    ['command/kick'] = {
        auth=auth_lower_role,
        reason_callback=kick_player_callback,
        kick_player
    },
    ['command/ban'] = {
        auth=auth_lower_role,
        reason_callback=ban_player_callback,
        ban_player
    }
}
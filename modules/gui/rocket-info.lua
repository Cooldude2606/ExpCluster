--[[-- Gui Module - Rocket Info
    - Adds a rocket infomation gui which shows general stats, milestones and build progress of rockets
    @gui Rocket-Info
    @alias rocket_info
]]

local Gui = require 'expcore.gui' --- @dep expcore.gui
local Roles = require 'expcore.roles' --- @dep expcore.roles
local Event = require 'utils.event' --- @dep utils.event
local config = require 'config.rockets' --- @dep config.rockets
local format_time = ext_require('expcore.common','format_time') --- @dep expcore.common
local Colors = require 'resources.color_presets' --- @dep resources.color_presets
local Rockets = require 'modules.control.rockets' --- @dep modules.control.rockets

--- Gets if a player is allowed to use the action buttons
local function player_allowed(player,action)
    if not config.progress['allow_'..action] then
        return false
    end

    if config.progress[action..'_admins_only'] and not player.admin then
        return false
    end

    if config.progress[action..'_role_permission'] and not Roles.player_allowed(player,config.progress[action..'_role_permission']) then
        return false
    end

    return true
end

--- Used on the name label to allow zoom to map
-- @element zoom_to_map
local zoom_to_map_name = Gui.uid_name()
Gui.on_click(zoom_to_map_name,function(event)
    local rocket_silo_name = event.element.parent.caption
    local rocket_silo = Rockets.get_silo_entity(rocket_silo_name)
    event.player.zoom_to_world(rocket_silo.position,2)
end)

--- Used to launch the rocket, when it is ready
-- @element launch_rocket
local launch_rocket =
Gui.new_button()
:set_sprites('utility/center')
:set_tooltip{'rocket-info.launch-tooltip'}
:set_embedded_flow(function(element,rocket_silo_name)
    return 'launch-'..rocket_silo_name
end)
:set_style('tool_button',function(style)
    Gui.set_padding_style(style,-2,-2,-2,-2)
    style.width = 16
    style.height = 16
end)
:on_click(function(player,element)
    local rocket_silo_name = element.parent.name:sub(8)
    local silo_data = Rockets.get_silo_data_by_name(rocket_silo_name)
    if silo_data.entity.launch_rocket() then
        silo_data.awaiting_reset = true
        element.enabled = false
        local progress_label = element.parent.parent[rocket_silo_name].label
        progress_label.caption = {'rocket-info.progress-launched'}
        progress_label.style.font_color = Colors.green
    else
        player.print({'rocket-info.launch-failed'},Colors.orange_red)
    end
end)

--- Used to toggle the auto launch on a rocket
-- @element toggle_rocket
local toggle_rocket =
Gui.new_button()
:set_sprites('utility/play')
:set_tooltip{'rocket-info.toggle-rocket-tooltip'}
:set_embedded_flow(function(element,rocket_silo_name)
    return 'toggle-'..rocket_silo_name
end)
:set_style('tool_button',function(style)
    Gui.set_padding_style(style,-2,-2,-2,-2)
    style.width = 16
    style.height = 16
end)
:on_click(function(player,element)
    local rocket_silo_name = element.parent.name:sub(8)
    local rocket_silo = Rockets.get_silo_entity(rocket_silo_name)
    if rocket_silo.auto_launch then
        element.sprite = 'utility/play'
        element.tooltip = {'rocket-info.toggle-rocket-tooltip'}
        rocket_silo.auto_launch = false
    else
        element.sprite = 'utility/stop'
        element.tooltip = {'rocket-info.toggle-rocket-tooltip-disabled'}
        rocket_silo.auto_launch = true
    end
end)

--- Used to toggle the visibility of the different sections
-- @element toggle_section
local toggle_section =
Gui.new_button()
:set_sprites('utility/expand_dark','utility/expand')
:set_tooltip{'rocket-info.toggle-section-tooltip'}
:set_style('tool_button',function(style)
    Gui.set_padding_style(style,-2,-2,-2,-2)
    style.height = 20
    style.width = 20
end)
:on_click(function(player,element)
    local flow_name = element.parent.caption
    local flow = element.parent.parent.parent[flow_name]
    if Gui.toggle_visible(flow) then
        element.sprite = 'utility/collapse_dark'
        element.hovered_sprite = 'utility/collapse'
        element.tooltip = {'rocket-info.toggle-section-collapse-tooltip'}
    else
        element.sprite = 'utility/expand_dark'
        element.hovered_sprite = 'utility/expand'
        element.tooltip = {'rocket-info.toggle-section-tooltip'}
    end
end)

--- Used to create the three different sections
local function create_section(container,section_name,table_size)
    -- Header for the section
    local header_area = Gui.create_header(
        container,
        {'rocket-info.section-caption-'..section_name},
        {'rocket-info.section-tooltip-'..section_name},
        true,
        section_name..'-header'
    )

    -- Right aligned button to toggle the section
    header_area.caption = section_name
    toggle_section(header_area)

    -- Table used to store the data
    local flow_table = Gui.create_scroll_table(container,table_size,215,section_name)
    flow_table.parent.visible = false

end

--[[ Creates the main structure for the gui
    element
    > container

    >> stats-header
    >>> stats
    >>>> toggle_section.name
    >> stats
    >>> table

    >> milestones-header
    >>> milestones
    >>>> toggle_section.name
    >> milestones
    >>> table

    >> progress-header
    >>> progress
    >>>> toggle_section.name
    >> progress
    >>> table
]]
local function generate_container(player,element)
    Gui.set_padding(element,1,2,2,2)
    element.style.minimal_width = 200

    -- main container which contains the other elements
    local container =
    element.add{
        name='container',
        type='frame',
        direction='vertical',
        style='window_content_frame_packed'
    }
    Gui.set_padding(container)

    if config.stats.show_stats then
        create_section(container,'stats',2)
    end

    if config.milestones.show_milestones then
        create_section(container,'milestones',2)
    end

    if config.progress.show_progress then
        local col_count = 3
        if player_allowed(player,'remote_launch') then col_count = col_count+1 end
        if player_allowed(player,'toggle_active') then col_count = col_count+1 end
        create_section(container,'progress',col_count)
        --- label used when no active silos
        container.progress.add{
            type='label',
            name='no_silos',
            caption={'rocket-info.progress-no-silos'}
        }
    end

end

--[[ Creates a text label followed by a data label, or updates them if already present
    element
    > "data_name_extra"-label
    > "data_name_extra"
    >> label
]]
local function create_label_value_pair(element,data_name,value,tooltip,extra)
    local data_name_extra = extra and data_name..extra or data_name
    if element[data_name_extra] then
        element[data_name_extra].label.caption = value
        element[data_name_extra].label.tooltip = tooltip
    else
        --- Label used with the data
        element.add{
            type='label',
            name=data_name_extra..'-label',
            caption={'rocket-info.data-caption-'..data_name,extra},
            tooltip={'rocket-info.data-tooltip-'..data_name,extra}
        }
        --- Right aligned label to store the data
        local right_flow = Gui.create_alignment(element,data_name_extra)
        right_flow.add{
            type='label',
            name='label',
            caption=value,
            tooltip=tooltip
        }
    end
end

--- Creates a text and data label using times as the data
local function create_label_value_pair_time(element,data_name,raw_value,no_hours,extra)
    local value = no_hours and format_time(raw_value,{minutes=true,seconds=true}) or format_time(raw_value)
    local tooltip = format_time(raw_value,{hours=not no_hours,minutes=true,seconds=true,long=true})
    create_label_value_pair(element,data_name,value,tooltip,extra)
end

--- Adds the different data values to the stats section
local function generate_stats(player,frame)
    if not config.stats.show_stats then return end
    local element = frame.container.stats.table
    local force_name = player.force.name
    local force_rockets = Rockets.get_rocket_count(force_name)
    local stats = Rockets.get_stats(force_name)

    if config.stats.show_first_rocket then
        create_label_value_pair_time(element,'first-launch',stats.first_launch or 0)
    end

    if config.stats.show_last_rocket then
        create_label_value_pair_time(element,'last-launch',stats.last_launch or 0)
    end

    if config.stats.show_fastest_rocket then
        create_label_value_pair_time(element,'fastest-launch',stats.fastest_launch or 0,true)
    end

    if config.stats.show_total_rockets then
        local total_rockets = Rockets.get_game_rocket_count()
        total_rockets = total_rockets == 0 and 1 or total_rockets
        local percentage = math.round(force_rockets/total_rockets,3)*100
        create_label_value_pair(element,'total-rockets',force_rockets,{'rocket-info.value-tooltip-total-rockets',percentage})
    end

    if config.stats.show_game_avg then
        local avg = force_rockets > 0 and math.floor(game.tick/force_rockets) or 0
        create_label_value_pair_time(element,'avg-launch',avg,true)
    end

    for _,avg_over in pairs(config.stats.rolling_avg) do
        local avg = Rockets.get_rolling_average(force_name,avg_over)
        create_label_value_pair_time(element,'avg-launch-n',avg,true,avg_over)
    end

end

--- Creates the list of milestones
local function generate_milestones(player,frame)
    if not config.milestones.show_milestones then return end
    local element = frame.container.milestones.table
    local force_name = player.force.name
    local force_rockets = Rockets.get_rocket_count(force_name)

    for _,milestone in ipairs(config.milestones) do
        if milestone <= force_rockets then
            local time = Rockets.get_rocket_time(force_name,milestone)
            create_label_value_pair_time(element,'milestone-n',time,false,milestone)
        else
            create_label_value_pair_time(element,'milestone-n',0,false,milestone)
            break
        end
    end
end

--- Creats the different buttons used with the rocket silos
local function generate_progress_buttons(player,element,silo_data)
    local silo_name = silo_data.name
    local rocket_silo = silo_data.entity
    local status = rocket_silo.status == defines.entity_status.waiting_to_launch_rocket
    local active = rocket_silo.auto_launch

    if player_allowed(player,'toggle_active') then
        local button_element = element['toggle-'..silo_name]

        if button_element then
            button_element = button_element[toggle_rocket.name]
        else
            button_element = toggle_rocket(element,silo_name)
        end

        if active then
            button_element.tooltip = {'rocket-info.toggle-rocket-tooltip'}
            button_element.sprite = 'utility/stop'
        else
            button_element.tooltip = {'rocket-info.toggle-rocket-tooltip-disabled'}
            button_element.sprite = 'utility/play'
        end
    end

    if player_allowed(player,'remote_launch') then
        local button_element = element['launch-'..silo_name]

        if button_element then
            button_element = button_element[launch_rocket.name]
        else
            button_element = launch_rocket(element,silo_name)
        end

        if silo_data.awaiting_reset then
            button_element.enabled = false
        else
            button_element.enabled = status
        end
    end

end

--[[ Creates build progress section
    element
    > toggle-"silo_name" (generate_progress_buttons)
    > launch-"silo_name" (generate_progress_buttons)
    > label-x-"silo_name"
    >> "silo_name"
    > label-y-"silo_name"
    >> "silo_name"
    > "silo_name"
    >> label
]]
local function generate_progress(player,frame)
    if not config.progress.show_progress then return end
    local element = frame.container.progress.table
    local force = player.force
    local force_name = force.name
    local force_silos = Rockets.get_silos(force_name)

    if not force_silos or table.size(force_silos) == 0 then
        element.parent.no_silos.visible = true

    else
        element.parent.no_silos.visible = false

        for _,silo_data in pairs(force_silos) do
            local silo_name = silo_data.name
            if not silo_data.entity or not silo_data.entity.valid then
                force_silos[silo_name] = nil
                Gui.destory_if_valid(element['toggle-'..silo_name])
                Gui.destory_if_valid(element['launch-'..silo_name])
                Gui.destory_if_valid(element['label-x-'..silo_name])
                Gui.destory_if_valid(element['label-y-'..silo_name])
                Gui.destory_if_valid(element[silo_name])

            elseif not element[silo_name] then
                local entity = silo_data.entity
                local progress = entity.rocket_parts
                local pos = {
                    x=entity.position.x,
                    y=entity.position.y
                }

                generate_progress_buttons(player,element,silo_data)

                --- Creates two flows and two labels for the X and Y position
                local name = config.progress.allow_zoom_to_map and zoom_to_map_name or nil
                local tooltip = config.progress.allow_zoom_to_map and {'rocket-info.progress-label-tooltip'} or nil
                local flow_x = element.add{
                    type='flow',
                    name='label-x-'..silo_name,
                    caption=silo_name
                }
                Gui.set_padding(flow_x,0,0,1,2)
                flow_x.add{
                    type='label',
                    name=name,
                    caption={'rocket-info.progress-x-pos',pos.x},
                    tooltip=tooltip
                }

                local flow_y = element.add{
                    type='flow',
                    name='label-y-'..silo_name,
                    caption=silo_name
                }
                Gui.set_padding(flow_y,0,0,1,2)
                flow_y.add{
                    type='label',
                    name=name,
                    caption={'rocket-info.progress-y-pos',pos.y},
                    tooltip=tooltip
                }

                --- Creates the progress value which is right aligned
                local right_flow = Gui.create_alignment(element,silo_name)
                right_flow.add{
                    type='label',
                    name='label',
                    caption={'rocket-info.progress-caption',progress},
                    tooltip={'rocket-info.progress-tooltip',silo_data.launched or 0}
                }

            else
                local entity = silo_data.entity
                local progress = entity.rocket_parts
                local status = entity.status == 21

                local label = element[silo_name].label
                label.caption = {'rocket-info.progress-caption',progress}
                label.tooltip = {'rocket-info.progress-tooltip',silo_data.launched or 0}

                if status and silo_data.awaiting_reset then
                    label.caption = {'rocket-info.progress-launched'}
                    label.style.font_color = Colors.green
                elseif status then
                    label.caption = {'rocket-info.progress-caption',100}
                    label.style.font_color = Colors.cyan
                else
                    silo_data.awaiting_reset = false
                    label.style.font_color = Colors.white
                end

                generate_progress_buttons(player,element,silo_data)

            end
        end

    end
end

--- Registers the rocket info
-- @element rocket_info
local rocket_info =
Gui.new_left_frame('gui/rocket-info')
:set_sprites('entity/rocket-silo')
:set_post_authenticator(function(player,define_name)
    return player.force.rockets_launched > 0 and Gui.classes.toolbar.allowed(player,define_name)
end)
:set_open_by_default(function(player,define_name)
    return player.force.rockets_launched > 0
end)
:set_direction('vertical')
:on_creation(function(player,element)
    generate_container(player,element)
    generate_stats(player,element)
    generate_milestones(player,element)
    generate_progress(player,element)
end)
:on_update(function(player,element)
    generate_stats(player,element)
    generate_milestones(player,element)
    generate_progress(player,element)
end)

--- Event used to update the stats and the hui when a rocket is launched
Event.add(defines.events.on_rocket_launched,function(event)
    local force = event.rocket_silo.force
    local rockets_launched = force.rockets_launched
    local first_rocket = rockets_launched == 1

    --- Updates all the guis (and toolbar since the button may now be visible)
    for _,player in pairs(force.players) do
        rocket_info:update(player)
        if first_rocket then
            Gui.update_toolbar(player)
            rocket_info:toggle(player)
        end
    end
end)

--- Adds a silo to the list when it is built
local function on_built(event)
    local entity = event.created_entity
    if entity.valid and entity.name == 'rocket-silo' then
        local force = entity.force

        for _,player in pairs(force.players) do
            local frame = rocket_info:get_frame(player)
            generate_progress(player,frame)
        end
    end
end

Event.add(defines.events.on_built_entity,on_built)
Event.add(defines.events.on_robot_built_entity,on_built)

--- Optimised update for only the build progress
Event.on_nth_tick(150,function()
    for _,force in pairs(game.forces) do
        local silos = Rockets.get_silos(force.name)
        if #silos > 0 then
            for _,player in pairs(force.connected_players) do
                local frame = rocket_info:get_frame(player)
                generate_progress(player,frame)
            end
        end
    end
end)

--- Makes sure the right buttons are present when role changes
Event.add(Roles.events.on_role_assigned,rocket_info 'redraw')
Event.add(Roles.events.on_role_unassigned,rocket_info 'redraw')

return rocket_info
--[[-- Command Module - Help
Game command to list and search all registered commands in a nice format
@commands _system-ipc

--- Get all messages related to banning a player
/commands ban
-- Get the second page of results
/commands ban 2
]]

local Storage = require("modules/exp_util/storage")
local Commands = require("modules/exp_commands")

local PAGE_SIZE = 5

local search_cache = {}
Storage.register(search_cache, function(tbl)
    search_cache = tbl
end)

--- Format commands into a strings across multiple pages
--- @param commands { [string]: Commands.Command } The commands to split into pages
--- @param page_size number The number of requests to show per page
--- @return LocalisedString[][], number
local function format_as_pages(commands, page_size)
    local pages = { {} }
    local page_length = 0
    local current_page = 1
    local total = 0

    for _, command in pairs(commands) do
        total = total + 1
        page_length = page_length + 1
        if page_length > page_size then
            current_page = current_page + 1
            pages[current_page] = {}
            page_length = 1
        end

        local description
        if command.defined_at then
            --- @cast command Commands.ExpCommand
            description = { "", command.help_text[2], "- ", command.description }
        else
            description = command.description
        end

        local aliases = #command.aliases > 0 and { "exp-commands-help.aliases", table.concat(command.aliases, ", ") } or ""
        pages[current_page][page_length] = { "exp-commands-help.format", command.name, description, aliases }
    end

    return pages, total
end

Commands.new("commands", { "exp-commands-help.description" })
    :add_aliases{ "chelp", "helpp" }
    :optional("keyword", { "exp-commands-help.arg-keyword" }, Commands.types.string)
    :optional("page", { "exp-commands-help.arg-page" }, Commands.types.integer)
    :defaults{ keyword = "", page = 1 }
    :register(function(player, keyword, page)
        -- Allow listing of all commands
        local as_number = tonumber(keyword)
        local cache = search_cache[player.index]
        if as_number and page == 1 then
            keyword = cache and cache.keyword or ""
            page = as_number
        end

        keyword = keyword:lower()
        local pages, found
        if cache and cache.keyword == keyword then
            -- Cached value found, no search is needed
            pages = cache.pages
            found = cache.found
        else
            -- No cached value, so a search needs to be done
            local commands = Commands.search_for_player(keyword, player)
            pages, found = format_as_pages(commands, PAGE_SIZE)
            search_cache[player.index] = { keyword = keyword, pages = pages, found = found }
        end

        -- Error if no pages found
        if found == 0 then
            return Commands.status.success{ "exp-commands-help.no-results" }
        end

        local page_data = pages[page]
        if page_data == nil then
            -- Page number was out of range for this search
            return Commands.status.invalid_input{ "exp-commands-help.out-of-range", page, #pages }
        end

        -- Print selected page to the player
        Commands.print{ "exp-commands-help.header", keyword == "" and "<all>" or keyword }
        for _, command in pairs(page_data) do
            Commands.print(command)
        end

        return Commands.status.success{ "exp-commands-help.footer", found, page, #pages }
    end)

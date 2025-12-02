--[[-- ExpUtil - Module Loader
Provides a standard and extendable module loader used to limit side events from require and prevent double loading
Module loaders can add other module loaders without any issues, as long as it has not already been loaded
]]

local ExpUtil = require("modules/exp_util")
local event_hander = require("event_handler")

--- @class ExpModule
--- @field _loaded table<function, boolean>?
--- @field modules table<any, ExpModule>?
--- @field loaders table<any, fun(module: ExpModule)>?
--- @field loader_counts table<any, fun(output: fun(message: string))>?
--- @field events table<defines.events, fun(event: EventData)>?
--- @field on_nth_tick table<number, fun()>?
--- @field on_configuration_changed fun()?
--- @field add_remote_interface fun()?
--- @field add_commands fun()?
--- @field on_init fun()?
--- @field on_load fun()?

--- @class ExpUtil_ModuleLoader
local ModuleLoader = {}

--- @class ModuleLoader: ExpModule
ModuleLoader._prototype = {}

ModuleLoader._metatable = {
    __index = ModuleLoader._prototype,
    __class = "ModuleLoader",
}

--- Create a module loader
--- @param no_event_handler boolean?
--- @return ModuleLoader
function ModuleLoader.new(no_event_handler)
    local module_loader = setmetatable({
        modules = {},
        loaders = {},
    }, ModuleLoader._metatable)

    if not no_event_handler then
        module_loader:add_loader(event_hander.add_lib)
    end

    return module_loader
end

--- Create a module loader and a require closure.
--- This only exists to help with luals typing which doesn't recognise __call
--- @param no_event_handler boolean?
--- @return ModuleLoader, fun(module_path: string)
function ModuleLoader.closure(no_event_handler)
    local module_loader = ModuleLoader.new(no_event_handler)
    return module_loader, function(module_path)
        module_loader:require(module_path)
    end
end

--- Add a loader
--- @param loader fun(module: ExpModule)
--- @param no_error boolean?
function ModuleLoader._prototype:add_loader(loader, no_error)
    if table.array_contains(self.loaders, loader) then
        if no_error then return end
        error("Trying to register same loader twice: " .. ExpUtil.get_function_name(loader))
    end

    self.loaders[#self.loaders + 1] = loader
end

--- Add a collection of loaders
--- @param loaders table<any, fun(module: ExpModule)>
--- @param no_error boolean?
function ModuleLoader._prototype:add_loaders(loaders, no_error)
    for _, loader in pairs(loaders) do
        self:add_loader(loader, no_error)
    end
end

--- Add a module
--- @param module ExpModule
--- @param no_error boolean?
function ModuleLoader._prototype:add_module(module, no_error)
    if table.array_contains(self.modules, module) then
        if no_error then return end
        error("Trying to register same lib twice")
    end

    -- Add the module
    self.modules[#self.modules + 1] = module

    -- Add any sub modules / dependencies that need loading
    if module.modules then
        self:add_modules(module.modules, true)
    end

    -- Add any loaders the module defines
    if module.loaders then
        self:add_loaders(module.loaders, true)
    end
end

--- Add a collection of modules
--- @param modules table<any, ExpModule>
--- @param no_error boolean?
function ModuleLoader._prototype:add_modules(modules, no_error)
    for _, module in pairs(modules) do
        self:add_module(module, no_error)
    end
end

--- Require then add a module
--- @param module_path string
function ModuleLoader._prototype:require(module_path)
    local module = require(module_path)
    if type(module) == "table" then
        self:add_module(module)
    end
end

--- Load all modules that have not been loaded
function ModuleLoader._prototype:load_modules()
    for _, module in ipairs(self.modules) do
        local loaded = module._loaded or {}
        for _, loader in ipairs(self.loaders) do
            if not loaded[loader] then
                loader(module)
                loaded[loader] = true
            end
        end
        module._loaded = loaded
    end
end

--- Log the counts of the loader
--- @param output fun(message: string)?
function ModuleLoader._prototype:output_counts(output)
    output = output or log
    output(#self.loaders .. " loaders")
    output(#self.modules .. " modules")

    -- If event handler is used, then log its handlers
    if table.array_contains(self.loaders, event_hander.add_lib) then
        local counts = { ev = 0, nth = 0, cc = 0, ri = 0, cs = 0, oi = 0, ol = 0 }
        for _, module in pairs(self.modules) do
            if module.events then counts.ev = counts.ev + table.size(module.events) end
            if module.on_nth_tick then counts.nth = counts.nth + table.size(module.on_nth_tick) end
            if module.on_configuration_changed then counts.cc = counts.cc + 1 end
            if module.add_remote_interface then counts.ri = counts.ri + 1 end
            if module.add_commands then counts.cs = counts.cs + 1 end
            if module.on_init then counts.oi = counts.oi + 1 end
            if module.on_load then counts.ol = counts.ol + 1 end
        end

        output(counts.ri .. " remote interfaces")
        output(counts.cs .. " command interfaces")
        output(counts.ev .. " event handlers")
        output(counts.oi .. " init handlers")
        output(counts.ol .. " load handlers")
        output(counts.nth .. " nth tick handlers")
        output(counts.cc .. " config changed handlers")
    end

    -- Call any custom loader logs
    for _, module in ipairs(self.modules) do
        if module.loader_counts then
            for _, loader_count in pairs(module.loader_counts) do
                loader_count(output)
            end
        end
    end
end

return ModuleLoader

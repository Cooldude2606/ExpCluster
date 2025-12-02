--[[-- ExtUtil - Module Loader
Provides a standard and extendable module loader used to limit side events from require
]]

local ExpUtil = require("modules/exp_util")
local event_hander = require("event_handler")

--- @class ExpUtil_Module
--- @field modules table<any, ExpUtil_Module>?
--- @field loaders table<any, fun(module: table)>?
--- @field events table<defines.events, fun(event: EventData)>?
--- @field on_nth_tick table<number, fun()>?
--- @field on_configuration_changed fun()?
--- @field add_remote_interface fun()?
--- @field add_commands fun()?
--- @field on_init fun()?
--- @field on_load fun()?

--- @class ExpUtil_ModuleLoader
local ModuleLoader = {}

--- @class ModuleLoader
--- @field modules table[]
--- @field loaders fun(module: table)[]
--- @operator call(string): nil
ModuleLoader._prototype = {}

ModuleLoader._metatable = {
    __call = ModuleLoader._prototype.require,
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
--- @param loader fun(module: ExpUtil_Module)
function ModuleLoader._prototype:add_loader(loader)
    if table.array_contains(self.loaders, loader) then
        error("Trying to register same loader twice: " .. ExpUtil.get_function_name(loader))
    end

    self.loaders[#self.loaders + 1] = loader
    for _, module in ipairs(self.modules) do
        loader(module)
    end
end

--- Add a collection of loaders
--- @param loaders table<any, fun(module: ExpUtil_Module)>
function ModuleLoader._prototype:add_loaders(loaders)
    for _, loader in pairs(loaders) do
        self:add_loader(loader)
    end
end

--- Add a module
--- @param module ExpUtil_Module
--- @param no_error boolean?
function ModuleLoader._prototype:add_module(module, no_error)
    if table.array_contains(self.modules, module) then
        if no_error then return end
        error("Trying to register same lib twice")
    end

    self.modules[#self.modules + 1] = module
    for _, loader in ipairs(self.loaders) do
        loader(module)
    end

    if module.modules then
        self:add_modules(module.modules, true)
    end

    if module.loaders then
        self:add_loaders(module.loaders)
    end
end

--- Add a collection of modules
--- @param modules table<any, ExpUtil_Module>
--- @param no_error boolean?
function ModuleLoader._prototype:add_modules(modules, no_error)
    for _, module in pairs(modules) do
        self:add_module(module, no_error)
    end
end

--- Require a module
--- @param module_path string
function ModuleLoader._prototype:require(module_path)
    local module = require(module_path)
    if type(module) == "table" then
        self:add_module(module)
    end
end

ModuleLoader._metatable.__call = ModuleLoader._prototype.require
return ModuleLoader

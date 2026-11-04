local _dir = debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])") or "./"
package.path = _dir .. "?.lua;" .. _dir .. "common/?.lua;" .. package.path

local function lrequire(name)
    local key = _dir .. name
    if not package.loaded[key] then
        package.loaded[key] = assert(loadfile(_dir .. name .. ".lua"))()
    end
    return package.loaded[key]
end

-- The game screen -- and the boards, word lists and puzzle banks it pulls
-- in -- loads the first time the game is opened, not when KOReader starts:
-- KOReader loads every plugin at startup and keeps it all session, so a
-- top-level require here costs memory even if the game is never played.
-- KOReader has put package.path back by then, so our directories are added
-- again while the module loads (common/ stays as a fallback for the shared
-- modules the game requires later on).
local function lazyrequire(name)
    local saved = package.path
    package.path = _dir .. "?.lua;" .. _dir .. "common/?.lua;" .. saved
    local ok, mod = pcall(lrequire, name)
    package.path = saved
    if not package.path:find(_dir .. "common/?.lua", 1, true) then
        package.path = package.path .. ";" .. _dir .. "common/?.lua"
    end
    if not ok then error(mod, 0) end
    return mod
end

local DataStorage = require("datastorage")
local LuaSettings = require("luasettings")
local UIManager   = require("ui/uimanager")
local PluginBase  = require("plugin_base")
local _           = require("i18n")

require("i18n").extend(lrequire("i18n_fr"))

local Quiz = PluginBase:extend{
    name       = "quiz",
    menu_text  = _("Quiz"),
    menu_hint  = "tools",
    -- "Quiz · multiplayer": named players or teams and a kept match, under
    -- two rules -- Classic, and Double or nothing (formerly the separate
    -- Double or Nothing plugin).
    party_mode = true,
}

function Quiz:init()
    PluginBase.init(self)
    local ok, err = pcall(self.migrateDoubleOrNothing, self)
    if not ok then
        require("logger").warn("quiz: Double or Nothing import failed:", err)
    end
end

-- The multiplayer rule last chosen: "classic" or "double".
function Quiz:getRule()
    return self:getSetting("party_rule") == "double" and "double" or "classic"
end

-- fresh: start a new match instead of restoring the saved one.
function Quiz:createScreen(fresh)
    if self.launch_mode == "party" then
        if self:getRule() == "double" then
            return lazyrequire("double_screen"):new{ plugin = self, fresh = fresh }
        end
        return lazyrequire("party_screen"):new{ plugin = self, fresh = fresh }
    end
    return lazyrequire("screen"):new{ plugin = self }
end

-- The multiplayer menu's "Rule: Classic / Double or nothing": the current
-- match is saved (each rule keeps its own), the other rule's screen replaces
-- it with its own saved match.
function Quiz:switchRule(rule)
    if rule == self:getRule() then return end
    local old = self.screen
    if old then
        if old._stopCountdown then old:_stopCountdown() end
        if old.saveGame then old:saveGame() end
        UIManager:close(old)
    end
    self:saveSetting("party_rule", rule)
    self.launch_mode = "party"
    self.screen = self:createScreen()
    UIManager:show(self.screen)
end

-- doubleornothing.koplugin's settings (settings/doubleornothing.lua), or nil
-- when the file does not exist. Only read, never modified or deleted.
local function read_settings(id)
    local ok, lfs = pcall(require, "libs/libkoreader-lfs")
    if not ok then ok, lfs = pcall(require, "lfs") end
    local path = DataStorage:getSettingsDir() .. "/" .. id .. ".lua"
    if not ok or lfs.attributes(path, "mode") ~= "file" then return nil end
    local ok2, s = pcall(LuaSettings.open, LuaSettings, path)
    return ok2 and s and s.data or nil
end

-- One-time import from Double or Nothing, now the "Double or nothing" rule
-- of Quiz · multiplayer (see quiz_migrate.lua): its language, teams, timer,
-- category and question history into this plugin's settings -- never over a
-- value the Quiz already has -- and its row of game_stats.lua folded into
-- the Quiz's (then removed, so Dashboard does not count those sessions
-- twice). Its settings file is only read.
function Quiz:migrateDoubleOrNothing()
    if self:getSetting("don_migrated", false) then return end
    local Migrate = lazyrequire("quiz_migrate")
    local writes = Migrate.settings(read_settings(Migrate.SOURCE_ID), function(key)
        return self.settings:readSetting(key)
    end)
    for key, value in pairs(writes) do
        self.settings:saveSetting(key, value)
    end

    local ok, StatsExporter = pcall(require, "stats_exporter")
    if ok then
        local id = self:getPluginId()
        local row = Migrate.stats(StatsExporter:get(id), StatsExporter:get(Migrate.SOURCE_ID))
        if row then
            StatsExporter:record(id, row)
            StatsExporter:remove(Migrate.SOURCE_ID)
        end
    end

    self.settings:saveSetting("don_migrated", true)
    self.settings:flush()
end

return Quiz

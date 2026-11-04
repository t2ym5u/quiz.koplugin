-- party_screen.lua — Quiz · multiplayer, Classic rule: the Quiz's own game
-- (question, optional countdown, reveal, +1 for every player who got it),
-- with named players (game-common party.lua), a scoreboard, and a match kept
-- across closing the screen. The other rule, Double or nothing, is
-- double_screen.lua; the menu's "Rule" switches between them (main.lua).
local _dir = debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])") or "./"

local UIManager = require("ui/uimanager")
local MenuHelper = require("menu_helper")
local Party     = require("party")
local _         = require("i18n")
local T         = require("ffi/util").template

local function lrequire(name)
    local key = _dir .. name
    if not package.loaded[key] then
        package.loaded[key] = assert(loadfile(_dir .. name .. ".lua"))()
    end
    return package.loaded[key]
end

local QuizScreen = lrequire("screen")
local Rules      = assert(loadfile(_dir .. "quiz_rules.lua"))()

local PartyScreen = QuizScreen:extend{ key_prefix = "party_" }

-- Seats of the Classic rule: players, 2 to 8 like the Quiz entry.
PartyScreen.SEATS = { min = 2, max = 8 }
PartyScreen.STATE_KEY = "party_state"

-- Rule menu shared with double_screen.lua: "Rule: Classic" or
-- "Rule: Double or nothing" in the title-bar menu, a picker behind it.
function PartyScreen.ruleMenuText(rule)
    return rule == "double" and _("Rule: Double or nothing") or _("Rule: Classic")
end

function PartyScreen.openRuleMenu(screen, current)
    MenuHelper.openPickerMenu{
        title      = _("Rule"),
        items      = { { id = "classic", text = _("Classic: +1 per right answer") },
                       { id = "double",  text = _("Double or nothing: bank or risk the pot") } },
        current_id = current,
        parent     = screen,
        on_select  = function(rule) screen.plugin:switchRule(rule) end,
    }
end

function PartyScreen:_initPlayers()
    local saved = not self.fresh and self.plugin:loadState(self.STATE_KEY)
    local scores = type(saved) == "table" and Party.restoreScores(saved.scores) or nil
    if not scores then
        scores = Party.newScores(Party.loadPlayers(self.plugin,
            Party.loadCount(self.plugin, self.SEATS), self.SEATS))
    end
    self.players = {}
    for i, name in ipairs(scores.names) do
        self.players[i] = { name = name, score = scores.points[i] }
    end
end

function PartyScreen:scores()
    local names = {}
    for i, p in ipairs(self.players) do names[i] = p.name end
    local scores = Party.newScores(names)
    for i, p in ipairs(self.players) do scores.points[i] = p.score end
    return scores
end

function PartyScreen:saveGame()
    self.plugin:saveState({ scores = self:scores() }, self.STATE_KEY)
end

-- The Quiz entry keeps "state"; this mode only writes its own key.
function PartyScreen:closeScreen()
    self:_stopCountdown()
    self:saveGame()
    if self.plugin then self.plugin:onScreenClosed() end
    UIManager:close(self)
    UIManager:setDirty(nil, "full")
end

function PartyScreen:_title()
    return T(_("%1 · multiplayer"), _("Quiz"))
end

local function anyPoints(scores)
    for _i, p in ipairs(scores.points) do
        if p ~= 0 then return true end
    end
    return false
end

-- New game: the final scores of the match being left first (when anyone
-- scored), then everyone back to zero and a fresh question.
function PartyScreen:onNewGame()
    local scores = self:scores()
    if anyPoints(scores) then Party.showScoreboard(scores, { final = true }) end
    QuizScreen.onNewGame(self)
    self:saveGame()
end

function PartyScreen:onScorePlayer(idx)
    QuizScreen.onScorePlayer(self, idx)
    self:saveGame()
end

-- A new number of players starts a new match with the remembered names.
function PartyScreen:openPlayersMenu()
    Party.pickCount(self.plugin, function(n)
        local names = Party.loadPlayers(self.plugin, n, self.SEATS)
        self.players = {}
        for i, name in ipairs(names) do self.players[i] = { name = name, score = 0 } end
        self:onNewGame()
    end, self, self.SEATS)
end

-- Renames the seats of the match in progress too.
function PartyScreen:openNamesMenu()
    local names = {}
    for i, p in ipairs(self.players) do names[i] = p.name end
    Party.editPlayers(self.plugin, names, function()
        for i, p in ipairs(self.players) do p.name = names[i] end
        self:saveGame()
        self:buildLayout()
        UIManager:setDirty(self, function() return "ui", self.dimen end)
    end, self, self.SEATS)
end

function PartyScreen:_menuItems()
    return {
        { text = _("New game"), callback = function() self:onNewGame() end },
        { text = PartyScreen.ruleMenuText("classic"),
          callback = function() PartyScreen.openRuleMenu(self, "classic") end },
        { text = T(_("Players: %1"), #self.players), callback = function() self:openPlayersMenu() end },
        { text = _("Player names"), callback = function() self:openNamesMenu() end },
        { text = T(_("Language: %1"), self.lang:upper()), callback = function() self:openLangMenu() end },
        { text = T(_("Timer: %1"), self:_durationLabel(self.duration)),
          callback = function() self:openDurationMenu() end },
        { text = self:_categoriesMenuText(), callback = function() self:openCategoryMenu() end },
        { text = _("Scores"), callback = function() Party.showScoreboard(self:scores()) end },
        { text = _("Reload file"), callback = function() self:onReloadFile() end },
        self:makeModeRulesButtonConfig(Rules),
    }
end

return PartyScreen

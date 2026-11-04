-- double_screen.lua — Quiz · multiplayer, "Double or nothing" rule (formerly
-- the Double or Nothing plugin, whose game this is, rules and scoring
-- unchanged): teams take turns; a correct answer wins the pot (1, then
-- doubled), and the team either banks it or risks it on a harder question.
--
-- What changed on the way into the Quiz: the teams are game-common
-- party.lua seats (names set in the menu), the match in progress is kept
-- when the screen closes, the questions are the rated bank plus the Quiz's
-- (double_deck.lua), and the no-repeat history is the Quiz's.
local _dir = debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])") or "./"

local Blitbuffer      = require("ffi/blitbuffer")
local CenterContainer = require("ui/widget/container/centercontainer")
local DataStorage     = require("datastorage")
local Device          = require("device")
local Font            = require("ui/font")
local FrameContainer  = require("ui/widget/container/framecontainer")
local Geom            = require("ui/geometry")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan  = require("ui/widget/horizontalspan")
local InfoMessage     = require("ui/widget/infomessage")
local LineWidget      = require("ui/widget/linewidget")
local RenderText      = require("ui/rendertext")
local Size            = require("ui/size")
local TextBoxWidget   = require("ui/widget/textboxwidget")
local TextWidget      = require("ui/widget/textwidget")
local UIManager       = require("ui/uimanager")
local VerticalGroup   = require("ui/widget/verticalgroup")
local VerticalSpan    = require("ui/widget/verticalspan")
local _               = require("i18n")
local T               = require("ffi/util").template

local MenuHelper = require("menu_helper")
local Party      = require("party")
local QuizBank   = require("quiz_bank")
local ScreenBase = require("screen_base")

local function lrequire(name)
    local key = _dir .. name
    if not package.loaded[key] then
        package.loaded[key] = assert(loadfile(_dir .. name .. ".lua"))()
    end
    return package.loaded[key]
end

local Deck        = lrequire("double_deck")
local Round       = lrequire("double_round")
local PartyScreen = lrequire("party_screen")
local Rules       = assert(loadfile(_dir .. "quiz_rules.lua"))()

local DeviceScreen = Device.screen

-- ---------------------------------------------------------------------------
-- Text sizing helpers
--
-- Font:getFace() scales its size by the screen DPI, so a size worked out from
-- pixel dimensions has to be divided back first, or every line comes out
-- about twice too big on a 300 dpi reader and runs off the screen edges.
-- ---------------------------------------------------------------------------

local DPI_SCALE = DeviceScreen:scaleBySize(1000) / 1000

local function pxFace(px)
    return Font:getFace("cfont", math.max(8, math.floor(px / DPI_SCALE)))
end

-- One line of text at up to `px` pixels, shrunk until it fits `max_w`.
local function fitLine(text, px, max_w)
    local face = pxFace(px)
    while px > 12 do
        local m = RenderText:sizeUtf8Text(0, max_w * 10, face, text, true, false)
        if m.x <= max_w then break end
        px   = math.floor(px * 0.9)
        face = pxFace(px)
    end
    return TextWidget:new{ text = text, face = face, max_width = max_w }
end

-- A paragraph wrapped to `width`, centred.
local function wrapText(text, face, width)
    return TextBoxWidget:new{ text = text, face = face, width = width, alignment = "center" }
end

local DEFAULT_DURATION = 0    -- seconds to think before reveal (0 = no timer)
local DURATIONS        = { 0, 15, 20, 30, 45 }

-- Seats: teams, 2 to 6 as in Double or Nothing.
local SEATS = { teams = true, min = 2, max = 6 }
local STATE_KEY = "party_double_state"

local function jsonDecode(s)
    local ok, json = pcall(require, "json")
    if ok then
        local ok2, result = pcall(json.decode, s)
        if ok2 then return result end
    end
    return nil
end

local PHASES = { idle = true, question = true, reveal = true, choice = true }

-- ---------------------------------------------------------------------------
-- DoubleScreen
-- ---------------------------------------------------------------------------

local DoubleScreen = ScreenBase:extend{}

DoubleScreen.SEATS     = SEATS
DoubleScreen.STATE_KEY = STATE_KEY

function DoubleScreen:init()
    local p = self.plugin
    local lang = p:getSetting("party_lang") or p:getSetting("lang")
        or (_.lang() == "fr" and "fr" or "en")
    self.lang     = lang == "fr" and "fr" or "en"
    self.duration = tonumber(p:getSetting("party_double_duration", DEFAULT_DURATION)) or DEFAULT_DURATION

    self.questions       = {}   -- normalized list of the loaded pool
    self.categories      = {}
    self.used            = {}   -- questions played this session (Deck no-repeat)
    self.question        = nil  -- the question on screen
    self.level           = 1    -- its difficulty level (1..5)
    self.phase           = "idle"  -- "idle" | "question" | "reveal" | "choice"
    self.pot             = 0
    self.current_team    = 1

    local saved = not self.fresh and p:loadState(STATE_KEY)
    if not (type(saved) == "table" and self:_restore(saved)) then
        self.scores = Party.newScores(Party.loadPlayers(p, Party.loadCount(p, SEATS), SEATS))
    end
    self.time_remaining = self.duration

    self:_loadQuestions()
    ScreenBase.init(self)
    if self.phase == "question" then self:_startCountdown() end
end

-- ---------------------------------------------------------------------------
-- Match in progress (kept in the settings, restored on the next opening)
-- ---------------------------------------------------------------------------

function DoubleScreen:serializeState()
    local q = self.question
    return {
        scores  = Party.copyScores(self.scores),
        current = self.current_team,
        pot     = self.pot,
        level   = self.level,
        phase   = self.phase,
        question = q and {
            question = q.question, answer = q.answer, category = q.category,
            level = q.level, rated = q.rated, alt = q.alt,
        } or nil,
    }
end

-- true when `t` held a usable match (then applied to self).
function DoubleScreen:_restore(t)
    local scores = Party.restoreScores(t.scores)
    if not scores then return false end
    self.scores = scores
    local n = #scores.names
    local cur = tonumber(t.current) or 1
    self.current_team = (cur >= 1 and cur <= n and cur % 1 == 0) and cur or 1
    local q = t.question
    if PHASES[t.phase] and t.phase ~= "idle" and type(q) == "table"
        and type(q.question) == "string" and type(q.answer) == "string" then
        self.phase    = t.phase
        self.question = q
        self.pot      = math.max(0, tonumber(t.pot) or 0)
        self.level    = Deck.parseLevel(t.level)
        self.used[Deck.key(q)] = true
    end
    return true
end

function DoubleScreen:saveGame()
    self.plugin:saveState(self:serializeState(), STATE_KEY)
end

-- The Quiz entry keeps "state"; this rule only writes its own key.
function DoubleScreen:closeScreen()
    self:_stopCountdown()
    self:saveGame()
    if self.plugin then self.plugin:onScreenClosed() end
    UIManager:close(self)
    UIManager:setDirty(nil, "full")
end

-- ---------------------------------------------------------------------------
-- Question loading (see double_deck.lua for where questions come from)
-- ---------------------------------------------------------------------------

function DoubleScreen:_loadQuestions()
    -- Drop the previous pool first so it can be collected before the next
    -- one is read (language switch on a 256 MB reader).
    self.questions, self.deck = {}, nil
    self.seen       = QuizBank.openHistory(self.plugin, self.lang)
    self.questions  = Deck.loadPool(DataStorage:getDataDir(), _dir, self.lang, jsonDecode, QuizBank)
    self.categories = Deck.categories(self.questions)
    self.category   = self.plugin:getSetting("party_double_category_" .. self.lang, "all")
    local known = false
    for _i, c in ipairs(self.categories) do
        if c == self.category then known = true end
    end
    if not known then self.category = "all" end
    self:_buildDeck()
end

function DoubleScreen:_buildDeck()
    self.deck = Deck.new(self.questions, {
        category = self.category ~= "all" and self.category or nil,
        used     = self.used,
        seen     = self.seen,
    })
end

function DoubleScreen:_deckSize()
    return self.deck and self.deck:size() or 0
end

-- Draw the question for the current level; nil when the deck is empty.
function DoubleScreen:_drawQuestion()
    self.question = self.deck and self.deck:draw(self.level) or nil
end

function DoubleScreen:_noQuestionsText()
    return T(_("No questions loaded.\n\nCopy %1\nto KOReader's documents folder."),
        "quiz_double_" .. self.lang .. ".json")
end

-- ---------------------------------------------------------------------------
-- Timer (optional reflection countdown during "question" phase)
-- ---------------------------------------------------------------------------

function DoubleScreen:_startCountdown()
    if self.duration <= 0 then return end
    self._tick_gen = (self._tick_gen or 0) + 1
    local gen = self._tick_gen
    UIManager:scheduleIn(1, function() self:_onTick(gen) end)
end

function DoubleScreen:_stopCountdown()
    self._tick_gen = (self._tick_gen or 0) + 1
end

function DoubleScreen:_onTick(gen)
    if gen ~= self._tick_gen then return end
    self.time_remaining = math.max(0, self.time_remaining - 1)
    if self.timer_widget then
        self.timer_widget:setText(self:_timerText())
        UIManager:setDirty(self, function() return "fast", self.dimen end)
    end
    if self.time_remaining <= 0 then
        self:onReveal()
    else
        UIManager:scheduleIn(1, function() self:_onTick(gen) end)
    end
end

function DoubleScreen:_timerText()
    if self.duration <= 0 then return "" end
    local m = math.floor(self.time_remaining / 60)
    local s = self.time_remaining % 60
    return string.format("%d:%02d", m, s)
end

-- ---------------------------------------------------------------------------
-- Game actions
-- ---------------------------------------------------------------------------

function DoubleScreen:_redraw()
    self:buildLayout()
    UIManager:setDirty(self, function() return "ui", self.dimen end)
end

function DoubleScreen:_teamName(i)
    return self.scores.names[i or self.current_team] or ""
end

function DoubleScreen:onStartTurn()
    if self:_deckSize() == 0 then
        UIManager:show(InfoMessage:new{ text = self:_noQuestionsText(), timeout = 6 })
        return
    end
    self.pot             = 0
    self.level           = Round.startLevel()
    self:_drawQuestion()
    self.time_remaining  = self.duration
    self.phase           = "question"
    self:saveGame()
    self:_redraw()
    self:_startCountdown()
end

function DoubleScreen:onReveal()
    self:_stopCountdown()
    self.phase = "reveal"
    self:saveGame()
    self:_redraw()
end

function DoubleScreen:onCorrect()
    self.pot = Round.nextPot(self.pot)
    self.phase = "choice"
    self:saveGame()
    self:_redraw()
end

function DoubleScreen:onWrong()
    UIManager:show(InfoMessage:new{
        text = T(_("%1 loses it all (%2 pt in play). Next team!"), self:_teamName(), self.pot),
        timeout = 3,
    })
    self:_endTurn()
end

function DoubleScreen:onBank()
    Party.award(self.scores, self.current_team, self.pot)
    self:_endTurn()
end

function DoubleScreen:onDoubleAgain()
    self.level           = Round.nextLevel(self.level)
    self:_drawQuestion()
    self.time_remaining  = self.duration
    self.phase           = "question"
    self:saveGame()
    self:_redraw()
    self:_startCountdown()
end

function DoubleScreen:_endTurn()
    self.pot           = 0
    self.question      = nil
    self.current_team  = Round.nextTeam(self.current_team, #self.scores.names)
    self.phase         = "idle"
    self:saveGame()
    self:_redraw()
end

local function anyPoints(scores)
    for _i, p in ipairs(scores.points) do
        if p ~= 0 then return true end
    end
    return false
end

-- New game: the final scores of the match being left first (when anyone
-- scored), then scores back to zero, first team to play, nothing in the pot.
-- names: the seats of the new match (default: the current ones).
function DoubleScreen:onNewGame(names)
    self:_stopCountdown()
    if anyPoints(self.scores) then Party.showScoreboard(self.scores, { final = true }) end
    self.scores       = Party.newScores(names or self.scores.names)
    self.current_team = 1
    self.pot          = 0
    self.question     = nil
    self.phase        = "idle"
    self:saveGame()
    self:_redraw()
end

-- ---------------------------------------------------------------------------
-- Options
-- ---------------------------------------------------------------------------

function DoubleScreen:_durationLabel(dur)
    if dur <= 0 then return _("Off") end
    return string.format("%d:%02d", math.floor(dur / 60), dur % 60)
end

function DoubleScreen:onReloadFile()
    self:_loadQuestions()
    self:_redraw()
end

function DoubleScreen:openLangMenu()
    MenuHelper.openPickerMenu{
        title = _("Language"),
        items = { { id = "fr", text = "Français" }, { id = "en", text = "English" } },
        current_id = self.lang, parent = self,
        on_select = function(lang)
            self.lang = lang
            self.plugin:saveSetting("party_lang", lang)
            self:_loadQuestions()
            self:_redraw()
        end,
    }
end

function DoubleScreen:_categoryLabel()
    if self.category == "all" then return _("Category: All") end
    return T(_("Category: %1"), self.category)
end

function DoubleScreen:openCategoryMenu()
    local items = { { id = "all", text = _("All") } }
    for _i, c in ipairs(self.categories) do
        items[#items + 1] = { id = c, text = c }
    end
    MenuHelper.openPickerMenu{
        title = _("Category"),
        items = items, current_id = self.category, parent = self,
        on_select = function(cat)
            self.category = cat
            self.plugin:saveSetting("party_double_category_" .. self.lang, cat)
            self:_buildDeck()
            self:_redraw()
        end,
    }
end

-- A new number of teams starts a new match with the remembered names.
function DoubleScreen:openTeamsMenu()
    Party.pickCount(self.plugin, function(n)
        self:onNewGame(Party.loadPlayers(self.plugin, n, SEATS))
    end, self, SEATS)
end

-- Renames the teams of the match in progress too.
function DoubleScreen:openNamesMenu()
    Party.editPlayers(self.plugin, self.scores.names, function()
        self:saveGame()
        self:_redraw()
    end, self, SEATS)
end

function DoubleScreen:openDurationMenu()
    local items = {}
    for _i, d in ipairs(DURATIONS) do
        items[#items + 1] = { id = d, text = self:_durationLabel(d) }
    end
    MenuHelper.openPickerMenu{
        title = _("Timer"),
        items = items, current_id = self.duration, parent = self,
        on_select = function(dur)
            self.duration = dur
            self.plugin:saveSetting("party_double_duration", dur)
        end,
    }
end

-- ---------------------------------------------------------------------------
-- Layout
-- ---------------------------------------------------------------------------

function DoubleScreen:buildLayout()
    if self.phase == "idle" then
        self:_buildIdleLayout()
    else
        self:_buildPlayLayout()
    end
    self[1] = self.layout
    self:updateStatus()
end

function DoubleScreen:_titleBar()
    return self:buildTitleBar(T(_("%1 · multiplayer"), _("Quiz")), function()
        return {
            { text = _("New game"), callback = function() self:onNewGame() end },
            { text = PartyScreen.ruleMenuText("double"),
              callback = function() PartyScreen.openRuleMenu(self, "double") end },
            { text = T(_("Teams: %1"), #self.scores.names), callback = function() self:openTeamsMenu() end },
            { text = _("Team names"), callback = function() self:openNamesMenu() end },
            { text = T(_("Language: %1"), self.lang:upper()), callback = function() self:openLangMenu() end },
            { text = self:_categoryLabel(), callback = function() self:openCategoryMenu() end },
            { text = T(_("Timer: %1"), self:_durationLabel(self.duration)),
              callback = function() self:openDurationMenu() end },
            { text = _("Scores"), callback = function() Party.showScoreboard(self.scores) end },
            { text = _("Reload file"), callback = function() self:onReloadFile() end },
            self:makeModeRulesButtonConfig(Rules),
        }
    end)
end

function DoubleScreen:_buildIdleLayout()
    local title_bar = self:_titleBar()
    local controls  = self:_buildControls({
        { text = _("Start turn"),
          callback = function() self:onStartTurn() end },
    })
    local bw, bh = self:getBoardBudget(title_bar, controls)
    local short  = math.min(bw, bh)
    local vs     = Size.span.vertical_large

    local deck_line
    if self:_deckSize() == 0 then
        deck_line = "⚠ " .. self:_noQuestionsText()
    else
        deck_line = T(_("%1 questions loaded"), self:_deckSize())
    end

    self.timer_widget = nil
    local content = VerticalGroup:new{
        align = "center",
        wrapText(_("Double or nothing"), Font:getFace("smallinfofont"), bw),
        VerticalSpan:new{ width = vs },
        fitLine(self:_teamName():upper(), short * 0.14, bw),
        VerticalSpan:new{ width = vs },
        wrapText(_("It's your turn!"), Font:getFace("infofont"), bw),
        VerticalSpan:new{ width = vs * 3 },
    }
    -- The standings, best first, once anyone has scored.
    if anyPoints(self.scores) then
        content[#content + 1] = wrapText(table.concat(Party.scoreLines(self.scores), "\n"),
            Font:getFace("infofont"), bw)
        content[#content + 1] = VerticalSpan:new{ width = vs * 3 }
    end
    content[#content + 1] = wrapText(deck_line, Font:getFace("smallinfofont"), bw)
    self:_placeLayout(title_bar, content, controls)
end

function DoubleScreen:_buildPlayLayout()
    local q = self.question

    local rows
    if self.phase == "question" then
        rows = {
            { text = _("Reveal answer"),
              callback = function() self:onReveal() end },
        }
    elseif self.phase == "reveal" then
        rows = {
            { text = "✓  " .. _("Correct"),
              callback = function() self:onCorrect() end },
            { text = "✗  " .. _("Wrong"),
              callback = function() self:onWrong() end },
        }
    else -- "choice"
        -- No emoji here: the UI fonts have no glyph for the 🏦 that used to
        -- prefix "Bank", so it rendered as a missing-glyph box.
        local next_pot = self.pot * 2
        rows = {
            { text = T(_("Bank +%1"), self.pot),
              callback = function() self:onBank() end },
            { text = T(_("Double → %1"), next_pot),
              callback = function() self:onDoubleAgain() end },
        }
    end

    local title_bar = self:_titleBar()
    local controls  = self:_buildControls(rows)
    local bw, bh = self:getBoardBudget(title_bar, controls)
    local short  = math.min(bw, bh)
    local vs     = Size.span.vertical_large

    local pot_text = T(_("Pot in play: %1 pt"), self.pot)

    -- The card fills the width; its text wraps inside the frame.
    local frame_pad = Size.padding.large
    local inner_w   = bw - 2 * (frame_pad + Size.border.window)
    local card_group
    if not q then
        card_group = wrapText(_("No questions."), Font:getFace("infofont"), inner_w)
    else
        local question_text = q.question or "?"
        local answer_text   = q.answer or "?"
        local badge = {}
        if q.category then badge[#badge + 1] = q.category end
        if q.rated then badge[#badge + 1] = T(_("Level %1"), q.level) end

        local body = VerticalGroup:new{ align = "center" }
        if #badge > 0 then
            body[#body + 1] = wrapText("[ " .. table.concat(badge, " · ") .. " ]", Font:getFace("smallinfofont"), inner_w)
            body[#body + 1] = VerticalSpan:new{ width = vs }
        end

        local qlen = #question_text
        local q_px = short * (qlen > 80 and 0.045 or qlen > 40 and 0.055 or 0.065)
        body[#body + 1] = wrapText(question_text, pxFace(q_px), inner_w)

        if self.phase == "reveal" or self.phase == "choice" then
            body[#body + 1] = VerticalSpan:new{ width = vs * 2 }
            body[#body + 1] = LineWidget:new{
                background = Blitbuffer.COLOR_DARK_GRAY,
                dimen      = Geom:new{ w = math.floor(inner_w * 0.6), h = Size.line.medium },
            }
            body[#body + 1] = VerticalSpan:new{ width = vs }
            body[#body + 1] = TextWidget:new{
                text = _("Answer:"),
                face = Font:getFace("smallinfofont"),
            }
            body[#body + 1] = VerticalSpan:new{ width = vs }
            body[#body + 1] = wrapText(answer_text, pxFace(short * 0.08), inner_w)
            if q.alt then
                body[#body + 1] = VerticalSpan:new{ width = vs }
                body[#body + 1] = wrapText(T(_("Also accepted: %1"), q.alt), Font:getFace("smallinfofont"), inner_w)
            end
        end

        card_group = body
    end

    local card_frame = FrameContainer:new{
        padding = frame_pad,
        margin  = 0,
        width   = bw,
        CenterContainer:new{
            dimen = Geom:new{ w = inner_w, h = card_group:getSize().h },
            card_group,
        },
    }

    local content = VerticalGroup:new{ align = "center" }
    self.timer_widget = nil
    if self.phase == "question" and self.duration > 0 then
        self.timer_widget = TextWidget:new{
            text = self:_timerText(),
            face = pxFace(short * 0.1),
        }
        content[#content + 1] = self.timer_widget
        content[#content + 1] = VerticalSpan:new{ width = vs }
    end
    content[#content + 1] = fitLine(self:_teamName():upper(), short * 0.07, bw)
    content[#content + 1] = VerticalSpan:new{ width = vs }
    content[#content + 1] = TextWidget:new{ text = pot_text, face = Font:getFace("smallinfofont"), max_width = bw }
    content[#content + 1] = VerticalSpan:new{ width = vs * 2 }
    content[#content + 1] = card_frame
    self:_placeLayout(title_bar, content, controls)
end

-- Status line + action bar, built before the content so the content can be
-- sized from what they leave over (getBoardBudget).
function DoubleScreen:_buildControls(rows)
    self.status_text:setMaxWidth(self:getControlsWidth())
    return VerticalGroup:new{
        align = "center",
        self.status_text,
        VerticalSpan:new{ width = Size.span.vertical_large },
        self:buildActionBar(rows),
    }
end

function DoubleScreen:_placeLayout(title_bar, content, controls)
    if self:isLandscape() then
        self:buildLandscapeLayout(title_bar, HorizontalGroup:new{
            align = "center",
            content,
            HorizontalSpan:new{ width = self:getGutter() },
            controls,
        })
    else
        self:buildPortraitLayout(title_bar, content,
            VerticalGroup:new{ align = "center", controls, VerticalSpan:new{ width = self:getGutter() } })
    end
end

-- "Team 1: 3 · Team 2: 1"
function DoubleScreen:_scoreStatus()
    local parts = {}
    for i, name in ipairs(self.scores.names) do
        parts[#parts + 1] = T(_("%1: %2"), name, self.scores.points[i])
    end
    return self:joinStatus((table.unpack or unpack)(parts))
end

-- ---------------------------------------------------------------------------
-- Status bar
-- ---------------------------------------------------------------------------

function DoubleScreen:updateStatus(msg)
    if msg then ScreenBase.updateStatus(self, msg); return end
    ScreenBase.updateStatus(self, self:_scoreStatus())
end

function DoubleScreen:onClose()
    self:closeScreen()
end

return DoubleScreen

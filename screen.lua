local _dir = debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])") or "./"

local ButtonTable    = require("ui/widget/buttontable")
local DataStorage    = require("datastorage")
local Device         = require("device")
local Font           = require("ui/font")
local FrameContainer = require("ui/widget/container/framecontainer")
local InfoMessage    = require("ui/widget/infomessage")
local Size           = require("ui/size")
local TextBoxWidget  = require("ui/widget/textboxwidget")
local TextWidget     = require("ui/widget/textwidget")
local UIManager      = require("ui/uimanager")
local VerticalGroup  = require("ui/widget/verticalgroup")
local VerticalSpan   = require("ui/widget/verticalspan")
local _              = require("i18n")

local MenuHelper = require("menu_helper")
local ScreenBase = require("screen_base")

local DeviceScreen = Device.screen

local DEFAULT_DURATION = 30   -- seconds to answer (0 = no timer)
local DEFAULT_NB_PLAYERS = 4

local GAME_RULES_EN = _([[
Quiz Party — Rules

Everyone writes their answer on paper while the question is displayed. When time runs out (or the host taps "Reveal"), the answer appears.

• Each player with the correct answer scores +1.
• The host reads answers aloud and decides who scores.
• Questions are shuffled from your JSON file.

JSON format (quiz_questions.json in documents):
[
  {
    "question": "Capital of Australia?",
    "answer": "Canberra",
    "category": "Geography"
  }
]
]])

local GAME_RULES_FR = [[
Quiz Party — Règles

Tout le monde écrit sa réponse sur papier pendant que la question est affichée. Quand le chrono sonne (ou que l'hôte appuie sur « Révéler »), la réponse apparaît.

• Chaque joueur avec la bonne réponse marque +1.
• L'hôte lit les réponses à voix haute et décide qui marque.
• Les questions sont mélangées depuis votre fichier JSON.

Format JSON (quiz_questions.json dans documents) :
[
  {
    "question": "Capitale de l'Australie ?",
    "answer": "Canberra",
    "category": "Géographie"
  }
]
]]

local function jsonDecode(s)
    local ok, json = pcall(require, "json")
    if ok then
        local ok2, result = pcall(json.decode, s)
        if ok2 then return result end
    end
    return nil
end

-- ---------------------------------------------------------------------------
-- QuizScreen
-- ---------------------------------------------------------------------------

local QuizScreen = ScreenBase:extend{}

function QuizScreen:init()
    self.lang       = self.plugin:getSetting("lang", "fr")
    self.duration   = self.plugin:getSetting("duration", DEFAULT_DURATION)
    local nb        = self.plugin:getSetting("nb_players", DEFAULT_NB_PLAYERS)

    self.players = {}
    for i = 1, nb do
        local default = self.lang == "fr" and ("Joueur " .. i) or ("Player " .. i)
        self.players[i] = {
            name  = self.plugin:getSetting("player_name_" .. i, default),
            score = 0,
        }
    end

    self.questions    = {}
    self.q_index      = 1
    self.phase        = "question"  -- "question" | "answer"
    self.time_remaining = self.duration
    self.category_filter = self.plugin:getSetting("category_filter", "all")

    self:_loadQuestions()
    ScreenBase.init(self)
    if self.duration > 0 then
        self:_startCountdown()
    end
end

-- ---------------------------------------------------------------------------
-- Question loading
-- ---------------------------------------------------------------------------

function QuizScreen:_loadQuestions()
    local docs = DataStorage:getDataDir()
    local paths = {
        docs .. "/quiz_questions_" .. self.lang .. ".json",
        docs .. "/quiz_questions.json",
    }
    for _, path in ipairs(paths) do
        local f = io.open(path, "r")
        if f then
            local content = f:read("*all")
            f:close()
            local data = jsonDecode(content)
            if type(data) == "table" and #data > 0 then
                self.questions = data
                self:_shuffleQuestions()
                return
            end
        end
    end
    self.questions = {}
end

function QuizScreen:_shuffleQuestions()
    local q = self.questions
    for i = #q, 2, -1 do
        local j = math.random(i)
        q[i], q[j] = q[j], q[i]
    end
    self.q_index = 1
end

function QuizScreen:_currentQuestion()
    if #self.questions == 0 then return nil end
    if self.q_index > #self.questions then self:_shuffleQuestions() end
    return self.questions[self.q_index]
end

-- ---------------------------------------------------------------------------
-- Timer
-- ---------------------------------------------------------------------------

function QuizScreen:_startCountdown()
    if self.duration <= 0 then return end
    self._tick_gen = (self._tick_gen or 0) + 1
    local gen = self._tick_gen
    UIManager:scheduleIn(1, function() self:_onTick(gen) end)
end

function QuizScreen:_stopCountdown()
    self._tick_gen = (self._tick_gen or 0) + 1
end

function QuizScreen:_onTick(gen)
    if gen ~= self._tick_gen then return end
    self.time_remaining = math.max(0, self.time_remaining - 1)
    if self.timer_widget then
        self.timer_widget:setText(self:_timerText())
        UIManager:setDirty(self, function() return "fast", self.dimen end)
    end
    if self.time_remaining <= 0 then
        self:onRevealAnswer()
    else
        UIManager:scheduleIn(1, function() self:_onTick(gen) end)
    end
end

function QuizScreen:_timerText()
    if self.duration <= 0 then return "" end
    local m = math.floor(self.time_remaining / 60)
    local s = self.time_remaining % 60
    return string.format("%d:%02d", m, s)
end

-- ---------------------------------------------------------------------------
-- Actions
-- ---------------------------------------------------------------------------

function QuizScreen:onRevealAnswer()
    self:_stopCountdown()
    self.phase = "answer"
    self:buildLayout()
    UIManager:setDirty(self, function() return "ui", self.dimen end)
end

function QuizScreen:onNextQuestion()
    self.q_index        = self.q_index + 1
    self.phase          = "question"
    self.time_remaining = self.duration
    self:buildLayout()
    UIManager:setDirty(self, function() return "ui", self.dimen end)
    if self.duration > 0 then self:_startCountdown() end
end

function QuizScreen:onScorePlayer(idx)
    self.players[idx].score = self.players[idx].score + 1
    self:updateStatus()
    UIManager:setDirty(self, function() return "ui", self.dimen end)
end

function QuizScreen:onResetScores()
    for _, p in ipairs(self.players) do p.score = 0 end
    self:buildLayout()
    UIManager:setDirty(self, function() return "ui", self.dimen end)
end

-- ---------------------------------------------------------------------------
-- Options
-- ---------------------------------------------------------------------------

function QuizScreen:openOptionsMenu()
    local is_fr = self.lang == "fr"
    local items = {
        { id = "lang",     text = is_fr and "Langue…"          or "Language…" },
        { id = "players",  text = is_fr and "Joueurs…"          or "Players…" },
        { id = "duration", text = is_fr and "Chrono…"           or "Timer…" },
        { id = "reset",    text = is_fr and "Remettre les scores à zéro" or "Reset scores" },
        { id = "reload",   text = is_fr and "Recharger le fichier" or "Reload file" },
    }
    MenuHelper.openPickerMenu{
        title = "Options", items = items, parent = self,
        on_select = function(id)
            if     id == "lang"     then self:openLangMenu()
            elseif id == "players"  then self:openPlayersMenu()
            elseif id == "duration" then self:openDurationMenu()
            elseif id == "reset"    then self:onResetScores()
            elseif id == "reload"   then self:_loadQuestions(); self:buildLayout(); UIManager:setDirty(self, function() return "ui", self.dimen end)
            end
        end,
    }
end

function QuizScreen:openLangMenu()
    MenuHelper.openPickerMenu{
        title = "Language / Langue",
        items = { { id = "fr", text = "Français" }, { id = "en", text = "English" } },
        current_id = self.lang, parent = self,
        on_select = function(lang)
            self.lang = lang
            self.plugin:saveSetting("lang", lang)
            self:_loadQuestions()
            self:buildLayout()
            UIManager:setDirty(self, function() return "ui", self.dimen end)
        end,
    }
end

function QuizScreen:openPlayersMenu()
    local is_fr = self.lang == "fr"
    local items = {}
    for n = 2, 8 do
        items[#items + 1] = { id = n, text = n .. " " .. (is_fr and "joueurs" or "players") }
    end
    MenuHelper.openPickerMenu{
        title = is_fr and "Joueurs" or "Players",
        items = items, current_id = #self.players, parent = self,
        on_select = function(n)
            self.plugin:saveSetting("nb_players", n)
            while #self.players < n do
                local i = #self.players + 1
                self.players[i] = { name = (self.lang == "fr" and "Joueur " or "Player ") .. i, score = 0 }
            end
            while #self.players > n do table.remove(self.players) end
            self:buildLayout()
            UIManager:setDirty(self, function() return "ui", self.dimen end)
        end,
    }
end

function QuizScreen:openDurationMenu()
    local is_fr = self.lang == "fr"
    local items = {
        { id = 0,  text = is_fr and "Pas de chrono" or "No timer" },
        { id = 20, text = "0:20" }, { id = 30, text = "0:30" },
        { id = 45, text = "0:45" }, { id = 60, text = "1:00" },
    }
    MenuHelper.openPickerMenu{
        title = is_fr and "Chrono" or "Timer",
        items = items, current_id = self.duration, parent = self,
        on_select = function(dur)
            self.duration = dur
            self.plugin:saveSetting("duration", dur)
        end,
    }
end

-- ---------------------------------------------------------------------------
-- Layout
-- ---------------------------------------------------------------------------

function QuizScreen:buildLayout()
    local sw    = DeviceScreen:getWidth()
    local sh = DeviceScreen:getHeight()
    local is_fr = self.lang == "fr"

    local btn_w = math.floor(sw * 0.92)

    -- Title bar with Options menu
    local title_bar = self:buildTitleBar(_("Quiz Party"), function()
        return {
            { text = is_fr and "Réglages" or "Settings", callback = function() self:openOptionsMenu() end },
            self:makeRulesButtonConfig(GAME_RULES_EN, GAME_RULES_FR),
        }
    end)

    -- Footer action button
    local action_btns
    if self.phase == "question" then
        local reveal_text = is_fr and "Révéler la réponse" or "Reveal answer"
        action_btns = ButtonTable:new{
            shrink_unneeded_width = true,
            width   = btn_w,
            buttons = {{
                { text = reveal_text, callback = function() self:onRevealAnswer() end },
            }},
        }
    else
        local next_text = is_fr and "Question suivante" or "Next question"
        action_btns = ButtonTable:new{
            shrink_unneeded_width = true,
            width   = btn_w,
            buttons = {{
                { text = next_text, callback = function() self:onNextQuestion() end },
            }},
        }
    end

    -- Question / answer display
    local q = self:_currentQuestion()
    local main_widget

    if not q then
        local msg = is_fr
            and "Aucune question chargée.\n\nCopiez quiz_questions_fr.json\n(ou quiz_questions.json)\ndans le dossier documents de KOReader."
            or  "No questions loaded.\n\nCopy quiz_questions_en.json\n(or quiz_questions.json)\nto KOReader's documents folder."
        main_widget = TextBoxWidget:new{
            text  = msg,
            face  = Font:getFace("smallinfofont"),
            width = math.floor(sw * 0.85),
        }
    else
        local question_text = q.question or q.q or "?"
        local answer_text   = q.answer   or q.a or "?"
        local category_text = q.category or q.cat or ""

        -- Category badge
        local cat_w = category_text ~= "" and TextWidget:new{
            text = "[ " .. category_text .. " ]",
            face = Font:getFace("smallinfofont"),
        }

        -- Question (adapts font to length)
        local qlen   = #question_text
        local q_fs   = qlen > 80 and 16 or qlen > 40 and 20 or 26
        q_fs = math.max(q_fs, math.floor(math.min(sw, sh) * 0.035))
        local q_w = TextBoxWidget:new{
            text  = question_text,
            face  = Font:getFace("cfont", q_fs),
            width = math.floor(sw * 0.88),
        }

        -- Counter
        local counter_text = string.format("%d / %d", self.q_index, #self.questions)
        local counter_w = TextWidget:new{
            text = counter_text,
            face = Font:getFace("smallinfofont"),
        }

        local body = VerticalGroup:new{ align = "center" }
        if cat_w then
            body[#body + 1] = cat_w
            body[#body + 1] = VerticalSpan:new{ width = Size.span.vertical_large }
        end
        body[#body + 1] = q_w
        body[#body + 1] = VerticalSpan:new{ width = Size.span.vertical_large }
        body[#body + 1] = counter_w

        if self.phase == "answer" then
            -- Answer reveal
            local sep = TextWidget:new{
                text = string.rep("─", 30),
                face = Font:getFace("smallinfofont"),
            }
            local ans_label = TextWidget:new{
                text = is_fr and "Réponse :" or "Answer:",
                face = Font:getFace("smallinfofont"),
            }
            local a_fs  = math.max(24, math.floor(math.min(sw, sh) * 0.07))
            local ans_w = TextBoxWidget:new{
                text  = answer_text,
                face  = Font:getFace("cfont", a_fs),
                width = math.floor(sw * 0.85),
            }
            body[#body + 1] = VerticalSpan:new{ width = Size.span.vertical_large * 2 }
            body[#body + 1] = sep
            body[#body + 1] = VerticalSpan:new{ width = Size.span.vertical_large }
            body[#body + 1] = ans_label
            body[#body + 1] = VerticalSpan:new{ width = Size.span.vertical_large }
            body[#body + 1] = ans_w

            -- Score buttons: one per player
            local score_rows = {}
            local row = {}
            for i, player in ipairs(self.players) do
                row[#row + 1] = {
                    text = "+" .. player.name .. " (" .. player.score .. ")",
                    callback = function() self:onScorePlayer(i) end,
                }
                if #row == 3 or i == #self.players then
                    score_rows[#score_rows + 1] = row
                    row = {}
                end
            end
            local score_btns = ButtonTable:new{
                shrink_unneeded_width = true,
                width   = btn_w,
                buttons = score_rows,
            }
            body[#body + 1] = VerticalSpan:new{ width = Size.span.vertical_large * 2 }
            body[#body + 1] = TextWidget:new{
                text = is_fr and "Qui a bon ?" or "Who got it?",
                face = Font:getFace("smallinfofont"),
            }
            body[#body + 1] = VerticalSpan:new{ width = Size.span.vertical_large }
            body[#body + 1] = score_btns
        end

        main_widget = FrameContainer:new{
            padding = Size.padding.large,
            margin  = Size.margin.default,
            body,
        }
    end

    -- Timer (only in question phase with timer enabled)
    local timer_group = VerticalGroup:new{ align = "center" }
    self.timer_widget = nil
    if self.phase == "question" and self.duration > 0 then
        local timer_fs = math.max(18, math.floor(math.min(sw, sh) * 0.08))
        self.timer_widget = TextWidget:new{
            text = self:_timerText(),
            face = Font:getFace("cfont", timer_fs),
        }
        timer_group[#timer_group + 1] = self.timer_widget
        timer_group[#timer_group + 1] = VerticalSpan:new{ width = Size.span.vertical_large }
    end

    local vs = VerticalSpan:new{ width = Size.span.vertical_large }

    local content = VerticalGroup:new{
        align = "center",
        timer_group,
        main_widget,
    }
    self:buildPortraitLayout(title_bar, content, action_btns)
    self:updateStatus()
end

function QuizScreen:updateStatus(msg)
    if msg then ScreenBase.updateStatus(self, msg); return end
    local parts = {}
    for _, p in ipairs(self.players) do
        parts[#parts + 1] = p.name .. " " .. p.score
    end
    local q_count = #self.questions > 0
        and string.format("  |  Q%d/%d", self.q_index, #self.questions)
        or  ""
    ScreenBase.updateStatus(self, table.concat(parts, "  ") .. q_count)
end

function QuizScreen:onClose()
    self:_stopCountdown()
    ScreenBase.onClose(self)
end

return QuizScreen

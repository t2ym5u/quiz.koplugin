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
local QuizBank   = require("quiz_bank")
local ScreenBase = require("screen_base")

-- Loaded from this plugin's own directory (a generic name such as
-- "quiz_rules" could otherwise be another plugin's file on package.path).
local Rules = assert(loadfile(_dir .. "quiz_rules.lua"))()

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

local DEFAULT_DURATION = 30   -- seconds to answer (0 = no timer)
local DEFAULT_NB_PLAYERS = 4

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

-- key_prefix: "" for the Quiz entry; party_screen.lua (Quiz · multiplayer,
-- Classic rule) sets "party_" so its language and timer are its own.
local QuizScreen = ScreenBase:extend{ key_prefix = "" }

QuizScreen.jsonDecode = jsonDecode

function QuizScreen:_key(name)
    return self.key_prefix .. name
end

-- Question language (bundled banks: quiz_questions_fr.lua and _en.lua).
-- The Quiz entry's is PluginBase:getLang/setLang: KOReader's language,
-- unless one was picked in the game under KOReader's current language.
-- Quiz · multiplayer (prefix "party_", both rules) keeps its own the same
-- way ("party_lang", picked under "party_lang_ko") and, until it has one,
-- follows the Quiz entry's.
local LANGS = { "fr", "en" }

local function koreaderLang()
    return (G_reader_settings and G_reader_settings:readSetting("language") or "en"):sub(1, 2)
end

function QuizScreen.getContentLang(plugin, prefix)
    if prefix and prefix ~= "" then
        local saved = plugin:getSetting(prefix .. "lang")
        if (saved == "fr" or saved == "en")
                and plugin:getSetting(prefix .. "lang_ko") == koreaderLang() then
            return saved
        end
    end
    return plugin:getLang(LANGS)
end

function QuizScreen.setContentLang(plugin, prefix, lang)
    if not prefix or prefix == "" then return plugin:setLang(lang) end
    plugin:saveSetting(prefix .. "lang", lang)
    plugin:saveSetting(prefix .. "lang_ko", koreaderLang())
end

function QuizScreen:init()
    self.lang       = QuizScreen.getContentLang(self.plugin, self.key_prefix)
    self.duration   = self.plugin:getSetting(self:_key("duration"))
        or self.plugin:getSetting("duration", DEFAULT_DURATION)

    self:_initPlayers()

    self.questions       = {}
    self.q_index         = 1
    self.phase           = "question"  -- "question" | "answer"
    self.time_remaining  = self.duration

    -- selected_categories: nil = all; {category = true, ...} = subset
    self.selected_categories = self:_loadCategorySelection()
    self.all_categories      = {}   -- category → question count, filled by _loadQuestions
    self._raw_data           = nil  -- cached raw data for re-filtering without I/O
    self._data_is_lua        = false

    self.seen = QuizBank.openHistory(self.plugin, self.lang)
    self:_loadQuestions()
    ScreenBase.init(self)
    if self.duration > 0 then
        self:_startCountdown()
    end
end

function QuizScreen:_initPlayers()
    local nb = self.plugin:getSetting("nb_players", DEFAULT_NB_PLAYERS)
    self.players = {}
    for i = 1, nb do
        self.players[i] = {
            name  = self.plugin:getSetting("player_name_" .. i, T(_("Player %1"), i)),
            score = 0,
        }
    end
end

-- ---------------------------------------------------------------------------
-- Category-selection persistence (stored as "cat1,cat2,..." or "" = all)
-- ---------------------------------------------------------------------------

function QuizScreen:_loadCategorySelection()
    local saved = self.plugin:getSetting("selected_categories_" .. self.lang, "")
    if not saved or saved == "" then return nil end
    local sel = {}
    for cat in saved:gmatch("[^\1]+") do
        sel[cat] = true
    end
    return sel
end

function QuizScreen:_saveCategorySelection()
    if self.selected_categories == nil then
        self.plugin:saveSetting("selected_categories_" .. self.lang, "")
        return
    end
    local parts = {}
    for cat in pairs(self.selected_categories) do
        parts[#parts + 1] = cat
    end
    table.sort(parts)
    self.plugin:saveSetting("selected_categories_" .. self.lang, table.concat(parts, "\1"))
end

-- ---------------------------------------------------------------------------
-- Category filtering
-- ---------------------------------------------------------------------------

-- data is {category = [{question,answer,category,difficulty}, ...], ...}
function QuizScreen:_filterByCategory(data)
    local sel   = self.selected_categories
    local questions = {}
    for cat, cat_questions in pairs(data) do
        if sel == nil or sel[cat] then
            for _, q in ipairs(cat_questions) do
                questions[#questions + 1] = q
            end
        end
    end
    return questions
end

-- data is a flat array [{question,answer,category,difficulty}, ...]
function QuizScreen:_filterByCategoryFlat(data)
    local sel = self.selected_categories
    if sel == nil then return data end
    local questions = {}
    for _, q in ipairs(data) do
        local cat = q.category or q.cat or self:_otherCategory()
        if sel[cat] then
            questions[#questions + 1] = q
        end
    end
    return questions
end

-- Bucket for flat-JSON questions with no category field.
function QuizScreen:_otherCategory()
    return self.lang == "fr" and "Autres" or "Other"
end

-- Re-filter from cached raw data (called after category selection changes)
function QuizScreen:_reloadQuestions()
    if self._raw_data == nil then return end
    if self._data_is_lua then
        self.questions = self:_filterByCategory(self._raw_data)
    else
        self.questions = self:_filterByCategoryFlat(self._raw_data)
    end
    self:_shuffleQuestions()
end

-- ---------------------------------------------------------------------------
-- Question loading (see quiz_bank.lua for the source order)
-- ---------------------------------------------------------------------------

function QuizScreen:_loadQuestions()
    -- Drop the previous bank first so it can be collected before the next
    -- one is read (language switch on a 256 MB reader).
    self.questions       = {}
    self._raw_data       = nil
    self.all_categories  = {}

    local data, is_lua = QuizBank.load(DataStorage:getDataDir(), _dir, self.lang, jsonDecode)
    if not data then return end

    self._raw_data    = data
    self._data_is_lua = is_lua
    if is_lua then
        for cat, cat_questions in pairs(data) do
            self.all_categories[cat] = #cat_questions
        end
        self.questions = self:_filterByCategory(data)
    else
        for _i, q in ipairs(data) do
            local cat = q.category or q.cat or self:_otherCategory()
            self.all_categories[cat] = (self.all_categories[cat] or 0) + 1
        end
        self.questions = self:_filterByCategoryFlat(data)
    end
    self:_shuffleQuestions()
end

-- Questions not seen in earlier sessions come first (see quiz_bank.lua).
-- A filtered list is a fresh table, but a flat user file with every
-- category kept is _raw_data itself: reordering it in place is harmless.
function QuizScreen:_shuffleQuestions()
    QuizBank.order(self.seen, self.questions)
    self.q_index   = 1
    self._shown_at = nil
end

-- The question on screen, marked as seen the first time it is shown (the
-- layout is rebuilt several times per question).
function QuizScreen:_currentQuestion()
    if #self.questions == 0 then return nil end
    if self.q_index > #self.questions then self:_shuffleQuestions() end
    local q = self.questions[self.q_index]
    if self._shown_at ~= self.q_index then
        self._shown_at = self.q_index
        if self.seen then self.seen:mark(q) end
    end
    return q
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
    -- Rebuild, not just updateStatus(): the score buttons show each score.
    self:buildLayout()
    UIManager:setDirty(self, function() return "ui", self.dimen end)
end

-- New game: scores back to zero, then on to a fresh question.
function QuizScreen:onNewGame()
    self:_stopCountdown()
    for _i, p in ipairs(self.players) do p.score = 0 end
    self:onNextQuestion()
end

-- ---------------------------------------------------------------------------
-- Options
-- ---------------------------------------------------------------------------

function QuizScreen:_durationLabel(dur)
    if dur <= 0 then return _("Off") end
    return string.format("%d:%02d", math.floor(dur / 60), dur % 60)
end

-- "Categories: All" or "Categories: 3/12" for the title-bar menu.
function QuizScreen:_categoriesMenuText()
    if self.selected_categories == nil then return _("Categories: All") end
    local total, sel = 0, 0
    for cat in pairs(self.all_categories) do
        total = total + 1
        if self.selected_categories[cat] then sel = sel + 1 end
    end
    return T(_("Categories: %1"), sel .. "/" .. total)
end

function QuizScreen:onReloadFile()
    self:_loadQuestions()
    self:buildLayout()
    UIManager:setDirty(self, function() return "ui", self.dimen end)
end

function QuizScreen:openLangMenu()
    MenuHelper.openPickerMenu{
        title = _("Language"),
        items = { { id = "fr", text = "Français" }, { id = "en", text = "English" } },
        current_id = self.lang, parent = self,
        on_select = function(lang)
            self.lang = lang
            QuizScreen.setContentLang(self.plugin, self.key_prefix, lang)
            self.selected_categories = self:_loadCategorySelection()
            self.seen = QuizBank.openHistory(self.plugin, lang)
            self:_loadQuestions()
            self:buildLayout()
            UIManager:setDirty(self, function() return "ui", self.dimen end)
        end,
    }
end

-- ---------------------------------------------------------------------------
-- Category-picker menu (multi-select, re-opens after each toggle)
-- ---------------------------------------------------------------------------

function QuizScreen:openCategoryMenu()

    local available = {}
    for cat in pairs(self.all_categories) do
        available[#available + 1] = cat
    end
    table.sort(available)

    if #available == 0 then
        UIManager:show(InfoMessage:new{
            text    = _("No categories available.\nLoad a question file first."),
            timeout = 3,
        })
        return
    end

    local all_selected = (self.selected_categories == nil)

    local items = {}
    items[#items + 1] = {
        id   = "__all__",
        text = (all_selected and "★ " or "  ")
               .. _("All categories")
               .. string.format("  (%d)", #self.questions),
    }
    for _, cat in ipairs(available) do
        local count = self.all_categories[cat] or 0
        local sel   = all_selected or (self.selected_categories[cat] == true)
        items[#items + 1] = {
            id   = cat,
            text = (sel and "✓ " or "○ ") .. cat
                   .. string.format("  (%d)", count),
        }
    end

    MenuHelper.openPickerMenu{
        title     = _("Categories"),
        items     = items,
        parent    = self,
        on_select = function(id)
            if id == "__all__" then
                self.selected_categories = nil
            else
                if self.selected_categories == nil then
                    -- Was "all" → keep every category except the one just tapped
                    self.selected_categories = {}
                    for _, cat in ipairs(available) do
                        if cat ~= id then
                            self.selected_categories[cat] = true
                        end
                    end
                else
                    -- Toggle the tapped category
                    if self.selected_categories[id] then
                        self.selected_categories[id] = nil
                    else
                        self.selected_categories[id] = true
                    end
                    -- Collapse back to nil if every category is now checked
                    local all_on = true
                    for _, cat in ipairs(available) do
                        if not self.selected_categories[cat] then
                            all_on = false
                            break
                        end
                    end
                    if all_on then self.selected_categories = nil end
                end
            end
            self:_reloadQuestions()
            self:_saveCategorySelection()
            self:buildLayout()
            UIManager:setDirty(self, function() return "ui", self.dimen end)
            -- Re-open to reflect the new state
            self:openCategoryMenu()
        end,
    }
end

function QuizScreen:openPlayersMenu()
    local items = {}
    for n = 2, 8 do
        items[#items + 1] = { id = n, text = T(_("%1 players"), n) }
    end
    MenuHelper.openPickerMenu{
        title = _("Players"),
        items = items, current_id = #self.players, parent = self,
        on_select = function(n)
            self.plugin:saveSetting("nb_players", n)
            while #self.players < n do
                local i = #self.players + 1
                self.players[i] = { name = T(_("Player %1"), i), score = 0 }
            end
            while #self.players > n do table.remove(self.players) end
            self:buildLayout()
            UIManager:setDirty(self, function() return "ui", self.dimen end)
        end,
    }
end

function QuizScreen:openDurationMenu()
    local items = {}
    for _i, d in ipairs({ 0, 20, 30, 45, 60 }) do
        items[#items + 1] = { id = d, text = self:_durationLabel(d) }
    end
    MenuHelper.openPickerMenu{
        title = _("Timer"),
        items = items, current_id = self.duration, parent = self,
        on_select = function(dur)
            self.duration = dur
            self.plugin:saveSetting(self:_key("duration"), dur)
        end,
    }
end

-- ---------------------------------------------------------------------------
-- Layout
-- ---------------------------------------------------------------------------

function QuizScreen:_title()
    return _("Quiz")
end

function QuizScreen:_menuItems()
    return {
        { text = _("New game"), callback = function() self:onNewGame() end },
        { text = T(_("Language: %1"), self.lang:upper()), callback = function() self:openLangMenu() end },
        { text = T(_("Players: %1"), #self.players),      callback = function() self:openPlayersMenu() end },
        { text = T(_("Timer: %1"), self:_durationLabel(self.duration)),
          callback = function() self:openDurationMenu() end },
        { text = self:_categoriesMenuText(), callback = function() self:openCategoryMenu() end },
        { text = _("Reload file"), callback = function() self:onReloadFile() end },
        self:makeModeRulesButtonConfig(Rules),
    }
end

function QuizScreen:buildLayout()

    -- Title bar with Options menu
    local title_bar = self:buildTitleBar(self:_title(), function()
        return self:_menuItems()
    end)

    -- Action bar: Reveal, or (once revealed) one score button per player
    -- above Next question.
    local rows
    if self.phase == "question" then
        rows = {{
            { text = _("Reveal answer"),
              callback = function() self:onRevealAnswer() end },
        }}
    else
        rows = {}
        local row = {}
        for i, player in ipairs(self.players) do
            row[#row + 1] = {
                text = "+" .. player.name .. " (" .. player.score .. ")",
                callback = function() self:onScorePlayer(i) end,
            }
            if #row == 3 or i == #self.players then
                rows[#rows + 1] = row
                row = {}
            end
        end
        rows[#rows + 1] = {
            { text = _("Next question"),
              callback = function() self:onNextQuestion() end },
        }
    end
    local controls = self:_buildControls(rows)
    local bw, bh = self:getBoardBudget(title_bar, controls)
    local short  = math.min(bw, bh)
    local vs     = Size.span.vertical_large

    -- Question / answer display
    local q = self:_currentQuestion()
    local frame_pad = Size.padding.large
    local inner_w   = bw - 2 * (frame_pad + Size.border.window)
    local main_widget

    if not q then
        local msg = T(_("No questions loaded.\n\nEither every category is unchecked (see Categories in the menu),\nor no question bank was found.\n\nTo use your own questions, copy\n%1 (or .lua) to\nKOReader's documents folder."),
            "quiz_questions_" .. self.lang .. ".json")
        main_widget = wrapText(msg, Font:getFace("smallinfofont"), bw)
    else
        local question_text = q.question or q.q or "?"
        local answer_text   = q.answer   or q.a or "?"
        local category_text = q.category or q.cat or ""

        local body = VerticalGroup:new{ align = "center" }
        -- Category badge
        if category_text ~= "" then
            body[#body + 1] = wrapText("[ " .. category_text .. " ]", Font:getFace("smallinfofont"), inner_w)
            body[#body + 1] = VerticalSpan:new{ width = vs }
        end

        -- Question (adapts font to length)
        local qlen = #question_text
        local q_px = short * (qlen > 80 and 0.045 or qlen > 40 and 0.055 or 0.065)
        body[#body + 1] = wrapText(question_text, pxFace(q_px), inner_w)

        if self.phase == "answer" then
            -- Answer reveal
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
            body[#body + 1] = VerticalSpan:new{ width = vs * 2 }
            body[#body + 1] = TextWidget:new{
                text = _("Who got it?"),
                face = Font:getFace("smallinfofont"),
            }
        end

        main_widget = FrameContainer:new{
            padding = frame_pad,
            margin  = 0,
            CenterContainer:new{
                dimen = Geom:new{ w = inner_w, h = body:getSize().h },
                body,
            },
        }
    end

    -- Timer (only in question phase with timer enabled)
    local content = VerticalGroup:new{ align = "center" }
    self.timer_widget = nil
    if self.phase == "question" and self.duration > 0 then
        self.timer_widget = TextWidget:new{
            text = self:_timerText(),
            face = pxFace(short * 0.12),
        }
        content[#content + 1] = self.timer_widget
        content[#content + 1] = VerticalSpan:new{ width = vs }
    end
    content[#content + 1] = main_widget

    self:_placeLayout(title_bar, content, controls)
    self:updateStatus()
end

-- Status line + action bar, built before the content so the content can be
-- sized from what they leave over (getBoardBudget).
function QuizScreen:_buildControls(rows)
    self.status_text:setMaxWidth(self:getControlsWidth())
    return VerticalGroup:new{
        align = "center",
        self.status_text,
        VerticalSpan:new{ width = Size.span.vertical_large },
        self:buildActionBar(rows),
    }
end

function QuizScreen:_placeLayout(title_bar, content, controls)
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
function QuizScreen:_scoreStatus(list)
    local parts = {}
    for _i, t in ipairs(list) do
        parts[#parts + 1] = T(_("%1: %2"), t.name, t.score)
    end
    return self:joinStatus((table.unpack or unpack)(parts))
end

function QuizScreen:updateStatus(msg)
    if msg then ScreenBase.updateStatus(self, msg); return end
    -- Question counter first: with many players the scores get cut off at
    -- the screen edge, the counter should not be.
    ScreenBase.updateStatus(self, self:joinStatus(
        #self.questions > 0 and string.format("Q%d/%d", self.q_index, #self.questions) or nil,
        self:_scoreStatus(self.players)))
end

function QuizScreen:onClose()
    self:_stopCountdown()
    ScreenBase.onClose(self)
end

return QuizScreen

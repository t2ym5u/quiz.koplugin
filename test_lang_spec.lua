-- Question language: the Quiz deals KOReader's language (French when
-- KOReader is in French), unless a language was picked in the game's menu
-- while KOReader had its current language. Quiz · multiplayer (both rules)
-- keeps its own choice ("party_lang") the same way and, until it has one,
-- follows the Quiz entry's. A language saved by an older version (no
-- "lang_ko" / "party_lang_ko") is dropped: it used to stick for good.
local DIR = debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])") or "./"

-- KOReader is not there: every module the screen requires that is not in
-- this plugin or common/ is a permissive stub (any field is a stub, a call
-- returns its first number or string argument, arithmetic gives 0).
local permissive
local function first_value(...)
    for i = 1, select("#", ...) do
        local v = select(i, ...)
        if type(v) == "number" or type(v) == "string" then return v end
    end
    return permissive()
end
local function zero() return 0 end
permissive = function()
    return setmetatable({}, {
        __index = function(t, k) local v = permissive(); rawset(t, k, v); return v end,
        __call = function(_, ...) return first_value(...) end,
        __add = zero, __sub = zero, __mul = zero, __div = zero, __unm = zero,
        __mod = zero, __idiv = zero,
        __concat = function() return "" end,
        __lt = function() return false end, __le = function() return false end,
    })
end
local function stubSearcher(name)
    return function() return permissive() end, name
end

-- The screen's base class: init does nothing (no layout).
local ScreenBase = {}
ScreenBase.__index = ScreenBase
function ScreenBase:extend(o) o = o or {}; o.__index = o; return setmetatable(o, self) end
function ScreenBase.init() end

-- The language menu: remember the picker it opens.
local picker
local MenuHelper = setmetatable({
    openPickerMenu = function(o) picker = o end,
}, { __index = function() return function() end end })

local PRELOADS = {
    screen_base = function() return ScreenBase end,
    menu_helper = function() return MenuHelper end,
    i18n = function()
        return setmetatable({ lang = function() return "fr" end, extend = function() end },
            { __call = function(_, s) return s end })
    end,
    ["ui/widget/container/widgetcontainer"] = function()
        return { extend = function(self, o) o = o or {}; o.__index = o; return setmetatable(o, { __index = self }) end }
    end,
}

local saved = {}
local PluginBase

local function koreader(lang)
    _G.G_reader_settings = { readSetting = function(_, k) if k == "language" then return lang end end }
end

-- A plugin whose settings live in a plain table.
local function newPlugin(store)
    store = store or {}
    local p = setmetatable({}, { __index = PluginBase })
    p.ensureSettings = function() end
    p.settings = {
        readSetting = function(_, k) return store[k] end,
        saveSetting = function(_, k, v) store[k] = v end,
        flush = function() end,
    }
    return p, store
end

local function setupHarness()
    saved.path = package.path
    saved.G = _G.G_reader_settings
    saved.preload = {}
    for name, f in pairs(PRELOADS) do
        saved.preload[name] = package.preload[name]
        package.preload[name] = f
    end
    saved.loaded = {}
    for k, v in pairs(package.loaded) do saved.loaded[k] = v end
    for name in pairs(PRELOADS) do package.loaded[name] = nil end
    package.path = DIR .. "?.lua;" .. DIR .. "common/?.lua;" .. package.path
    local searchers = package.searchers or package.loaders
    searchers[#searchers + 1] = stubSearcher
    PluginBase = dofile(DIR .. "common/plugin_base.lua")
end

local function teardownHarness()
    local searchers = package.searchers or package.loaders
    for i = #searchers, 1, -1 do
        if searchers[i] == stubSearcher then table.remove(searchers, i) end
    end
    for name, v in pairs(saved.preload) do package.preload[name] = v end
    for k in pairs(package.loaded) do
        if saved.loaded[k] == nil then package.loaded[k] = nil end
    end
    for k, v in pairs(saved.loaded) do package.loaded[k] = v end
    package.path = saved.path
    _G.G_reader_settings = saved.G
end

-- Picks `lang` in the screen's language menu.
local function pickLang(screen, lang)
    picker = nil
    screen:openLangMenu()
    assert.is_table(picker, "the language menu opened no picker")
    picker.on_select(lang)
end

local Screens = {}
local CONTENT = {
    fr = { "quiz_questions_fr.lua", "double_questions_fr.lua" },
    en = { "quiz_questions_en.lua", "double_questions_en.lua" },
}

-- Every string in the given content files.
local STRINGS = {}
local function strings(lang)
    if not STRINGS[lang] then
        local set = {}
        local function walk(v)
            if type(v) == "string" then set[v] = true
            elseif type(v) == "table" then for _k, x in pairs(v) do walk(x) end end
        end
        for _i, path in ipairs(CONTENT[lang]) do walk(dofile(DIR .. path)) end
        STRINGS[lang] = set
    end
    return STRINGS[lang]
end

-- The screen plays `lang`: the questions it has come from that language's
-- banks, and some of them are not in the other language's.
local function dealsIn(screen, lang)
    if screen.lang ~= lang then return false end
    local mine, other = strings(lang), strings(lang == "fr" and "en" or "fr")
    assert.is_true(#screen.questions > 0, "no questions")
    local own = false
    for i, q in ipairs(screen.questions) do
        if i > 20 then break end
        if not mine[q.question] then return false end
        if not other[q.question] then own = true end
    end
    return own
end

-- kind: "solo" (Quiz), "classic" or "double" (Quiz · multiplayer).
local function open(kind, store)
    local Screen = Screens[kind]
    local s = setmetatable({ plugin = (newPlugin(store)) }, Screen)
    for _i, name in ipairs({ "_redraw", "buildLayout", "_startCountdown" }) do
        s[name] = function() end
    end
    s:init()
    return s
end

describe("Quiz question language", function()
    setup(function()
        setupHarness()
        Screens.solo    = dofile(DIR .. "screen.lua")
        Screens.classic = dofile(DIR .. "party_screen.lua")
        Screens.double  = dofile(DIR .. "double_screen.lua")
    end)
    teardown(teardownHarness)

    it("deals French questions when KOReader is in French", function()
        koreader("fr")
        for _i, kind in ipairs({ "solo", "classic", "double" }) do
            assert.is_true(dealsIn(open(kind), "fr"), kind)
        end
        koreader("en_US")
        for _i, kind in ipairs({ "solo", "classic", "double" }) do
            assert.is_true(dealsIn(open(kind), "en"), kind)
        end
    end)

    it("no longer keeps English saved by an older version (no lang_ko)", function()
        koreader("fr")
        for _i, kind in ipairs({ "solo", "classic", "double" }) do
            assert.is_true(dealsIn(open(kind, { lang = "en", party_lang = "en" }), "fr"), kind)
        end
    end)

    it("keeps a language picked in the Quiz while KOReader's stays the same", function()
        koreader("fr")
        local store = {}
        local s = open("solo", store)
        pickLang(s, "en")
        assert.is_true(dealsIn(s, "en"))
        assert.is_true(dealsIn(open("solo", store), "en"))
        -- multiplayer has no choice of its own yet: it follows the Quiz's
        assert.is_true(dealsIn(open("classic", store), "en"))
        assert.is_true(dealsIn(open("double", store), "en"))
        koreader("en")
        pickLang(open("solo", store), "fr")
        koreader("fr")
        assert.is_true(dealsIn(open("solo", store), "fr"))
        koreader("en")
        assert.is_true(dealsIn(open("solo", store), "fr"))
    end)

    it("keeps multiplayer's own language, picked under either rule", function()
        koreader("fr")
        local store = {}
        pickLang(open("classic", store), "en")
        assert.are.equal("en", store.party_lang)
        assert.is_true(dealsIn(open("classic", store), "en"))
        assert.is_true(dealsIn(open("double", store), "en"))
        assert.is_true(dealsIn(open("solo", store), "fr"))   -- the Quiz entry's is its own
        local d = open("double", store)
        pickLang(d, "fr")
        assert.is_true(dealsIn(d, "fr"))
        assert.is_true(dealsIn(open("classic", store), "fr"))
        koreader("en")                                         -- KOReader changes: follow it
        assert.is_true(dealsIn(open("classic", store), "en"))
    end)
end)

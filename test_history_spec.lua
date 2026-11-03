-- Questions shown in one session do not come back in the next one until the
-- rest of the pool has been played (quiz_bank.lua + game-common seen_history).
local DIR = debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])") or "./"
package.path = DIR .. "?.lua;" .. DIR .. "common/?.lua;" .. package.path

local QuizBank = require("quiz_bank")

-- Plugin settings as PluginBase keeps them (survive across "sessions").
local function fakePlugin()
    local store = {}
    return {
        store = store,
        getSetting  = function(_self, k, d) if store[k] == nil then return d end return store[k] end,
        saveSetting = function(_self, k, v) store[k] = v end,
    }
end

-- One evening: open the history, order the list, show `n` questions.
local function session(plugin, lang, list, n)
    local seen = QuizBank.openHistory(plugin, lang)
    local copy = {}
    for i, q in ipairs(list) do copy[i] = q end
    QuizBank.order(seen, copy)
    local shown = {}
    for i = 1, n do
        shown[i] = copy[i]
        seen:mark(copy[i])
    end
    return shown
end

local function category(lang, name)
    local bank = QuizBank.loadLua(DIR .. "quiz_questions_" .. lang .. ".lua")
    if name then return bank[name] end
    local all = {}
    for _cat, qs in pairs(bank) do
        for _i, q in ipairs(qs) do all[#all + 1] = q end
    end
    return all
end

describe("quiz history across sessions", function()
    it("gives every question of a category before any repeat (en)", function()
        local p = fakePlugin()
        local list = category("en", "Animals")
        local half = math.floor(#list / 2)
        local got = {}
        for _i, q in ipairs(session(p, "en", list, half)) do got[q.question] = true end
        for _i, q in ipairs(session(p, "en", list, #list - half)) do
            assert.is_nil(got[q.question], "repeated: " .. q.question)
            got[q.question] = true
        end
        local n = 0
        for _k in pairs(got) do n = n + 1 end
        assert.equals(#list, n)
        -- Pool used up: a third session starts a new cycle instead of failing.
        assert.equals(5, #session(p, "en", list, 5))
    end)

    it("keeps one history per language", function()
        local p = fakePlugin()
        session(p, "fr", category("fr"), 30)
        assert.is_table(p.store.seen_questions_fr)
        assert.is_nil(p.store.seen_questions_en)
    end)

    it("remembers the whole French bank (3,200 ids >= pool)", function()
        assert.is_true(QuizBank.HISTORY_MAX >= #category("fr"))
    end)

    it("hashes question text to short distinct ids", function()
        for _i, lang in ipairs({ "fr", "en" }) do
            local ids, n, dup = {}, 0, 0
            for _j, q in ipairs(category(lang)) do
                local id = QuizBank.questionId(q)
                assert.equals(8, #id)
                if ids[id] and ids[id] ~= q.question then dup = dup + 1 end
                ids[id] = q.question
                n = n + 1
            end
            assert.is_true(dup <= 2, lang .. ": " .. dup .. " hash collisions")
        end
    end)

    it("works for a user's flat file (questions keyed by text)", function()
        local p = fakePlugin()
        local list = {}
        for i = 1, 6 do list[i] = { question = "Q" .. i, answer = "A" } end
        local first = session(p, "en", list, 3)
        local second = session(p, "en", list, 3)
        local got = {}
        for _i, q in ipairs(first) do got[q.question] = true end
        for _i, q in ipairs(second) do assert.is_nil(got[q.question]) end
    end)
end)

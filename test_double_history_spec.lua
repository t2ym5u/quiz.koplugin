-- Double or nothing rule: questions played in one session come back in the
-- next one only once the rest of their level has been played
-- (double_deck.lua + the Quiz's history, game-common seen_history). The
-- history is the Quiz's own, shared by both rules.
local DIR = debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])") or "./"
package.path = DIR .. "?.lua;" .. DIR .. "common/?.lua;" .. package.path

local Deck     = require("double_deck")
local QuizBank = require("quiz_bank")

local function fakePlugin()
    local store = {}
    return {
        store = store,
        getSetting  = function(_self, k, d) if store[k] == nil then return d end return store[k] end,
        saveSetting = function(_self, k, v) store[k] = v end,
    }
end

local function bank(lang)
    return Deck.loadRated(DIR, lang)
end

-- One evening: a fresh screen (new session set, history reopened from the
-- settings), `n` draws at `level` in one category.
local function session(plugin, lang, cat, level, n, list)
    local deck = Deck.new(list or bank(lang), { category = cat, seen = QuizBank.openHistory(plugin, lang) })
    local out = {}
    for i = 1, n do out[i] = deck:draw(level) end
    return out
end

describe("double or nothing history across sessions", function()
    it("does not replay last session's level-1 questions while unseen ones remain", function()
        local p = fakePlugin()
        local first = session(p, "en", "Geography", 1, 5)
        local got = {}
        for _i, q in ipairs(first) do
            assert.equals(1, q.level)
            got[q.question] = true
        end
        local second = session(p, "en", "Geography", 1, 5)
        for _i, q in ipairs(second) do
            assert.equals(1, q.level)
            assert.is_nil(got[q.question], "repeated: " .. q.question)
        end
    end)

    it("stays at the asked level once every question of it was seen before", function()
        local p = fakePlugin()
        local lvl1 = 0
        for _i, q in ipairs(bank("fr")) do
            if q.category == "Sport" and q.level == 1 then lvl1 = lvl1 + 1 end
        end
        session(p, "fr", "Sport", 1, lvl1)          -- the whole level, evening 1
        -- Evening 2: level 1 again, not a drift to level 2.
        local again = session(p, "fr", "Sport", 1, 3)
        local got = {}
        for _i, q in ipairs(again) do
            assert.equals(1, q.level)
            assert.is_nil(got[q.question])
            got[q.question] = true
        end
    end)

    it("keeps one history per language, the Quiz's, within the cap", function()
        local p = fakePlugin()
        session(p, "fr", nil, 3, 10)
        assert.equals(10, #p.store.seen_questions_fr)
        assert.is_nil(p.store.seen_questions_en)
        -- ids are the Quiz's question hashes
        assert.is_truthy(p.store.seen_questions_fr[1]:match("^%x%x%x%x%x%x%x%x$"))
    end)

    it("does not ask again a question the Classic rule showed", function()
        local p = fakePlugin()
        local list = Deck.normalize({
            { question = "A?", answer = "a", difficulty = 2 },
            { question = "B?", answer = "b", difficulty = 2 },
        })
        -- the Classic rule (screen.lua) marks what it shows
        QuizBank.openHistory(p, "en"):mark({ question = "A?", answer = "a" })
        local q = session(p, "en", nil, 2, 1, list)[1]
        assert.equals("B?", q.question)
    end)

    it("works for a user's flat JSON-shaped list", function()
        local p = fakePlugin()
        local list = Deck.normalize({
            { question = "A?", answer = "a", difficulty = 1 },
            { question = "B?", answer = "b", difficulty = 1 },
            { question = "C?", answer = "c", difficulty = 1 },
            { question = "D?", answer = "d", difficulty = 1 },
        })
        local d1 = Deck.new(list, { seen = QuizBank.openHistory(p, "en") })
        local a, b = d1:draw(1), d1:draw(1)
        local d2 = Deck.new(list, { seen = QuizBank.openHistory(p, "en") })
        local c, d = d2:draw(1), d2:draw(1)
        for _i, q in ipairs({ c, d }) do
            assert.is_true(q ~= a and q.question ~= a.question and q.question ~= b.question)
        end
    end)
end)

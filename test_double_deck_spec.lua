-- The deck decides which question comes next: at the turn's difficulty, and
-- never one already played this session until the whole deck has gone by.
local DIR = debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])") or "./"

package.path = DIR .. "?.lua;" .. DIR .. "common/?.lua;" .. package.path

local Deck  = require("double_deck")
local Round = require("double_round")

-- n questions at each level of `levels`, named "L<level>-<i>".
local function makeList(levels, n)
    local list = {}
    for _, l in ipairs(levels) do
        for i = 1, n do
            list[#list + 1] = { question = "L" .. l .. "-" .. i, answer = "a", category = "C" .. (i % 2), level = l }
        end
    end
    return list
end

describe("Deck.normalize", function()
    it("flattens the bundled grouped format", function()
        local list = Deck.normalize({
            { cat = "Sport", q = { { 2, "Q1 ?", "A1" }, { 5, "Q2 ?", "A2", "B2" } } },
            { cat = "Arts",  q = { { 1, "Q3 ?", "A3" } } },
        })
        assert.are.equal(3, #list)
        assert.are.same({ question = "Q2 ?", answer = "A2", category = "Sport", level = 5, rated = true, alt = "B2" }, list[2])
        assert.are.equal("Arts", list[3].category)
    end)

    it("reads a user JSON list, with or without a difficulty", function()
        local list = Deck.normalize({
            { question = "Q1", answer = "A1", category = "Geo", difficulty = 4 },
            { question = "Q2", answer = "A2" },
            { question = "Q3", answer = 1969, level = "2" },
            { question = "Q4", answer = "A4", difficulty = "hard" },
        })
        assert.are.equal(4, #list)
        assert.are.equal(4, list[1].level)
        assert.is_true(list[1].rated)
        assert.are.equal(Deck.DEFAULT_LEVEL, list[2].level)
        assert.is_false(list[2].rated)
        assert.is_nil(list[2].category)
        assert.are.equal("1969", list[3].answer)
        assert.are.equal(2, list[3].level)
        assert.are.equal(5, list[4].level)
    end)

    it("skips malformed entries instead of failing the file", function()
        local list = Deck.normalize({ { question = "no answer" }, "junk", { answer = "x" },
            { question = "  ", answer = "x" }, { question = "ok", answer = "y" } })
        assert.are.equal(1, #list)
        assert.are.same({}, Deck.normalize(nil))
        assert.are.same({}, Deck.normalize("not a table"))
    end)

    it("clamps out-of-range levels", function()
        assert.are.equal(1, Deck.parseLevel(0))
        assert.are.equal(5, Deck.parseLevel(9))
        assert.are.equal(3, Deck.parseLevel("?"))
    end)
end)

describe("Deck:draw", function()
    it("draws at the asked level", function()
        local deck = Deck.new(makeList({ 1, 2, 3, 4, 5 }, 4))
        for l = 1, 5 do
            assert.are.equal(l, deck:draw(l).level)
        end
    end)

    it("never repeats a question until the deck is exhausted", function()
        local list = makeList({ 1, 2, 3, 4, 5 }, 6)
        local deck = Deck.new(list)
        local seen = {}
        for i = 1, #list do
            local q = deck:draw((i % 5) + 1)
            assert.is_nil(seen[q.question], "repeated " .. q.question .. " at draw " .. i)
            seen[q.question] = true
        end
        assert.are.equal(0, deck:remaining())
        -- the next draw starts a new cycle instead of failing
        assert.is_not_nil(deck:draw(3))
        assert.are.equal(#list - 1, deck:remaining())
    end)

    it("falls back to the nearest level, harder first, when a level runs out", function()
        local deck = Deck.new(makeList({ 2, 4 }, 1))
        assert.are.equal(4, deck:draw(3).level)   -- tie between 2 and 4: harder wins
        assert.are.equal(2, deck:draw(3).level)
        local only3 = Deck.new(makeList({ 3 }, 3))
        assert.are.equal(3, only3:draw(1).level)  -- a deck without levels still plays
        assert.are.equal(3, only3:draw(5).level)
    end)

    it("plays a whole turn on a rising level: 1-2, then +1 per Double, capped", function()
        local deck = Deck.new(makeList({ 1, 2, 3, 4, 5 }, 10))
        for _ = 1, 20 do
            local level = Round.startLevel()
            local q = deck:draw(level)
            assert.is_true(q.level <= 2)
            for _d = 1, 5 do
                local prev = level
                level = Round.nextLevel(level)
                assert.are.equal(math.min(5, prev + 1), level)
                -- exact level while that level has questions left; level 5 is
                -- asked for most and runs dry first, then the nearest one serves
                local exact = deck:remaining(level) > 0
                q = deck:draw(level)
                if exact then assert.are.equal(level, q.level) end
            end
        end
    end)

    it("filters by category", function()
        local deck = Deck.new(makeList({ 1, 2, 3 }, 4), { category = "C1" })
        assert.are.equal(6, deck:size())
        for _ = 1, 6 do assert.are.equal("C1", deck:draw(2).category) end
    end)

    it("keeps the session history across a rebuild (category change, reload)", function()
        local list, used = makeList({ 1, 2, 3, 4, 5 }, 2), {}
        local first = Deck.new(list, { used = used })
        local played = {}
        for l = 1, 5 do played[first:draw(l).question] = true end
        local second = Deck.new(list, { used = used })
        assert.are.equal(5, second:remaining())
        for l = 1, 5 do
            assert.is_nil(played[second:draw(l).question])
        end
    end)

    it("returns nil from an empty deck", function()
        assert.is_nil(Deck.new({}):draw(1))
        assert.is_nil(Deck.new(makeList({ 1 }, 2), { category = "none" }):draw(1))
    end)

    it("lists categories once, sorted", function()
        assert.are.same({ "C0", "C1" }, Deck.categories(makeList({ 1, 2 }, 3)))
    end)
end)

-- ---------------------------------------------------------------------------
-- Quiz · multiplayer: the Quiz questions join the rated bank
-- ---------------------------------------------------------------------------

local QuizBank = require("quiz_bank")

describe("Deck.fromQuiz", function()
    it("places the Quiz's three difficulties at levels 2, 3 and 4", function()
        local list = Deck.fromQuiz({
            Sport = {
                { question = "E?", answer = "e", category = "Sport", difficulty = "facile" },
                { question = "M?", answer = "m", category = "Sport", difficulty = "medium" },
                { question = "H?", answer = "h", category = "Sport", difficulty = "difficile" },
                { question = "N?", answer = "n", category = "Sport" },
            },
        }, true)
        assert.are.equal(4, #list)
        assert.are.same({ 2, 3, 4, 3 }, { list[1].level, list[2].level, list[3].level, list[4].level })
        assert.is_true(list[1].rated)
        assert.is_false(list[4].rated)
        assert.are.equal("Sport", list[1].category)
    end)

    it("reads a flat user list, keeping a 1..5 number as it is", function()
        local list = Deck.fromQuiz({
            { question = "A?", answer = "a", difficulty = 5 },
            { question = "B?", answer = "b", difficulty = "hard" },
            { q = "C?", a = "c", cat = "X" },
        }, false)
        assert.are.same({ 5, 4, 3 }, { list[1].level, list[2].level, list[3].level })
        assert.are.equal("X", list[3].category)
    end)

    it("is empty for nothing", function()
        assert.are.same({}, Deck.fromQuiz(nil, true))
    end)
end)

describe("Deck.merge", function()
    it("keeps the first copy of a question asked by both banks", function()
        local rated = Deck.normalize({ { cat = "Geo", q = { { 1, "Same?", "Rated" } } } })
        local quiz  = Deck.fromQuiz({ { question = "Same?", answer = "Quiz", difficulty = "hard" },
                                      { question = "Other?", answer = "o" } }, false)
        local all = Deck.merge(rated, quiz)
        assert.are.equal(2, #all)
        assert.are.equal("Rated", all[1].answer)
        assert.are.equal(1, all[1].level)
    end)
end)

describe("Deck.loadPool", function()
    local tmp = os.tmpname()
    os.remove(tmp)
    local docs = tmp .. "_docs"
    os.execute("mkdir -p '" .. docs .. "'")
    local json = function(s) return assert((loadstring or load)("return " .. s))() end

    local function write(name, content)
        local f = assert(io.open(docs .. "/" .. name, "w"))
        f:write(content)
        f:close()
    end

    teardown(function() os.execute("rm -rf '" .. docs .. "'") end)

    local function counts(list)
        local c = { 0, 0, 0, 0, 0 }
        for _, q in ipairs(list) do c[q.level] = c[q.level] + 1 end
        return c
    end

    for _, lang in ipairs({ "fr", "en" }) do
        it("is the rated bank plus the Quiz bank (" .. lang .. ")", function()
            local pool, path = Deck.loadPool(docs, DIR, lang, json, QuizBank)
            assert.is_nil(path)
            local rated = Deck.loadRated(DIR, lang)
            local data, is_dict = QuizBank.load(docs, DIR, lang, json)
            local quiz = Deck.fromQuiz(data, is_dict)
            local c = counts(pool)
            print(string.format("\n%s pool: %d questions (rated %d + quiz %d, %d shared), levels 1-5: %d %d %d %d %d",
                lang, #pool, #rated, #quiz, #rated + #quiz - #pool, c[1], c[2], c[3], c[4], c[5]))
            assert.is_true(#rated >= 550)
            assert.is_true(#quiz >= 1500)
            assert.is_true(#pool > #rated + #quiz * 0.95)
            -- the ends of the ladder are the hand-rated questions only
            local rc = counts(rated)
            assert.are.equal(rc[1], c[1])
            assert.are.equal(rc[5], c[5])
            for l = 2, 4 do assert.is_true(c[l] > rc[l]) end
            -- one history holds the whole pool
            assert.is_true(QuizBank.HISTORY_MAX >= #pool, #pool .. " > " .. QuizBank.HISTORY_MAX)
        end)
    end

    it("lets the player's own Double-or-nothing file replace everything", function()
        write("quiz_double_en.json", '{ { question = "Mine?", answer = "yes", difficulty = 4 } }')
        local pool, path = Deck.loadPool(docs, DIR, "en", json, QuizBank)
        assert.are.equal(1, #pool)
        assert.are.equal(4, pool[1].level)
        assert.is_truthy(path:match("quiz_double_en%.json$"))
        os.remove(docs .. "/quiz_double_en.json")
    end)

    it("still reads a file named for the Double or Nothing plugin", function()
        write("doubleornothing_questions.json", '{ { question = "Old?", answer = "file" } }')
        local pool, path = Deck.loadPool(docs, DIR, "fr", json, QuizBank)
        assert.are.equal(1, #pool)
        assert.are.equal("Old?", pool[1].question)
        assert.is_truthy(path:match("doubleornothing_questions%.json$"))
        -- the Quiz's own names come first
        write("quiz_double.json", '{ { question = "New?", answer = "file" } }')
        pool = Deck.loadPool(docs, DIR, "fr", json, QuizBank)
        assert.are.equal("New?", pool[1].question)
        os.remove(docs .. "/doubleornothing_questions.json")
        os.remove(docs .. "/quiz_double.json")
    end)

    it("takes the player's own Quiz file as the Quiz part", function()
        write("quiz_questions_en.json", '{ { question = "Q1?", answer = "a", difficulty = "easy" } }')
        local pool = Deck.loadPool(docs, DIR, "en", json, QuizBank)
        local rated = Deck.loadRated(DIR, "en")
        assert.are.equal(#rated + 1, #pool)
        assert.are.equal("Q1?", pool[#pool].question)
        assert.are.equal(2, pool[#pool].level)
        os.remove(docs .. "/quiz_questions_en.json")
    end)
end)

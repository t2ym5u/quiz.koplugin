-- One-time import from the retired Double or Nothing plugin (now the
-- "Double or nothing" rule of Quiz · multiplayer): settings, question
-- history and the game_stats.lua row (quiz_migrate.lua).
local DIR = debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])") or "./"
package.path = DIR .. "?.lua;" .. DIR .. "common/?.lua;" .. package.path

local Migrate  = require("quiz_migrate")
local QuizBank = require("quiz_bank")

local function getter(t)
    return function(k) return t[k] end
end

describe("Migrate.settings", function()
    it("imports nothing without a Double or Nothing settings file", function()
        assert.are.same({}, Migrate.settings(nil, getter({})))
    end)

    it("imports language, teams, timer, category and picks the rule", function()
        local out = Migrate.settings({
            lang = "en", duration = 30, nb_teams = 4,
            team_name_1 = "Les Bleus", team_name_3 = "Rouges",
            category_fr = "Sport", category_en = "all",
        }, getter({}))
        assert.are.same({
            party_lang = "en", party_double_duration = 30, party_team_count = 4,
            party_teams = { "Les Bleus", "", "Rouges" },
            party_double_category_fr = "Sport", party_double_category_en = "all",
            party_rule = "double",
        }, out)
    end)

    it("never overwrites a value the Quiz already has", function()
        local out = Migrate.settings({ lang = "en", duration = 30, nb_teams = 4, category_fr = "Sport" },
            getter({ party_lang = "fr", party_double_duration = 0, party_team_count = 2,
                     party_double_category_fr = "Histoire", party_rule = "classic" }))
        assert.are.same({}, out)
    end)

    it("skips values Double or Nothing could not have written", function()
        local out = Migrate.settings({ lang = "de", duration = 17, nb_teams = 9, team_name_2 = "  " },
            getter({}))
        assert.are.same({ party_rule = "double" }, out)
    end)

    it("merges the question history, Double or Nothing's as the older part", function()
        local mine = { QuizBank.questionId("Quiz question?") }
        local out = Migrate.settings({
            seen_questions_fr = { "Quelle est la capitale de l'Italie ?", "Quiz question?" },
        }, getter({ seen_questions_fr = mine }))
        assert.are.same({ QuizBank.questionId("Quelle est la capitale de l'Italie ?"), mine[1] },
            out.seen_questions_fr)
        assert.is_nil(out.seen_questions_en)
    end)
end)

describe("Migrate.history", function()
    it("is nil when there is nothing new", function()
        assert.is_nil(Migrate.history(nil, {}))
        assert.is_nil(Migrate.history({ "A?" }, { QuizBank.questionId("A?") }))
    end)

    it("stays within the Quiz's cap, dropping the oldest", function()
        local don, quiz = {}, {}
        for i = 1, 600 do don[i] = "D" .. i .. "?" end
        for i = 1, QuizBank.HISTORY_MAX - 100 do quiz[i] = string.format("%08x", i) end
        local out = Migrate.history(don, quiz)
        assert.are.equal(QuizBank.HISTORY_MAX, #out)
        assert.are.equal(quiz[#quiz], out[#out])                -- newest kept
        assert.are.equal(QuizBank.questionId("D501?"), out[1])  -- oldest 500 dropped
    end)
end)

describe("Migrate.stats", function()
    it("folds Double or Nothing's sessions in as multiplayer ones", function()
        local row = Migrate.stats(
            { sessions = 5, time_played = 600, last_played = 1000 },
            { sessions = 3, time_played = 900, last_played = 2000 })
        assert.are.same({ sessions = 8, time_played = 1500, last_played = 2000,
                          last_solo_played = 1000, last_party_played = 2000 }, row)
    end)

    it("keeps the Quiz's later times", function()
        local row = Migrate.stats(
            { sessions = 1, time_played = 10, last_played = 3000, last_solo_played = 3000, last_party_played = 2500 },
            { sessions = 2, time_played = 20, last_played = 2000 })
        assert.are.equal(3000, row.last_played)
        assert.are.equal(2500, row.last_party_played)
        assert.are.equal(3000, row.last_solo_played)
    end)

    it("creates the Quiz's row when it has none", function()
        assert.are.same({ sessions = 2, time_played = 0, last_played = 7, last_party_played = 7 },
            Migrate.stats(nil, { sessions = 2, last_played = 7 }))
    end)

    it("is nil without a Double or Nothing row", function()
        assert.is_nil(Migrate.stats({ sessions = 1 }, nil))
        assert.is_nil(Migrate.stats({ sessions = 1 }, { foo = 1 }))
    end)
end)

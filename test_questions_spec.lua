-- The bundled question banks are thousands of hand-written entries, and the
-- loader (quiz_bank.lua, loadLua) only type-checks the *first* pair it sees.
-- A single malformed entry further down therefore loads fine and only blows
-- up when the player happens to draw it, mid-game. These tests read every
-- bank in full.
local DIR = debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])") or "./"

package.path = DIR .. "?.lua;" .. package.path

local QuizBank = require("quiz_bank")

-- Per language: the difficulty words used, and a floor on the bank size so a
-- truncated regeneration is caught.
local LANGS = {
    fr = { difficulties = { facile = true, moyen = true, difficile = true }, min_questions = 3000 },
    -- en was drafted in a pipe-separated format with inline notes; make sure
    -- none of that leaked into the shipped text.
    en = { difficulties = { easy = true, medium = true, hard = true },       min_questions = 1500,
           no_drafting_marks = true },
}

local function loadBank(lang)
    local bank = QuizBank.loadLua(DIR .. "quiz_questions_" .. lang .. ".lua")
    assert(bank, "quiz_questions_" .. lang .. ".lua did not load")
    return bank
end

for lang, spec in pairs(LANGS) do
    describe("quiz question bank (" .. lang .. ")", function()
        local bank

        setup(function()
            bank = loadBank(lang)
        end)

        it("is a category-keyed dict, the shape _filterByCategory expects", function()
            assert.is_table(bank)
            local categories = 0
            for key, questions in pairs(bank) do
                assert.is_string(key)
                assert.is_table(questions)
                categories = categories + 1
            end
            assert.is_true(categories >= 20, "only " .. categories .. " categories")
        end)

        it("has no holes: #list reaches every question", function()
            -- _filterByCategory walks each category with ipairs, which stops at the
            -- first nil. A hole would silently drop the rest of that category.
            for cat, questions in pairs(bank) do
                local counted = 0
                for _ in pairs(questions) do counted = counted + 1 end
                assert.are.equal(counted, #questions,
                    "category " .. cat .. " has a hole in its array")
            end
        end)

        it("holds at least " .. spec.min_questions .. " questions", function()
            local total = 0
            for _, questions in pairs(bank) do total = total + #questions end
            assert.is_true(total >= spec.min_questions, "only " .. total .. " questions")
        end)

        it("gives every question a non-empty question and answer", function()
            for cat, questions in pairs(bank) do
                for i, q in ipairs(questions) do
                    local where = cat .. " #" .. i
                    assert.is_table(q, where .. " is not a table")
                    assert.is_string(q.question, where .. " has no question")
                    assert.is_string(q.answer, where .. " has no answer")
                    assert.is_true(#q.question > 0, where .. " has an empty question")
                    assert.is_true(#q.answer > 0, where .. " has an empty answer")
                    if spec.no_drafting_marks then
                        for _, mark in ipairs({ "|", "...", "no —", "No —" }) do
                            assert.is_nil(q.question:find(mark, 1, true),
                                where .. " has a stray " .. mark .. ": " .. q.question)
                        end
                    end
                end
            end
        end)

        it("keeps each question's category field in step with its key", function()
            -- The flat-array loader falls back on q.category, so the two must agree
            -- or the same question lands in a different bucket depending on format.
            for cat, questions in pairs(bank) do
                for i, q in ipairs(questions) do
                    assert.are.equal(cat, q.category,
                        cat .. " #" .. i .. " is filed under " .. tostring(q.category))
                end
            end
        end)

        it("uses one difficulty vocabulary throughout, with every level present", function()
            local seen = {}
            for cat, questions in pairs(bank) do
                for i, q in ipairs(questions) do
                    assert.is_true(spec.difficulties[q.difficulty] == true,
                        cat .. " #" .. i .. " has difficulty " .. tostring(q.difficulty))
                    seen[q.difficulty] = true
                end
            end
            for level in pairs(spec.difficulties) do
                assert.is_true(seen[level], "no question at difficulty " .. level)
            end
        end)

        it("asks no question twice", function()
            local seen = {}
            for cat, questions in pairs(bank) do
                for i, q in ipairs(questions) do
                    local key = q.question:lower()
                    local prev = seen[key]
                    assert.is_nil(prev, "duplicate question in " .. cat .. " #" .. i
                        .. ", first seen in " .. tostring(prev) .. ": " .. q.question)
                    seen[key] = cat
                end
            end
        end)

        it("leaves no category empty", function()
            for cat, questions in pairs(bank) do
                assert.is_true(#questions > 0, "category " .. cat .. " is empty")
            end
        end)
    end)
end

-- Content guidelines: no figure known mainly for genocide, terrorism, mass
-- murder or dictatorship, no serial killers, family-friendly wording.
-- The French bank predates the guidelines; its few such questions were
-- removed in 1.4.0 and this keeps them out.
describe("French bank content", function()
    local EXCLUDED = {
        "hitler", "staline", "mussolini", "pol pot", "laden", "saddam",
        "kadhafi", "idi amin", "pinochet", "mao zedong", "kim jong", "himmler",
        "goebbels", "ceausescu", "ceaușescu", "gengis", "éventreur",
    }

    it("names no excluded figure", function()
        local bank = loadBank("fr")
        for cat, questions in pairs(bank) do
            for i, q in ipairs(questions) do
                local text = (q.question .. " " .. q.answer):lower()
                for _, name in ipairs(EXCLUDED) do
                    assert.is_nil(text:find(name, 1, true),
                        cat .. " #" .. i .. " mentions " .. name .. ": " .. q.question)
                end
            end
        end
    end)
end)

describe("English bank content", function()
    local EXCLUDED = {
        "hitler", "nazi", "stalin", "mussolini", "pol pot", "laden", "saddam",
        "gaddafi", "idi amin", "pinochet", "mao zedong", "kim jong", "himmler",
        "goebbels", "ceausescu", "ceaușescu", "genghis", "jack the ripper",
        "dahmer", "bundy", "porn", "cocaine", "suicide", "terroris",
    }
    local EXCLUDED_WORDS = { "sex", "sexy", "rape", "heroin", "drunk", "nude", "naked" }

    it("names no excluded figure and stays family-friendly", function()
        local bank = loadBank("en")
        for cat, questions in pairs(bank) do
            for i, q in ipairs(questions) do
                local text = (q.question .. " " .. q.answer):lower()
                for _, name in ipairs(EXCLUDED) do
                    assert.is_nil(text:find(name, 1, true),
                        cat .. " #" .. i .. " mentions " .. name .. ": " .. q.question)
                end
                for word in text:gmatch("%a+") do
                    for _, bad in ipairs(EXCLUDED_WORDS) do
                        assert.are_not.equal(bad, word,
                            cat .. " #" .. i .. " uses \"" .. bad .. "\": " .. q.question)
                    end
                end
            end
        end
    end)
end)

describe("QuizBank.load", function()
    local tmp

    local function write(path, text)
        local f = assert(io.open(path, "w"))
        f:write(text)
        f:close()
    end

    -- A stand-in for KOReader's json module: enough to tell the files apart.
    local function fakeDecode(s)
        local question = s:match('"question"%s*:%s*"([^"]*)"')
        if not question then return nil end
        return { { question = question, answer = "x" } }
    end

    before_each(function()
        tmp = os.tmpname()
        os.remove(tmp)
        assert(os.execute("mkdir -p '" .. tmp .. "'"))
    end)

    after_each(function()
        os.execute("rm -rf '" .. tmp .. "'")
    end)

    it("loads the bundled English bank when the documents folder has nothing", function()
        local data, is_lua, path = QuizBank.load(tmp, DIR, "en", fakeDecode)
        assert.is_table(data)
        assert.is_true(is_lua)
        assert.are.equal(DIR .. "quiz_questions_en.lua", path)
        assert.is_table(data["Geography: Countries"])
    end)

    it("loads the bundled French bank for fr", function()
        local data, is_lua, path = QuizBank.load(tmp, DIR, "fr", fakeDecode)
        assert.is_true(is_lua)
        assert.are.equal(DIR .. "quiz_questions_fr.lua", path)
        assert.is_table(data["Sports"])
    end)

    it("prefers the player's own JSON file over the bundled bank", function()
        write(tmp .. "/quiz_questions_en.json", '[{"question": "mine", "answer": "x"}]')
        local data, is_lua, path = QuizBank.load(tmp, DIR, "en", fakeDecode)
        assert.is_false(is_lua)
        assert.are.equal(tmp .. "/quiz_questions_en.json", path)
        assert.are.equal("mine", data[1].question)
    end)

    it("prefers the generic quiz_questions.json over the bundled bank too", function()
        write(tmp .. "/quiz_questions.json", '[{"question": "generic", "answer": "x"}]')
        local _, is_lua, path = QuizBank.load(tmp, DIR, "en", fakeDecode)
        assert.is_false(is_lua)
        assert.are.equal(tmp .. "/quiz_questions.json", path)
    end)

    it("prefers the per-language JSON over the generic one", function()
        write(tmp .. "/quiz_questions.json", '[{"question": "generic", "answer": "x"}]')
        write(tmp .. "/quiz_questions_en.json", '[{"question": "english", "answer": "x"}]')
        local data = QuizBank.load(tmp, DIR, "en", fakeDecode)
        assert.are.equal("english", data[1].question)
    end)

    it("prefers a Lua bank in documents over everything else", function()
        write(tmp .. "/quiz_questions_en.lua",
            'return { Mine = { { question = "q", answer = "a", category = "Mine" } } }')
        write(tmp .. "/quiz_questions_en.json", '[{"question": "english", "answer": "x"}]')
        local data, is_lua, path = QuizBank.load(tmp, DIR, "en", fakeDecode)
        assert.is_true(is_lua)
        assert.are.equal(tmp .. "/quiz_questions_en.lua", path)
        assert.is_table(data.Mine)
    end)

    it("skips a user file that does not parse and falls back to the bundled bank", function()
        write(tmp .. "/quiz_questions_en.json", "not json")
        write(tmp .. "/quiz_questions_en.lua", "this is not lua (")
        local _, is_lua, path = QuizBank.load(tmp, DIR, "en", fakeDecode)
        assert.is_true(is_lua)
        assert.are.equal(DIR .. "quiz_questions_en.lua", path)
    end)

    it("returns nil for a language with no bank anywhere", function()
        assert.is_nil(QuizBank.load(tmp, tmp .. "/", "xx", fakeDecode))
    end)
end)

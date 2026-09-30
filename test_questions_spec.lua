-- The bundled question bank is 3,000+ hand-written entries, and the loader in
-- screen.lua (_tryLoadLua) only type-checks the *first* pair it sees. A single
-- malformed entry further down therefore loads fine and only blows up when the
-- player happens to draw it, mid-game. These tests read the whole bank.
local DIR = debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])") or "./"

package.path = DIR .. "?.lua;" .. package.path

describe("quiz question bank", function()
    local bank

    setup(function()
        bank = require("quiz_questions_fr")
    end)

    it("is a category-keyed dict, the shape _filterByCategory expects", function()
        assert.is_table(bank)
        local categories = 0
        for key, questions in pairs(bank) do
            assert.is_string(key)
            assert.is_table(questions)
            categories = categories + 1
        end
        assert.is_true(categories > 0)
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

    it("gives every question a non-empty question and answer", function()
        for cat, questions in pairs(bank) do
            for i, q in ipairs(questions) do
                local where = cat .. " #" .. i
                assert.is_table(q, where .. " is not a table")
                assert.is_string(q.question, where .. " has no question")
                assert.is_string(q.answer, where .. " has no answer")
                assert.is_true(#q.question > 0, where .. " has an empty question")
                assert.is_true(#q.answer > 0, where .. " has an empty answer")
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

    it("uses one difficulty vocabulary throughout", function()
        local allowed = { facile = true, moyen = true, difficile = true }
        for cat, questions in pairs(bank) do
            for i, q in ipairs(questions) do
                assert.is_true(allowed[q.difficulty] == true,
                    cat .. " #" .. i .. " has difficulty " .. tostring(q.difficulty))
            end
        end
    end)

    it("asks no question twice", function()
        local seen = {}
        for cat, questions in pairs(bank) do
            for i, q in ipairs(questions) do
                local prev = seen[q.question]
                assert.is_nil(prev, "duplicate question in " .. cat .. " #" .. i
                    .. ", first seen in " .. tostring(prev) .. ": " .. q.question)
                seen[q.question] = cat
            end
        end
    end)

    it("leaves no category empty", function()
        for cat, questions in pairs(bank) do
            assert.is_true(#questions > 0, "category " .. cat .. " is empty")
        end
    end)
end)

-- The bundled question banks: every entry well-formed, a difficulty 1..5,
-- no question twice, and enough at every level for the Double ladder.
-- The counts per level and per category are printed, so a run shows what
-- the bank holds.
local DIR = debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])") or "./"

package.path = DIR .. "?.lua;" .. package.path

local Deck = require("double_deck")

-- Figures the content guidelines keep out of a family party game.
local EXCLUDED = { "hitler", "staline", "stalin", "mussolini", "pol pot", "ben laden", "bin laden" }

local function fold(s)
    return (s:lower():gsub("[%s%p]", ""))
end

for _, lang in ipairs({ "fr", "en" }) do
    describe("double_questions_" .. lang .. ".lua", function()
        local path = DIR .. "double_questions_" .. lang .. ".lua"
        local bank

        setup(function()
            bank = assert(loadfile(path))()
        end)

        it("stays light enough for a 256 MB reader (< 400 KB)", function()
            local f = assert(io.open(path, "rb"))
            local size = f:seek("end")
            f:close()
            assert.is_true(size < 400 * 1024, size .. " bytes")
        end)

        it("has well-formed entries with a level 1..5", function()
            for _, group in ipairs(bank) do
                assert.are.equal("string", type(group.cat))
                assert.is_true(#group.cat > 0)
                for i, e in ipairs(group.q) do
                    local where = group.cat .. " #" .. i
                    assert.are.equal("number", type(e[1]), where)
                    assert.is_true(e[1] >= 1 and e[1] <= 5 and e[1] % 1 == 0, where .. " level " .. tostring(e[1]))
                    assert.are.equal("string", type(e[2]), where)
                    assert.are.equal("string", type(e[3]), where)
                    assert.is_true(#e[2] >= 8, where .. " question too short")
                    -- a question, or a saying to complete ("... »", "...\"")
                    local ends = e[2]:match("[%?%.\"]$") or e[2]:match("»$") or e[2]:match("…$")
                    assert.is_truthy(ends, where .. " odd ending: " .. e[2])
                    assert.is_true(#e[3] >= 1 and #e[3] <= 60, where .. " answer length: " .. e[3])
                    assert.is_true(e[4] == nil or (type(e[4]) == "string" and #e[4] > 0), where .. " alt")
                    assert.is_nil(e[5], where .. " stray field")
                end
            end
        end)

        it("never asks the same question twice", function()
            local seen = {}
            for _, group in ipairs(bank) do
                for i, e in ipairs(group.q) do
                    local k = fold(e[2])
                    assert.is_nil(seen[k], group.cat .. " #" .. i .. " duplicates " .. tostring(seen[k]))
                    seen[k] = group.cat .. " #" .. i
                end
            end
        end)

        it("names nobody the content guidelines exclude", function()
            for _, group in ipairs(bank) do
                for _, e in ipairs(group.q) do
                    local text = (e[2] .. " " .. e[3] .. " " .. (e[4] or "")):lower()
                    for _, name in ipairs(EXCLUDED) do
                        assert.is_falsy(text:find(name, 1, true), e[2])
                    end
                end
            end
        end)

        it("holds ~600 questions, spread over every level and category", function()
            local list = Deck.normalize(bank)
            local per_level, per_cat = { 0, 0, 0, 0, 0 }, {}
            for _, q in ipairs(list) do
                per_level[q.level] = per_level[q.level] + 1
                per_cat[q.category] = per_cat[q.category] or { 0, 0, 0, 0, 0 }
                per_cat[q.category][q.level] = per_cat[q.category][q.level] + 1
            end
            print(string.format("\n%s: %d questions, levels 1-5: %d %d %d %d %d", lang, #list,
                per_level[1], per_level[2], per_level[3], per_level[4], per_level[5]))
            for _, cat in ipairs(Deck.categories(list)) do
                local c = per_cat[cat]
                print(string.format("  %-26s %3d  (%d %d %d %d %d)", cat, c[1] + c[2] + c[3] + c[4] + c[5],
                    c[1], c[2], c[3], c[4], c[5]))
                for l = 1, 5 do
                    assert.is_true(c[l] > 0, cat .. " has no level " .. l)
                end
            end
            assert.is_true(#list >= 550, #list .. " questions")
            for l = 1, 5 do
                assert.is_true(per_level[l] >= #list / 10, "level " .. l .. " too thin: " .. per_level[l])
            end
            assert.is_true(#Deck.categories(list) >= 10)
        end)
    end)
end

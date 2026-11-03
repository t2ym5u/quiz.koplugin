-- Where the questions for a language come from, and loading them.
--
-- Pure Lua, no UI, so the specs can run it without KOReader.
--
-- A file in KOReader's data ("documents") folder always wins over the bundled
-- bank, so a player can replace the shipped questions with their own:
--   1. <docs>/quiz_questions_<lang>.lua    category-keyed dict (like the bundled bank)
--   2. <docs>/quiz_questions_<lang>.json   flat array of {question, answer, category}
--   3. <docs>/quiz_questions.json          same, for any language
--   4. <plugin>/quiz_questions_<lang>.lua  the bundled bank (fr, en)
--   5. <plugin>/quiz_questions_<lang>.json, <plugin>/quiz_questions.json
--
-- Banks are read with loadfile, not require, so they are not pinned in
-- package.loaded: switching language lets the previous bank be collected
-- (the bundled banks are a few hundred KB each; Kobo Aura has 256 MB).

local QuizBank = {}

function QuizBank.sources(docs, dir, lang)
    return {
        { path = docs .. "/quiz_questions_" .. lang .. ".lua",  kind = "lua"  },
        { path = docs .. "/quiz_questions_" .. lang .. ".json", kind = "json" },
        { path = docs .. "/quiz_questions.json",                kind = "json" },
        { path = dir  .. "quiz_questions_" .. lang .. ".lua",   kind = "lua"  },
        { path = dir  .. "quiz_questions_" .. lang .. ".json",  kind = "json" },
        { path = dir  .. "quiz_questions.json",                 kind = "json" },
    }
end

-- A category-keyed dict {category = {question, ...}, ...}, or nil.
function QuizBank.loadLua(path)
    local f = io.open(path, "r")
    if not f then return nil end
    f:close()
    local chunk = loadfile(path)
    if not chunk then return nil end
    local ok, data = pcall(chunk)
    if not ok or type(data) ~= "table" then return nil end
    -- Verify it is a category-keyed dict (not a flat array)
    for k, v in pairs(data) do
        if type(k) ~= "string" or type(v) ~= "table" then return nil end
        break
    end
    return data
end

-- A non-empty flat array of questions, or nil.
function QuizBank.loadJson(path, json_decode)
    if not json_decode then return nil end
    local f = io.open(path, "r")
    if not f then return nil end
    local content = f:read("*all")
    f:close()
    local data = json_decode(content)
    if type(data) == "table" and #data > 0 then return data end
    return nil
end

-- First source that loads: data, is_lua (dict) or false (flat array), path.
-- Returns nil when nothing loads.
function QuizBank.load(docs, dir, lang, json_decode)
    for _i, src in ipairs(QuizBank.sources(docs, dir, lang)) do
        if src.kind == "lua" then
            local data = QuizBank.loadLua(src.path)
            if data then return data, true, src.path end
        else
            local data = QuizBank.loadJson(src.path, json_decode)
            if data then return data, false, src.path end
        end
    end
    return nil
end

return QuizBank

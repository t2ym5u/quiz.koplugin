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

-- ---------------------------------------------------------------------------
-- Across sessions: questions already shown are remembered (game-common
-- seen_history, one history per question language) so the next evening
-- starts with questions not seen yet instead of the same random openers.
-- ---------------------------------------------------------------------------

-- Ids are kept in the plugin settings, flushed at every question: a short
-- hash of the question text (8 hex digits) instead of the text itself keeps
-- 4,000 of them around 50 KB. Works for a user's own file too. A collision
-- (about 1 in 1,000 for a 3,000-question bank) only means one question counts
-- as seen a little early.
function QuizBank.questionId(q)
    local s = type(q) == "table" and (q.question or q.q) or q
    if type(s) ~= "string" then return nil end
    local h = 5381
    for i = 1, #s do
        h = (h * 33 + s:byte(i)) % 4294967296
    end
    return string.format("%08x", h)
end

-- Remembers up to 4,000 questions per language: the whole bundled French
-- bank (3,194) plus the 600 rated questions of the "Double or nothing" rule
-- of Quiz · multiplayer, which shares this history (so a question asked
-- under one rule does not come back under the other), and more than twice
-- the English one; a full cycle goes by before any question is shown again.
QuizBank.HISTORY_MAX = 4000

function QuizBank.openHistory(plugin, lang)
    local SeenHistory = require("seen_history")
    return SeenHistory.open(plugin, "questions_" .. lang,
        { max = QuizBank.HISTORY_MAX, id_of = QuizBank.questionId })
end

local function shuffle(t, rng)
    for i = #t, 2, -1 do
        local j = rng(i)
        t[i], t[j] = t[j], t[i]
    end
    return t
end

-- Reorders `list` in place: questions not seen yet first, then the ones seen
-- in earlier sessions, each part shuffled. Nothing is marked here (the screen
-- marks a question when it is shown). When every question of `list` has been
-- seen, their history is forgotten and a new random cycle starts.
function QuizBank.order(seen, list, rng)
    rng = rng or math.random
    if not seen then return shuffle(list, rng) end
    local fresh, old = {}, {}
    for _i, q in ipairs(list) do
        if seen:has(q) then old[#old + 1] = q else fresh[#fresh + 1] = q end
    end
    if #fresh == 0 then
        seen:forgetPool(list)
        fresh, old = old, {}
    end
    shuffle(fresh, rng)
    shuffle(old, rng)
    for i = 1, #fresh do list[i] = fresh[i] end
    for i = 1, #old do list[#fresh + i] = old[i] end
    return list
end

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

-- The question deck of the "Double or nothing" rule (Quiz · multiplayer,
-- formerly the Double or Nothing plugin's deck.lua): what the next question
-- is, at which difficulty, and never the same one twice until the whole
-- deck has been played; across sessions, questions not seen yet come first.
--
-- Pure Lua, no UI, so it can be tested without KOReader. Questions come in
-- three shapes:
--   * the rated banks (double_questions_fr.lua / double_questions_en.lua),
--     grouped by category, every question rated 1..5:
--       { { cat = "Sport", q = { { level, question, answer, alt? }, ... } }, ... }
--   * a player's own Double-or-nothing JSON file, a flat list of objects:
--       { question = ..., answer = ..., category = ..., difficulty = 1..5, alt = ... }
--   * the Quiz bank (quiz_questions_<lang>.lua, or the player's own quiz
--     file, see quiz_bank.lua), whose difficulty is a word: Deck.fromQuiz()
--     maps easy/facile -> 2, medium/moyen -> 3, hard/difficile -> 4, so the
--     ends of the ladder (1 and 5) stay the hand-rated questions.
-- Deck.normalize() / Deck.fromQuiz() turn them into one flat list of
--   { question, answer, category, level, rated, alt }.

local Deck = {}
Deck.__index = Deck

Deck.MIN_LEVEL = 1
Deck.MAX_LEVEL = 5
-- A question with no usable difficulty sits in the middle of the range, so a
-- user deck without levels still plays (every draw falls back to level 3).
Deck.DEFAULT_LEVEL = 3

-- Words a player's own Double-or-nothing file may use (the whole 1..5 range).
local WORD_LEVELS = {
    easy = 1, facile = 1,
    medium = 3, moyen = 3, normal = 3,
    hard = 5, difficile = 5,
}

-- The Quiz bank's three difficulties, placed inside the ladder.
Deck.QUIZ_LEVELS = {
    easy = 2, facile = 2,
    medium = 3, moyen = 3, normal = 3,
    hard = 4, difficile = 4,
}

-- 1..5 from a number, a numeric string or an easy/medium/hard word.
function Deck.parseLevel(v, words)
    if type(v) == "string" then
        v = tonumber(v) or (words or WORD_LEVELS)[v:lower()]
    end
    if type(v) ~= "number" then return Deck.DEFAULT_LEVEL end
    v = math.floor(v + 0.5)
    if v < Deck.MIN_LEVEL then return Deck.MIN_LEVEL end
    if v > Deck.MAX_LEVEL then return Deck.MAX_LEVEL end
    return v
end

local function nonEmpty(s)
    if type(s) == "number" then s = tostring(s) end
    if type(s) ~= "string" then return nil end
    s = s:match("^%s*(.-)%s*$")
    if s == "" then return nil end
    return s
end

local function addEntry(out, question, answer, category, level, alt, words)
    question, answer = nonEmpty(question), nonEmpty(answer)
    if not question or not answer then return end
    out[#out + 1] = {
        question = question,
        answer   = answer,
        category = nonEmpty(category),
        level    = Deck.parseLevel(level, words),
        -- false when the file gave no difficulty: the level is then only the
        -- default and the card does not claim one
        rated    = level ~= nil and level ~= "",
        alt      = nonEmpty(alt),
    }
end

-- Flatten a rated bank or a user JSON list into question records.
-- Malformed entries are skipped rather than failing the whole file.
function Deck.normalize(data)
    local out = {}
    if type(data) ~= "table" then return out end
    for _, item in ipairs(data) do
        if type(item) == "table" then
            if type(item.q) == "table" then
                for _, e in ipairs(item.q) do
                    if type(e) == "table" then
                        addEntry(out, e[2], e[3], item.cat, e[1], e[4])
                    end
                end
            else
                addEntry(out, item.question, item.answer, item.category,
                    item.difficulty or item.level, item.alt)
            end
        end
    end
    return out
end

-- Flatten Quiz questions (QuizBank.load's data: a category-keyed dict when
-- is_dict, else a flat array) with their difficulty mapped by QUIZ_LEVELS.
-- Categories are visited in sorted order so the result does not depend on
-- pairs().
function Deck.fromQuiz(data, is_dict)
    local out = {}
    if type(data) ~= "table" then return out end
    local function add(q, cat)
        if type(q) == "table" then
            addEntry(out, q.question or q.q, q.answer or q.a, q.category or q.cat or cat,
                q.difficulty or q.level, q.alt, Deck.QUIZ_LEVELS)
        end
    end
    if is_dict then
        local cats = {}
        for cat, list in pairs(data) do
            if type(cat) == "string" and type(list) == "table" then cats[#cats + 1] = cat end
        end
        table.sort(cats)
        for _i, cat in ipairs(cats) do
            for _j, q in ipairs(data[cat]) do add(q, cat) end
        end
    else
        for _i, q in ipairs(data) do add(q) end
    end
    return out
end

-- `first`, then the entries of `more` whose question is not already there
-- (the same question in both banks is played once, as the first one rates it).
function Deck.merge(first, more)
    local out, have = {}, {}
    for _i, list in ipairs({ first or {}, more or {} }) do
        for _j, q in ipairs(list) do
            local k = Deck.key(q)
            if not have[k] then
                have[k] = true
                out[#out + 1] = q
            end
        end
    end
    return out
end

-- Sorted list of the distinct categories in a normalized list.
function Deck.categories(list)
    local seen, cats = {}, {}
    for _, q in ipairs(list) do
        if q.category and not seen[q.category] then
            seen[q.category] = true
            cats[#cats + 1] = q.category
        end
    end
    table.sort(cats)
    return cats
end

-- A question's identity for the no-repeat rule within a session: its text,
-- so a question that survives a reload or a category change is still
-- recognised as already played. (Across sessions, the shared Quiz history
-- keys questions by QuizBank.questionId, a hash of the same text.)
function Deck.key(q)
    return q.question
end

-- ---------------------------------------------------------------------------
-- Where the questions come from (see double_screen.lua):
--   1. the player's own Double-or-nothing file in the documents folder, which
--      replaces everything else:
--        quiz_double_<lang>.json, quiz_double.json, and -- so a file made for
--        the Double or Nothing plugin keeps working -- its old names
--        doubleornothing_questions_<lang>.json, doubleornothing_questions.json
--   2. otherwise the rated bank double_questions_<lang>.lua, plus the Quiz
--      questions (QuizBank.load: the player's own quiz file, else the
--      bundled Quiz bank) at their mapped level.
-- ---------------------------------------------------------------------------

function Deck.userFiles(docs, lang)
    return {
        docs .. "/quiz_double_" .. lang .. ".json",
        docs .. "/quiz_double.json",
        docs .. "/doubleornothing_questions_" .. lang .. ".json",
        docs .. "/doubleornothing_questions.json",
    }
end

-- The first user file that holds at least one question, normalized, and its
-- path; nil when there is none.
function Deck.loadUserFile(docs, lang, json_decode)
    if not json_decode then return nil end
    for _i, path in ipairs(Deck.userFiles(docs, lang)) do
        local f = io.open(path, "r")
        if f then
            local content = f:read("*all")
            f:close()
            local list = Deck.normalize(json_decode(content))
            if #list > 0 then return list, path end
        end
    end
    return nil
end

-- The rated bank shipped in `dir` for `lang` (English when there is none),
-- normalized. Read with loadfile, not require, so it is not pinned in
-- package.loaded.
function Deck.loadRated(dir, lang)
    for _i, l in ipairs({ lang, "en" }) do
        local chunk = loadfile(dir .. "double_questions_" .. l .. ".lua")
        if chunk then
            local ok, data = pcall(chunk)
            if ok and type(data) == "table" then return Deck.normalize(data) end
        end
    end
    return {}
end

-- The whole pool for `lang`: { list, user_path or nil }.
-- quiz_bank: the QuizBank module (passed in so this file stays standalone).
function Deck.loadPool(docs, dir, lang, json_decode, quiz_bank)
    local own, path = Deck.loadUserFile(docs, lang, json_decode)
    if own then return own, path end
    local rated = Deck.loadRated(dir, lang)
    local quiz = {}
    if quiz_bank then
        local data, is_dict = quiz_bank.load(docs, dir, lang, json_decode)
        quiz = Deck.fromQuiz(data, is_dict)
    end
    return Deck.merge(rated, quiz), nil
end

-- ---------------------------------------------------------------------------
-- The deck
-- ---------------------------------------------------------------------------

-- opts.category : only questions of that category (nil = all)
-- opts.used     : shared { [key] = true } set of questions already played;
--                 pass the same table across rebuilds to keep the session's
--                 history when the category or the file changes
-- opts.seen     : a game-common SeenHistory (QuizBank.openHistory) that
--                 remembers questions across sessions; at a level, questions
--                 not seen in earlier sessions are drawn first
-- opts.random   : function(n) -> 1..n (default math.random), for tests
function Deck.new(list, opts)
    opts = opts or {}
    local self = setmetatable({
        random = opts.random or math.random,
        used   = opts.used or {},
        seen   = opts.seen,
        pools  = {},
        count  = 0,
    }, Deck)
    for l = Deck.MIN_LEVEL, Deck.MAX_LEVEL do self.pools[l] = {} end
    for _, q in ipairs(list or {}) do
        if not opts.category or q.category == opts.category then
            local pool = self.pools[Deck.parseLevel(q.level)]
            pool[#pool + 1] = q
            self.count = self.count + 1
        end
    end
    return self
end

function Deck:size()
    return self.count
end

-- Questions of this deck at `level` (all of them, played or not).
function Deck:levelSize(level)
    return #self.pools[level]
end

-- Questions of this deck not yet played (at `level`, or at any level).
function Deck:remaining(level)
    local n = 0
    for l = Deck.MIN_LEVEL, Deck.MAX_LEVEL do
        if not level or l == level then
            for _, q in ipairs(self.pools[l]) do
                if not self.used[Deck.key(q)] then n = n + 1 end
            end
        end
    end
    return n
end

function Deck:_pickUnused(level)
    local free = {}
    for _, q in ipairs(self.pools[level]) do
        if not self.used[Deck.key(q)] then free[#free + 1] = q end
    end
    if #free == 0 then return nil end
    -- The history prefers, among this level's questions not played this
    -- session, those not seen in earlier sessions either; once they have all
    -- been seen, it forgets them and they come back in a new random cycle.
    -- Staying at the asked level matters more than freshness: the ladder
    -- only moves to a neighbour level when this session used the level up.
    if self.seen then return self.seen:draw(free, 1, self.random)[1] end
    return free[self.random(#free)]
end

-- The nearest level that still has an unused question: the asked level
-- first, then one step harder, one step easier, two harder, ... A Double asks
-- for a harder question, so on a tie the harder side wins.
function Deck:_pickNear(level)
    for d = 0, Deck.MAX_LEVEL - Deck.MIN_LEVEL do
        for _, l in ipairs(d == 0 and { level } or { level + d, level - d }) do
            if l >= Deck.MIN_LEVEL and l <= Deck.MAX_LEVEL then
                local q = self:_pickUnused(l)
                if q then return q end
            end
        end
    end
    return nil
end

-- Draw a question at (or as near as possible to) `level` and mark it played.
-- Once every question of the deck has been played, the history of this
-- deck's questions is cleared and a new cycle starts. nil if the deck is empty.
function Deck:draw(level)
    if self.count == 0 then return nil end
    level = Deck.parseLevel(level)
    local q = self:_pickNear(level)
    if not q then
        for l = Deck.MIN_LEVEL, Deck.MAX_LEVEL do
            for _, p in ipairs(self.pools[l]) do self.used[Deck.key(p)] = nil end
        end
        q = self:_pickNear(level)
    end
    self.used[Deck.key(q)] = true
    return q
end

return Deck

-- quiz_migrate.lua — one-time import from doubleornothing.koplugin (Double
-- or Nothing, retired: it is now the "Double or nothing" rule of
-- Quiz · multiplayer). Pure Lua, no UI and no file access (main.lua reads
-- the files and writes the result), so the specs can run it.
--
-- Double or Nothing's settings file (settings/doubleornothing.lua) held:
--   lang                  "fr" | "en", the question language
--   duration              thinking timer: 0 (off), 15, 20, 30 or 45 seconds
--   nb_teams              2..6
--   team_name_<i>         team names (the plugin read them but never wrote
--                         them; kept in case a player edited the file)
--   category_<lang>       "all" or one category of that language's bank
--   seen_questions_<lang> question texts already asked (seen_history ids)
-- It never saved a match in progress (scores lived only while the screen was
-- open), so there is none to import.
--
-- Nothing already in the Quiz's settings is ever overwritten: each value is
-- imported only when the Quiz has none for it. The question histories are
-- merged (the Double or Nothing ones counted as older).

local QuizBank = require("quiz_bank")

local Migrate = {}

Migrate.SOURCE_ID = "doubleornothing"

local DURATIONS = { [0] = true, [15] = true, [20] = true, [30] = true, [45] = true }
local MIN_TEAMS, MAX_TEAMS = 2, 6

-- don: Double or Nothing's settings table (nil when the file does not exist).
-- get(key): the Quiz's current value for key, or nil.
-- Returns { key = value, ... } to write into the Quiz's settings (empty when
-- there is nothing to import).
function Migrate.settings(don, get)
    local out = {}
    if type(don) ~= "table" then return out end
    local function set(key, value)
        if value ~= nil and get(key) == nil then out[key] = value end
    end

    if don.lang == "fr" or don.lang == "en" then set("party_lang", don.lang) end

    local d = tonumber(don.duration)
    if d and DURATIONS[d] then set("party_double_duration", d) end

    local n = tonumber(don.nb_teams)
    if n and n == math.floor(n) and n >= MIN_TEAMS and n <= MAX_TEAMS then
        set("party_team_count", n)
    end

    local names, last = {}, 0
    for i = 1, MAX_TEAMS do
        local s = don["team_name_" .. i]
        if type(s) == "string" and s:match("%S") then
            names[i] = s; last = i
        end
    end
    if last > 0 then
        -- "" for a gap: party.lua shows the default "Team k" for it.
        for i = 1, last do names[i] = names[i] or "" end
        set("party_teams", names)
    end

    for _i, lang in ipairs({ "fr", "en" }) do
        local c = don["category_" .. lang]
        if type(c) == "string" and c ~= "" then set("party_double_category_" .. lang, c) end
        local merged = Migrate.history(don["seen_questions_" .. lang], get("seen_questions_" .. lang))
        if merged then out["seen_questions_" .. lang] = merged end
    end

    -- A Double or Nothing player opening Quiz · multiplayer for the first
    -- time finds the game they played there.
    if next(out) ~= nil or next(don) ~= nil then set("party_rule", "double") end
    return out
end

-- Double or Nothing's history (question texts) merged into the Quiz's
-- (QuizBank.questionId hashes): the imported ids first, as the older ones,
-- then the Quiz's own, at most QuizBank.HISTORY_MAX (the oldest dropped).
-- nil when there is nothing to add.
function Migrate.history(don_list, quiz_list)
    if type(don_list) ~= "table" then return nil end
    local have, ids = {}, {}
    if type(quiz_list) == "table" then
        for _i, id in ipairs(quiz_list) do have[tostring(id)] = true end
    end
    for _i, text in ipairs(don_list) do
        local id = QuizBank.questionId(tostring(text))
        if id and not have[id] then
            have[id] = true
            ids[#ids + 1] = id
        end
    end
    if #ids == 0 then return nil end
    if type(quiz_list) == "table" then
        for _i, id in ipairs(quiz_list) do ids[#ids + 1] = tostring(id) end
    end
    local extra = #ids - QuizBank.HISTORY_MAX
    if extra > 0 then
        local kept = {}
        for i = extra + 1, #ids do kept[#kept + 1] = ids[i] end
        ids = kept
    end
    return ids
end

-- Double or Nothing's row of the shared game_stats.lua folded into the
-- Quiz's: sessions and play time add up, the last-played times keep the
-- latest, and Double or Nothing's sessions count as multiplayer ones
-- (last_party_played, which Dashboard and "Recently played" read for the
-- "Quiz · multiplayer" entry). Returns the new Quiz row, or nil when there is
-- nothing to fold.
function Migrate.stats(quiz_row, don_row)
    if type(don_row) ~= "table" or not tonumber(don_row.sessions) then return nil end
    local q = type(quiz_row) == "table" and quiz_row or {}
    local out = {}
    for k, v in pairs(q) do out[k] = v end
    out.sessions    = (tonumber(q.sessions) or 0) + tonumber(don_row.sessions)
    out.time_played = (tonumber(q.time_played) or 0) + (tonumber(don_row.time_played) or 0)
    -- The Quiz's sessions so far were all played from the Quiz entry.
    if tonumber(q.last_played) and not q.last_solo_played then
        out.last_solo_played = q.last_played
    end
    local don_last  = tonumber(don_row.last_played)
    if don_last then
        out.last_played       = math.max(tonumber(q.last_played) or 0, don_last)
        out.last_party_played = math.max(tonumber(q.last_party_played) or 0, don_last)
    end
    return out
end

return Migrate

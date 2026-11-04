-- The "Double or nothing" rule of Quiz · multiplayer (formerly the Double or
-- Nothing plugin's round.lua, unchanged): how the pot grows, and whose turn
-- comes next.
--
-- Split out of double_screen.lua because these two rules are the whole game and were
-- otherwise only reachable through UIManager. The pot in particular doubles,
-- so a mistake here is not a rounding error -- it is off by a factor of two and
-- keeps doubling.

local Round = {}

-- What the pot is worth after the first correct answer of a turn.
Round.BASE_POT = 1

-- The pot after one more correct answer. A turn starts at 0; the first correct
-- answer is worth BASE_POT rather than nothing doubled.
function Round.nextPot(pot)
    if (pot or 0) == 0 then return Round.BASE_POT end
    return pot * 2
end

-- The pot a team would be sitting on after `n` correct answers in a row.
-- Useful to state the progression in one place rather than inferring it.
function Round.potAfter(n)
    if (n or 0) <= 0 then return 0 end
    return Round.BASE_POT * 2 ^ (n - 1)
end

-- Difficulty: a turn opens on an easy question and every Double climbs one
-- level, so the pot and the risk grow together.
Round.MAX_LEVEL = 5

-- The level of the first question of a turn: 1 or 2. `random` is
-- function(n) -> 1..n (math.random by default).
function Round.startLevel(random)
    return (random or math.random)(2)
end

-- The level of the question drawn on a Double: one step harder, capped.
function Round.nextLevel(level)
    return math.min(Round.MAX_LEVEL, (level or 0) + 1)
end

-- Whose turn it is after this one. Teams are numbered 1..count and wrap.
function Round.nextTeam(current, count)
    if (count or 0) < 1 then return 1 end
    return (current % count) + 1
end

return Round

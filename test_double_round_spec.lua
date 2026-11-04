-- The pot doubles, so an error here is never small: it is a factor of two that
-- compounds with every correct answer. The rest of the turn logic sits in
-- screen.lua behind UIManager; these are the two rules that decide the score.
local DIR = debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])") or "./"

package.path = DIR .. "?.lua;" .. package.path

describe("Round.nextPot", function()
    local Round

    setup(function()
        Round = require("double_round")
    end)

    it("is worth the base stake after the first correct answer", function()
        assert.are.equal(Round.BASE_POT, Round.nextPot(0))
    end)

    it("doubles from there", function()
        assert.are.equal(2, Round.nextPot(1))
        assert.are.equal(4, Round.nextPot(2))
        assert.are.equal(8, Round.nextPot(4))
    end)

    it("follows the 1 2 4 8 16 run a team actually plays", function()
        local pot, run = 0, {}
        for _ = 1, 6 do
            pot = Round.nextPot(pot)
            run[#run + 1] = pot
        end
        assert.are.same({ 1, 2, 4, 8, 16, 32 }, run)
    end)

    it("treats a missing pot as the start of a turn", function()
        assert.are.equal(Round.BASE_POT, Round.nextPot(nil))
    end)
end)

describe("Round.potAfter", function()
    local Round

    setup(function()
        Round = require("double_round")
    end)

    it("is nothing before the first correct answer", function()
        assert.are.equal(0, Round.potAfter(0))
        assert.are.equal(0, Round.potAfter(nil))
    end)

    it("agrees with stepping nextPot the same number of times", function()
        local pot = 0
        for n = 1, 10 do
            pot = Round.nextPot(pot)
            assert.are.equal(pot, Round.potAfter(n), "disagreement at " .. n)
        end
    end)
end)

describe("Round.nextTeam", function()
    local Round

    setup(function()
        Round = require("double_round")
    end)

    it("hands over to the next team", function()
        assert.are.equal(2, Round.nextTeam(1, 3))
        assert.are.equal(3, Round.nextTeam(2, 3))
    end)

    it("wraps back to the first team after the last", function()
        assert.are.equal(1, Round.nextTeam(3, 3))
        assert.are.equal(1, Round.nextTeam(2, 2))
    end)

    it("gives every team exactly one turn per cycle", function()
        for count = 1, 6 do
            local seen, team = {}, 1
            for _ = 1, count do
                assert.is_nil(seen[team], count .. " teams: " .. team .. " played twice")
                seen[team] = true
                team = Round.nextTeam(team, count)
            end
            assert.are.equal(1, team, count .. " teams: cycle did not close")
        end
    end)

    it("keeps a solo player on their own turn", function()
        assert.are.equal(1, Round.nextTeam(1, 1))
    end)

    it("does not divide by zero when there are no teams yet", function()
        assert.are.equal(1, Round.nextTeam(1, 0))
    end)
end)

describe("Round difficulty levels", function()
    local Round

    setup(function()
        Round = require("double_round")
    end)

    it("opens a turn on level 1 or 2", function()
        assert.are.equal(1, Round.startLevel(function() return 1 end))
        assert.are.equal(2, Round.startLevel(function() return 2 end))
        for _ = 1, 200 do
            local l = Round.startLevel()
            assert.is_true(l == 1 or l == 2, "start level " .. l)
        end
    end)

    it("climbs one level per Double", function()
        assert.are.equal(2, Round.nextLevel(1))
        assert.are.equal(3, Round.nextLevel(2))
        assert.are.equal(5, Round.nextLevel(4))
    end)

    it("is capped at level 5 however long the run", function()
        local level, run = 1, { 1 }
        for _ = 1, 6 do
            level = Round.nextLevel(level)
            run[#run + 1] = level
        end
        assert.are.same({ 1, 2, 3, 4, 5, 5, 5 }, run)
    end)
end)

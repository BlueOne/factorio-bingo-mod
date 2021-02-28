local Event = require("__stdlib__/stdlib/event/event")
local Board = require("src/Board")
local BoardCreator = require("src/BoardCreator")
local Gui = require('__stdlib__/stdlib/event/gui')
local table = require("__stdlib__/stdlib/utils/table")


local research_all_recipes = function(force)
    for _, tech in pairs(force.technologies) do
        if table.any(tech.effects,
            function(effect) return effect.type == "unlock-recipe" end) or #tech.effects == 0
        then
            tech.researched = true
        end
    end
end

-- TODO this is temporary. Come up with a better design.
-- Current design: Bingo starts on init, joining players are assigned to the board as active players.
local start_bingo = function()
    research_all_recipes(game.forces.player)
    local settings = {
        seed = game.surfaces["nauvis"].map_gen_settings.seed
    }
    local tasks = BoardCreator.roll_board(settings)
    local players = {}
    for _, p in pairs(game.players) do
        if p.force.name == "player" then
            table.insert(players, p)
        end
    end
    local board = Board.create(tasks, players, players)
    global.bingo_board = board
end


Event.on_init(function()
    start_bingo()
end)

Event.on_event(defines.events.on_player_joined_game, function(args)
    local player = game.players[args.player_index]
    if not global.bingo_board then start_bingo() end
    Board.add_player(global.bingo_board, player)
end)


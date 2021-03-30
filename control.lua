
local Event = require("__stdlib__/stdlib/event/event")
require("src/TaskImpl")

local Board = require("src/Board")
local BoardGenerator = require("src/BoardGenerator")
local BoardGui = require("src/BoardGui") --luacheck:ignore 211
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

local setup_spectator_force = function()
    if game.forces.spectator then return end
    local spectator_force = game.create_force("spectator")
    local player_force = game.forces.player
    spectator_force.set_friend("player", true)
    spectator_force.set_cease_fire("player", true)
    spectator_force.share_chart = true
    player_force.set_cease_fire("spectator", false)
    player_force.set_friend("spectator", true)
    player_force.share_chart = true
end


-- TODO this is temporary. Come up with a better design.
-- Current design: Bingo starts on init, joining players are assigned to the board as active players.
local start_bingo = function()
    setup_spectator_force()
    research_all_recipes(game.forces.player)
    local settings = {
        seed = game.surfaces["nauvis"].map_gen_settings.seed,
        generic_line = {6, 6, 6, "restriction", 8}
    }
    local tasks = BoardGenerator.roll_board(settings)
    local players = {}
    for _, p in pairs(game.players) do
        if p.force.name == "player" and p.connected then
            table.insert(players, p)
        end
    end
    local args = {
        task_names = tasks,
        n = 5,
        active_players = players,
    }
    if false then
        for i = 11, 25 do tasks[i] = nil end
        args.mode = "rows_only"
        args.n_rows = 2
    end

    local board = Board.create(args)

    global.bingo_board = board
end


Event.on_init(function()
    start_bingo()
end)

Event.on_event(defines.events.on_player_joined_game, function(args) --luacheck: ignore 212
    local player = game.players[args.player_index]
    if not global.bingo_board then
        start_bingo()
    end
    Board.add_active_player(global.bingo_board, player)
end)


local set_spectator = function(player, followed_player)
    if not game.forces.spectator then setup_spectator_force() end
    global.is_spectator = global.is_spectator or {}
    if global.is_spectator[player.index] then return end

    player.force = "spectator"

    if player.character then
        player.character.destroy()
    end
    player.set_controller{type=defines.controllers.spectator}
    player.spectator = true
    player.color = {0,0,0,0}

    Board.remove_player_from_all_boards(player, true)
    player.tag = "[Spectator]"
    -- TODO: set up following
    global.is_spectator[player.index] = true
end

local spectate_help = "Switch to spectator mode. "
for _, s in pairs({"spectate", "spec"}) do
    commands.add_command(s, spectate_help, function(args)
        local player = game.players[args.player_index]
        local name = args.parameter
        local followed_player
        if name and game.players[name] then
            followed_player = game.players[name]
        end
        set_spectator(player, followed_player)
    end)
end
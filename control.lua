
local Event = require("__stdlib__/stdlib/event/event")
require("src/TaskImpl")

local Board = require("src/Board")
local BoardGenerator = require("src/BoardGenerator")
local BoardGui = require("src/BoardGui") --luacheck:ignore 211
local table = require("__stdlib__/stdlib/utils/table")
local StartingItems = require("src/StartingItems")
local StartingInventory = require("src/StartingInventory")
local string = require('__stdlib__/stdlib/utils/string')



local function set_research(force)
    local techs_to_disable =
    {
      "physical-projectile-damage",
      "stronger-explosives",
      "refined-flammables",
      "energy-weapons-damage",
      "weapon-shooting-speed",
      "laser-shooting-speed",
      "follower-robot-count",
      "mining-productivity"
    }
    force.research_all_technologies()
    local tech = force.technologies
    for k, name in pairs (techs_to_disable) do
    for i = 1, 20 do
        local full_name = name.."-"..i
        if tech[full_name] then
            tech[full_name].researched = false
        end
    end
    end
    force.reset_technology_effects()
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

local function create_start_settings()
    local board_settings = {
        mode = "default",
        n_rows = 3,
        tasks_per_line = {5},
        n = 4
    }

    local preset = settings.global["bingo-start-preset"].value
    if preset ~= "unset" then
        if preset == "default" then
            table.insert(board_settings.tasks_per_line, "gather")
        end
        if preset == "large" then
            table.insert(board_settings.tasks_per_line, "gather")
            table.insert(board_settings.tasks_per_line, "restriction")
            board_settings.n = 5
        end
        if preset == "rows-only" then
            board_settings.mode = "rows_only"
            board_settings.n_rows = 3
        end
        if preset == "rows-only-large" then
            board_settings.mode = "rows_only"
            table.insert(board_settings.tasks_per_line, "gather")
            table.insert(board_settings.tasks_per_line, "restriction")
            board_settings.n = 6
            board_settings.n_rows = 4
        end
    else
        if settings.global["bingo-start-rows-only"].value == true then
            board_settings.mode = "rows_only"
        end
        if settings.global["bingo-start-enable-gather-tasks"].value == true then
            table.insert(board_settings.tasks_per_line, "gather")
        end
        if settings.global["bingo-start-enable-restriction-tasks"].value == true then
            table.insert(board_settings.tasks_per_line, "restriction")
        end
        if settings.global["bingo-start-columns-count"].value then
            board_settings.n = settings.global["bingo-start-columns-count"].value
        end
        if settings.global["bingo-start-rows-count"].value then
            board_settings.n_rows = settings.global["bingo-start-rows-count"].value
        end
    end

    for i = #board_settings.tasks_per_line, board_settings.n-1 do
        table.insert(board_settings.tasks_per_line, 2)
    end
    return board_settings
end


-- TODO this is temporary. Come up with a better design.
-- Current design: Bingo starts on init, joining players are assigned to the board as active players.
local start_bingo = function()
    local start_settings = create_start_settings()
    local mode = start_settings.mode
    local n_rows = start_settings.n_rows
    local tasks_per_line = start_settings.tasks_per_line
    local n = start_settings.n


    --remote.call("freeplay", "set_disable_crashsite", true)
    if not remote.interfaces["freeplay"] then error("The bingo mod only works in freeplay!") end
    remote.call("freeplay", "set_skip_intro", true)
    remote.call("freeplay", "set_disable_crashsite", true)
    remote.call("freeplay", "set_created_items", {
        ["submachine-gun"] = 1,
        ["firearm-magazine"] = 40,
        ["shotgun"] = 1,
        ["shotgun-shell"] = 20,
        ["construction-robot"] = 10,
    })
    remote.call("freeplay", "set_respawn_items", {
        ["submachine-gun"] = 1,
        ["firearm-magazine"] = 40,
        ["shotgun"] = 1,
        ["shotgun-shell"] = 20,
        ["construction-robot"] = 10,
    })

    setup_spectator_force()
    set_research(game.forces.player)
    StartingItems.create_starting_chest(game.surfaces.nauvis, {x=0, y=0})


    local generator_settings = {
        seed = game.surfaces["nauvis"].map_gen_settings.seed,
        tasks_per_line = tasks_per_line,
        mode = mode,
        n_rows = n_rows
    }
    local tasks = BoardGenerator.roll_board(generator_settings)
    local players = {}
    for _, p in pairs(game.players) do
        if p.force.name == "player" and p.connected then
            table.insert(players, p)
        end

        StartingInventory.give_respawn_equipment(p)
    end

    local bingo_settings = {
        task_names = tasks,
        n = n,
        n_rows = n_rows,
        mode = mode,
        active_players = players,
    }

    local board = Board.create(bingo_settings)

    global.bingo_board = board
end


Event.on_init(function()
    start_bingo()
end)


Event.on_event(defines.events.on_runtime_mod_setting_changed, function(args)
    if string.starts_with(args.setting, "bingo-start") and args.player_index then
        game.players[args.player_index].print("A bingo mod setting was changed, this has no effect after the board has been started!")
    end
end)


Event.on_event(defines.events.on_player_joined_game, function(args) --luacheck: ignore 212
    local player = game.players[args.player_index]
    if not global.bingo_board then
        start_bingo()
    end
    Board.add_active_player(global.bingo_board, player)
    StartingInventory.give_respawn_equipment(player)
end)

Event.on_event(defines.events.on_player_respawned, StartingInventory.on_player_respawned)


--[[
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
--]]

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
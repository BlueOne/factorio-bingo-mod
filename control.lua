
local Event = require("__stdlib__/stdlib/event/event")
require("src/TaskImpl")

local Board = require("src/Board")
local BoardGenerator = require("src/BoardGenerator")
local BoardGui = require("src/BoardGui") --luacheck:ignore 211
local table = require("__stdlib__/stdlib/utils/table")
local StartingItems = require("src/StartingItems")
local StartingInventory = require("src/StartingInventory")



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


-- TODO this is temporary. Come up with a better design.
-- Current design: Bingo starts on init, joining players are assigned to the board as active players.
local start_bingo = function()
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

    local mode = "rows_only"
    local n_rows = 3
    local tasks_per_line = {2, 2, "gather", 5}
    local n = #tasks_per_line

    local settings = {
        seed = game.surfaces["nauvis"].map_gen_settings.seed,
        tasks_per_line = tasks_per_line,
        mode = mode,
        n_rows = n_rows
    }
    local tasks = BoardGenerator.roll_board(settings)
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
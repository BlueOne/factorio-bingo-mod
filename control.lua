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
-- Current design: if started in mp then show start button to first player. if sp then start immediately.
local start_bingo = function()
    research_all_recipes(game.forces.player)
    global.bingo_started = true
    game.tick_paused = false
    local settings = {
        seed = game.surfaces["nauvis"].map_gen_settings.seed
    }
    local tasks = BoardCreator.roll_board(settings)
    for i, p in pairs(game.players) do
        if p.connected and p.force.name == "player" then
            Board.create(tasks, p)
        end
    end
end


Event.on_init(function()
    if #game.players == 0 then
        game.tick_paused = true
    else
        start_bingo()
    end
end)

Event.on_event(defines.events.on_player_joined_game, function(args)
    if global.bingo_started then return end
    local player = game.players[args.player_index]

    if game.is_multiplayer() then
        local screen = player.gui.screen
        if not screen.bingo_start_frame then
            local frame = screen.add{type="frame", name="bingo_start_frame", caption = "Bingo"}
            frame.add{type="button", name="start_bingo_button", caption="Start Bingo", style="menu_button_continue"}
        end
    else
        start_bingo()
    end
end)


Gui.on_click("start_bingo_button", function(_)
    for _, p in pairs(game.players) do
        if p.gui.screen.bingo_start_frame then
            p.gui.screen.bingo_start_frame.destroy()
        end
    end
    start_bingo()
end)


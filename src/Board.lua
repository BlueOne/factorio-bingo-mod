


local TaskPrototypes = require("TaskPrototypes")
local mod_gui = require("mod-gui")
local table = require('__stdlib__/stdlib/utils/table')
local Event = require('__stdlib__/stdlib/event/event')
local Gui = require('__stdlib__/stdlib/event/gui')
local CustomEvent = require("customEvent")
local Tasks = require("src/TaskRegistry")
local TaskImpl = require("src/TaskImpl")
local ModUtil = require("src/ModUtil")

-- Handles runtime game control and ui that isn't task specific. Task specific stuff is in the task prototypes.

-- Constraints:
--      Board contains at most one task of any name
--      Each player may be active in one board and only view the ui of one board.

local Board = {}

Board.g = {
    boards = {},
}


Board.on_load = function()
    Board.g = global.Board or Board.g
    -- load board
    for _, board in pairs(Board.g.boards) do
        -- load task
        for i, task in pairs(board.tasks) do
            local mt = {__index = TaskPrototypes.get(task.name)}
            setmetatable(task, mt)
            if TaskImpl[task.type].init then TaskImpl[task.type].init(task, true) end
            Tasks.add(task)
            TaskImpl.init_events(task.type)
        end
    end
end
Event.on_load(Board.on_load)

Board.on_init = function()
    global.Board = global.Board or Board.g
end
Event.on_init(Board.on_init)


Board.get_ui = function(player)
    local player_index = player
    if type(player_index) ~= type(1) then player_index = player.index end
    return table.find(Board.g.boards,
        function(b) return table.any(b.ui_players,
            function(p) return p.index == player_index end)
        end
    )
end

Board.add_player = function(board, player)
    if not ModUtil.table_contains(board.active_players, player) then
        table.insert(board.active_players, player)
    end
    Board.add_ui_player(board, player)
end

Board.add_ui_player = function(board, player)
    if not ModUtil.table_contains(board.ui_players, player) then
        table.insert(board.ui_players, player)
        Board.create_board_ui(board, player)
    end
end

Board.create = function(task_names, active_players, ui_players)
    if active_players then
        active_players = table.deepcopy(active_players)
    else
        active_players = {}
    end
    if ui_players then
        ui_players = table.deepcopy(ui_players)
    else
        ui_players = table.depcopy(active_players)
    end
    assert(#task_names == 25, "Task list for creation of board is not length 25.")
    local board = {
        tasks = {},
        won = false,
        active_players = active_players,
        ui_players = ui_players,
        flows = {}
    }
    table.insert(Board.g.boards, board)
    for i, name in pairs(task_names) do
        local prototype = TaskPrototypes.get(name)
        local task = {
            index = i,
            flows = {},
            done = false or prototype.done,
            name = name,
            data = {},
            board = board,
            force = game.forces.player
        }
        setmetatable(task, {__index = prototype})
        assert(TaskImpl[task.type], "Task Type not implemented: "..task.type)
        TaskImpl.init_events(task.type)
        Tasks.add(task)
        table.insert(board.tasks, task)
    end

    for _, player in pairs(board.ui_players) do
        Board.create_board_ui(board, player)
    end

    for i = 1, 25 do
        local task = board.tasks[i]
        if TaskImpl[task.type].init then TaskImpl[task.type].init(task) end
        for _, player in pairs(board.ui_players) do
            local flow = task.flows[player.index]
            if task.done then flow.parent.style = "dark_green_frame" else flow.parent.style = "inside_deep_frame" end
        end
    end
    return board
end

-- TODO: This is rudimentary for now. Styles need to be worked.
Board.create_board_ui = function(board, player)
    if type(player) == type(1) then player = game.players[player] end
    local button_flow = mod_gui.get_button_flow(player)
    if button_flow.bingo_hide_button then button_flow.bingo_hide_button.destroy() end
    -- TODO nicer button sprite (dice? timer?)
    button_flow.add{type="sprite-button", name="bingo_hide_button", sprite="technology/steel-axe"}

    --local frame_flow = mod_gui.get_frame_flow(player)
    local frame_flow = player.gui.screen
    if frame_flow.bingo_flow then frame_flow.bingo_flow.destroy() end
    local flow = frame_flow.add{type="frame", caption="Bingo!", name="bingo_flow", direction="vertical"}
        flow.location = {0, 60}

    board.flows[player.index] = flow

    local bingo_table = flow.add{type="table", name="bingo_table", column_count=5, vertical_centering=true, style="filter_slot_table", }
    bingo_table.style.cell_padding = 4

    for i = 1, 25 do
        local task = board.tasks[i]
        -- Flow inside the frame so that we can change the color of the frame without changing the dimension and alignments inside the flow.
        local task_ui = bingo_table.add{type="frame", name="bingo_task_"..i, direction="vertical", style="inside_deep_frame"}
        local task_flow = task_ui.add{type="flow", name="flow", direction="vertical"}
        task_flow.style.width = 94
        task_flow.style.height = 45
        task_ui.style.horizontal_align = "center"
        task_ui.style.vertical_align = "center"
        task_flow.style.horizontal_align = "center"
        task_flow.style.vertical_align = "center"

        task.flows[player.index] = task_flow
        TaskImpl[task.type].create_ui(task, player)
        if task.done then task.flows[player.index].parent.style = "dark_green_frame" else task.flows[player.index].parent.style = "inside_deep_frame" end
    end
end

Board.destroy_board_ui = function(player)
    local button_flow = mod_gui.get_button_flow(player)
    button_flow.bingo_hide_button.destroy()
    --local frame_flow = mod_gui.get_frame_flow(player)
    local frame_flow = player.gui.screen
    frame_flow.bingo_flow.destroy()
end

Board.task_finished = function(task, done)
    local board = task.board
    if board.won then return end
    if done == nil then done = true end
    task.done = done

    for _, player in pairs(board.ui_players) do
        if task.done then task.flows[player.index].parent.style = "dark_green_frame" else task.flows[player.index].parent.style = "inside_deep_frame" end
    end

    if done then
        if TaskImpl[task.type].finished then TaskImpl[task.type].finished(task) end

        -- Check for victory.
        local index = task.index
        local x = (index-1) % 5 + 1
        local row_start = index - x + 1
        local y = (row_start - 1) / 5 + 1
        local column_finished = true
        local row_finished = true
        for i = 0, 4 do
            local c = board.tasks[x + 5*i]
            local r = board.tasks[row_start + i]
            if not c or not c.done then column_finished = false end
            if not r or not r.done then row_finished = false end
        end
        local text = ""
        if column_finished then
            text = "Column "..x.." finished. Ingame time: "..util.formattime(game.tick)
        elseif row_finished then
            text = "Row "..y.." finished. Ingame time: "..util.formattime(game.tick)
        end
        if column_finished or row_finished then
            for _, player in pairs(board.ui_players) do
                board.flows[player.index].caption = "Bingo! "..text
            end
            game.print(text)
            board.won = true
            local player_string = ""
            for i = 1, 4 do
                if board.active_players[i] then
                    player_string = player_string..board.active_players[i].name
                end
                if board.active_players[i+1] and i ~= 4 then
                    player_string = player_string..", "
                end
            end
            if board.active_players[5] then player_string = player_string.." and more" end
            game.print("Players "..player_string.." finished the board!")
--            for _, t in pairs(board.tasks) do
--                if t.destroy then t.destroy(t, board) end
--                TaskEvent.remove_task(t)
--            end
        end
    end
end
Event.register(CustomEvent.on_task_finished, function(e) Board.task_finished(e.task, e.done) end)


Board.toggle_hide_ui = function(args)
    local player = game.players[args.player_index]
    --local element = args.element
    local board = Board.get_ui(player)
    local flow = board.flows[args.player_index]
    flow.visible = not flow.visible
end
Gui.on_click("bingo_hide_button", Board.toggle_hide_ui)


Board.on_configuration_changed = function()
    -- Rebuild ui
    for _, board in pairs(Board.g.boards) do
        for _, player in pairs(board.ui_players) do
            Board.destroy_board_ui(player)
            Board.create_board_ui(board, player)
        end
    end
end


Event.on_configuration_changed(Board.on_configuration_changed)

Event.register(define)

return Board
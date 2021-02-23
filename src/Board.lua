


local TaskPrototypes = require("src/TaskPrototypes")
local mod_gui = require("mod-gui")
local table = require('__stdlib__/stdlib/utils/table')
local Event = require('__stdlib__/stdlib/event/event')
local Gui = require('__stdlib__/stdlib/event/gui')
local CustomEvent = require("customEvent")
local TaskEvent = require("src/TaskEvent")


-- Handles runtime game control and ui that isn't task specific. Task specific stuff is in the task prototypes.

-- Constraints:
--      At most one board per player
--      Task names are unique per board

local Board = {}

Board.g = {
    player_boards = {},
}


Board.on_load = function()
    Board.g = global.Board or Board.g
    -- load board
    for _, board in pairs(Board.g.player_boards) do
        -- load task
        for i, task in pairs(board.tasks) do
            local mt = {__index = TaskPrototypes.get(task.name)}
            setmetatable(task, mt)
            task.init(task, board, true)
        end
    end
end
Event.on_load(Board.on_load)

Board.on_init = function()
    global.Board = global.Board or Board.g
end
Event.on_init(Board.on_init)


Board.get_board = function(player)
    if type(player) ~= type(1) then player = player.index end
    return Board.g.player_boards[player]
end

Board.create = function(task_names, player)
    if type(player) == type(1) then player = game.players[player] end
    assert(#task_names == 25, "Task list for creation of board is not length 25.")
    assert(Board.g.player_boards[player.index] == nil, "Attempting to create board for a player while a board already exists.")
    local board = {
        pid = player.index,
        tasks = {},
        player = player,
        won = false,
    }
    Board.g.player_boards[player.index] = board

    Board.create_board_ui(player)


    for i, name in pairs(task_names) do
        local prototype = TaskPrototypes.get(name)
        local task = {
            index = i,
            player = player,
            pid = player.index,
            flow = board.flow.bingo_table["bingo_task_"..i],
            done = false or prototype.done,
            name = name,
            data = {}
        }
        setmetatable(task, {__index = prototype})
        -- TODO use description, etc.
        --local title = task.flow.add{type="label", caption=task.title, name="title"}
        --title.style.horizontal_align = "center"
        --title.style.font_color = {r=255,g=200,b=105}
        --title.style.font = "default-large-semibold"
        task.init(task, board, false)
        table.insert(board.tasks, task)
        task.create_ui(task, board)
    end
    return board
end

-- TODO: doesn't create the ui of the tasks. Current order is create board ui -> init tasks -> create task ui and each step requires the previous ones.
-- TODO: This is very rudimentary for now. Styles need to be worked.
Board.create_board_ui = function(player)
    if type(player) == type(1) then player = game.players[player] end
    local button_flow = mod_gui.get_button_flow(player)
    if button_flow.bingo_hide_button then button_flow.bingo_hide_button.destroy() end
    -- TODO nicer button sprite (dice? timer?)
    button_flow.add{type="sprite-button", name="bingo_hide_button", sprite="technology/steel-axe"}

    local frame_flow = mod_gui.get_frame_flow(player)
    if frame_flow.bingo_flow then frame_flow.bingo_flow.destroy() end
    local flow = frame_flow.add{type="frame", caption="Bingo!", name="bingo_flow", style=mod_gui.frame_style, direction="vertical"}

    local board = Board.get_board(player)
    board.flow = flow

    local bingo_table = flow.add{type="table", name="bingo_table", column_count=5, vertical_centering=true, style="filter_slot_table", }
    bingo_table.style.cell_padding = 4

    for i = 1, 25 do
        local task_ui = bingo_table.add{type="frame", name="bingo_task_"..i, direction="vertical", style="inside_deep_frame"}
        task_ui.style.horizontal_align = "center"
        task_ui.style.vertical_align = "center"
        task_ui.style.maximal_width = 120
        task_ui.style.minimal_width = 120
        task_ui.style.maximal_height = 60
        task_ui.style.minimal_height = 60
    end
end

Board.destroy_board_ui = function(player)
    local button_flow = mod_gui.get_button_flow(player)
    button_flow.bingo_hide_button.destroy()
    local frame_flow = mod_gui.get_frame_flow(player)
    frame_flow.bingo_flow.destroy()
end

Board.task_finished = function(player, task, board, done)
    if board.won then return end
    if done == nil then done = true end
    task.done = done

    -- TODO: change task ui frame color or find some other way to signal task done/not done
    if done then
        if task.finished then task.finished(task, board) end

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
            if not c.done then column_finished = false end
            if not r.done then row_finished = false end
        end
        local text = ""
        if column_finished then text = "Column "..x.." finished. Ingame time: "..util.formattime(game.tick) end
        if row_finished then text = "Row "..y.." finished. Ingame time: "..util.formattime(game.tick) end
        if column_finished or row_finished then
            board.flow.caption = "Bingo! "..text
            game.print(text)
            board.won = true
            game.print("Player "..player.name.." finished the board. Congratulations!")
            for _, t in pairs(board.tasks) do
                if t.destroy then t.destroy(t, board) end
                TaskEvent.remove_task(t)
            end
        end
    end
end
Event.register(CustomEvent.on_task_finished, function(e) Board.task_finished(e.player, e.task, e.board, e.done) end)


Board.toggle_hide_ui = function(args)
    local player = game.players[args.player_index]
    --local element = args.element
    local board = Board.get_board(player)
    board.flow.visible = not board.flow.visible
end
Gui.on_click("bingo_hide_button", Board.toggle_hide_ui)


Board.on_configuration_changed = function()
    -- Rebuild ui
    for _, board in pairs(Board.g.player_boards) do
        local player = board.player
        Board.destroy_board_ui(player)
        Board.create_board_ui(player)
        for _, task in pairs(board.tasks) do
            task.flow = board.flow.bingo_table["bingo_task_"..task.index]
            task.create_ui(task, board)
        end
    end
end


Event.on_configuration_changed(Board.on_configuration_changed)


return Board
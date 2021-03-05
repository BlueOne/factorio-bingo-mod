

local Board = {}

package.loaded[...] = Board

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


Board.get_board = function(player)
    local player_index = player
    if type(player_index) ~= type(1) then player_index = player.index end
    return table.find(Board.g.boards,
        function(b) return table.any(b.ui_players,
            function(p) return p.index == player_index end)
        end
    )
end

Board.add_active_player = function(board, player)
    -- TODO notify tasks that a player is joining
    if not ModUtil.table_contains(board.active_players, player) then
        table.insert(board.active_players, player)
    end
    Board.subscribe_ui(board, player)
    Board.generate_team_name(board)
end


Board.remove_player_from_all_boards = function(player, keep_ui)
    for _, board in pairs(Board.g.boards) do
        Board.remove_active_player(board, player, keep_ui)
    end
end

Board.remove_active_player = function(board, player, keep_ui)
    -- TODO notify tasks that a player is not active anymore
    ModUtil.remove_all(board.active_players, function(p) return p == player end)
    if not keep_ui then
        Board.unsubscribe_ui(board, player)
    end
    Board.generate_team_name(board)
end

Board.generate_team_name = function(board)
    local team_name = ""
    for i = 1, 4 do
        if board.active_players[i] then
            team_name = team_name..board.active_players[i].name
        end
        if board.active_players[i+1] and i ~= 4 then
            team_name = team_name..", "
        end
    end
    if board.active_players[5] then team_name = team_name.." and more" end
    board.team_name = team_name

    for _, player in pairs(board.ui_players) do
        local flow = Board.get_flow(board, player)
        flow.caption = "Bingo. "..board.team_name
    end
end

Board.unsubscribe_ui = function(board, player)
    Board.destroy_board_ui(player)
    ModUtil.remove_all(board.ui_players, function(p) return p == player end)
end

Board.subscribe_ui = function(board, player)
    if not ModUtil.table_contains(board.ui_players, player) then
        table.insert(board.ui_players, player)
        Board.create_board_ui(board, player)
    end
end

Board.create = function(task_names, active_players, ui_players)
    assert(#task_names == 25, "Task list for creation of board is not length 25.")
    local board = {
        tasks = {},
        won = false,
        active_players = {},
        ui_players = {},
        flows = {},
        team_name = "",
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

    for _, player in pairs(active_players or {}) do
        Board.add_active_player(board, player)
    end
    for _, player in pairs(ui_players or {}) do
        Board.subscribe_ui(board, player)
    end

    for _, task in pairs(board.tasks) do
        if TaskImpl[task.type].init then TaskImpl[task.type].init(task) end
        for _, player in pairs(board.ui_players) do
            Board.update_task_ui_frame(task, player)
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
        Board.update_task_ui_frame(task, player)
    end
end

Board.update_task_ui_frame = function(task, player)
    local frame = Board.get_task_flow(task, player).parent
    if task.done then frame.style = "dark_green_frame" else frame.style = "inside_deep_frame" end
end

Board.destroy_board_ui = function(player)
    local button_flow = mod_gui.get_button_flow(player)
    button_flow.bingo_hide_button.destroy()
    --local frame_flow = mod_gui.get_frame_flow(player)
    local frame_flow = player.gui.screen
    frame_flow.bingo_flow.destroy()
end

Board.get_flow = function(board, player)
    return board.flows[player.index]
end

Board.get_board_of_task = function(task)
    return task.board
end

Board.get_task_flow = function(task, player)
    return task.flows[player.index]
end

Board.get_task = function(board, index)
    return board.tasks[index]
end

Board.task_finished = function(task, done)
    local board = task.board
    if board.won then return end
    if done == nil then done = true end
    task.done = done

    for _, player in pairs(board.ui_players) do
        Board.update_task_ui_frame(task, player)
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
                Board.get_flow(board, player).caption = "Bingo! "..text
            end
            game.print(text)
            board.won = true
            game.print(board.team_name.." finished the board!")
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
    local board = Board.get_board(player)
    local flow = Board.get_flow(board, player)
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

return Board
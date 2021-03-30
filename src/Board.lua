

local Board = {}

package.loaded[...] = Board

local table = require('__stdlib__/stdlib/utils/table')
local Event = require('__stdlib__/stdlib/event/event')
local ModUtil = require("src/ModUtil")
local Task = require("src/Task")


-- Constraints:
--      Board contains at most one task of any name
--      Each player may be active in one board.


global.Board = global.Board or {
    boards = {},
}


Board.cell_width = 100
Board.cell_height = 30



function Board.create(args)
    local task_names = args.task_names
    local active_players = args.active_players or {}
    if args.force then active_players = table.copy(args.force.players) end
    local force = args.force or game.forces.player
    local n = args.n or 5
    local n_rows = args.n_rows or n
    local n_cols = args.n_cols or n
    local mode = args.mode or "default"
    local auto_generate_team_name = args.auto_generate_team_name
    if auto_generate_team_name == nil then auto_generate_team_name = true end
    assert(#task_names == n_rows * n_cols, "Task list for creation of board is not length "..n_rows*n_cols)
    local board = {
        n_rows = n_rows,
        n_cols = n_cols,
        tasks = {},
        won = false,
        active_players = {},
        team_name = "",
        marked_line = nil,
        force = force,
        mode = mode,
        lines = nil,
        auto_generate_team_name = auto_generate_team_name
    }

    if board.mode == "default" or board.mode == "rows_only" then
        local lines = {}
        if board.mode == "default" then
            for i = 1, n_cols do
                local line_vertical = {}
                for j = 1, n_rows do
                    table.insert(line_vertical, i + (j-1)*5)
                end
                table.insert(lines, line_vertical)
            end
        end
        for i = 1, n_rows do
            local line_horizontal = {}
            for j = 1, n_cols do
                table.insert(line_horizontal, (i-1)*5 + j)
            end
            table.insert(lines, line_horizontal)
        end
        board.lines = lines
    end

    table.insert(global.Board.boards, board)
    for i, name in pairs(task_names) do
        local task = Task.create{name = name, index = i, board = board, force = force }
        table.insert(board.tasks, task)
    end

    Event.dispatch{
        name = Event.generate_event_name("on_bingo_board_created"),
        board = board
    }
    for i, task in pairs(board.tasks) do
        Task.init(task)
    end

    for _, player in pairs(active_players or {}) do
        Board.add_active_player(board, player)
    end

    return board
end

function Board.destroy(board)
    ModUtil.remove_all(global.Board.boards, function(b) return b == board end)
    for _, task in pairs(board.tasks) do
        Task.destroy(task)
    end

    Event.dispatch{
        name = Event.generate_event_name("on_bingo_board_ended"),
        board = board
    }
end


function Board.get_board(player)
    local player_index = player
    if type(player_index) ~= type(1) then player_index = player.index end
    return table.find(global.Board.boards,
        function(b) return table.any(b.active_players,
            function(p) return p.index == player_index end)
        end
    )
end

function Board.add_active_player(board, player)
    if ModUtil.contains(board.active_players, player) then
        return
    end

    table.insert(board.active_players, player)
    if board.auto_generate_team_name then
        Board.generate_team_name(board)
    end

    Event.dispatch{
        name = Event.generate_event_name("on_bingo_board_player_added"),
        player_index = player.index,
        board = board
    }

    Board.generate_team_name(board)
end

function Board.is_player_active(board, player)
    local active = ModUtil.contains(board.active_players, player)
    return active
end

function Board.get_active_players(board)
    return board.active_players
end

function Board.remove_player_from_all_boards(player)
    for _, board in pairs(global.Board.boards) do
        Board.remove_active_player(board, player)
    end
end

function Board.remove_active_player(board, player)
    ModUtil.remove_all(board.active_players, function(p) return p == player end)
    if board.auto_generate_team_name then
        Board.generate_team_name(board)
    end
    Event.dispatch{
        name = Event.generate_event_name("on_bingo_board_player_removed"),
        player_index = player.index,
        board = board,
    }
end

function Board.generate_team_name(board)
    local team_name = ""
    if board.active_players[1] then
        team_name = team_name .. board.active_players[1].name
    end
    local count = 3
    for i = 2, count do
        if board.active_players[i] then
            if table_size(board.active_players) > i then
                team_name = team_name .. ", "
            else
                team_name = team_name .. " and "
            end
            team_name = team_name .. board.active_players[i].name
        else
            break
        end
    end
    if board.active_players[count + 1] then
        if not board.active_players[count + 2] then
            team_name = team_name .. " and " .. board.active_players[count + 1].name
        else
            team_name = team_name .. " and more"
        end
    end

    Board.set_team_name(board, team_name)
end

function Board.set_team_name(board, team_name)
    board.team_name = team_name
    Event.dispatch{
        name = Event.generate_event_name("on_bingo_team_name_changed"),
        board = board,
        team_name = team_name,
    }
end


function Board.get_marked_line_index(board)
    return board.marked_line
end

function Board.set_marked_line_index(board, line_index)
    local old_index = board.marked_line
    if old_index ~= line_index then
        board.marked_line = line_index
        Event.dispatch{
            name = Event.generate_event_name("on_bingo_marked_line_changed"),
            new_line_index = line_index,
            old_line_index = old_index,
            board = board
        }
    end
end

function Board.get_lines(board)
    return board.lines
end

function Board.get_mode(board)
    return board.mode
end

function Board.get_task(board, index)
    return board.tasks[index]
end


function Board.is_task_done(task)
    return task.done
end

function Board.on_task_finished(args)
    local task = args.task
    local done = args.done
    local board = task.board
    if board.won then return end
    if done == nil then done = true end
    task.done = done

    if done then
        local won = false
        for line_index, line in pairs(board.lines) do
            if not won then
                local success = true
                for _, ind in pairs(line) do
                    if not board.tasks[ind].done then
                        success = false
                    end
                end

                if success then
                    won = true
                    board.won = true
                    Event.dispatch{
                        name = Event.generate_event_name("on_bingo_board_won"),
                        finished_line_index = line_index,
                        board = board
                    }
                    game.print("Bingo board finished! "..board.team_name or "")
                end
            end
        end
    end
end
Event.register(Event.generate_event_name("on_bingo_task_done"), Board.on_task_finished)


return Board
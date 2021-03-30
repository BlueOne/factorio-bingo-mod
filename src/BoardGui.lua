

local BoardGui = {}

package.loaded[...] = BoardGui

local mod_gui = require("mod-gui")
local table = require('__stdlib__/stdlib/utils/table')
local Event = require('__stdlib__/stdlib/event/event')
local Gui = require('__stdlib__/stdlib/event/gui')
local Board = require('src/Board')
local TaskGui = require("src/TaskGui")
local ModUtil = require("src/ModUtil")


global.BoardGui = global.BoardGui or {
    guis = {},
}



-- TODO: This is rudimentary for now. Styles need to be worked.
function BoardGui.create(player, args)
    local board = args.board or args
    local is_player_active = args.is_player_active
    local mode = args.mode or board.mode
    if mode == nil then mode = "default" end
    if is_player_active == nil then is_player_active = true end
    local lines = args.lines or Board.get_lines(board)

    local board_gui = {
        n_rows = board.n_rows,
        n_cols = board.n_cols,
        player = player,
        flow = nil,
        button_flow = nil,
        task_guis = {},
        board = board,
        marked_line_override = nil,
        is_player_active = is_player_active,
        mode = mode,
        lines = lines
    }
    global.BoardGui.guis[player.index] = board_gui

    if type(player) == type(1) then player = game.players[player] end
    local button_flow = mod_gui.get_button_flow(player)
    if button_flow.bingo_hide_button then button_flow.bingo_hide_button.destroy() end
    -- TODO nicer button sprite (dice? timer?)
    button_flow.add{type="sprite-button", name="bingo_hide_button", sprite="technology/steel-axe"}

    --local frame_flow = mod_gui.get_frame_flow(player)
    local frame_flow = player.gui.screen
    if frame_flow.bingo_flow then frame_flow.bingo_flow.destroy() end
    local flow = frame_flow.add{type="frame", caption="Bingo!", name="bingo_flow", direction="vertical"}
    if board_gui.mode == "rows_only" then flow.caption = "Tasks" end
    flow.location = {0, 60}


    board_gui.flow = flow
    board_gui.button_flow = button_flow

    local bingo_table = flow.add{type="table", name="bingo_table", column_count=board_gui.n_cols + 1, vertical_centering=true, horizontal_centering=true, style="filter_slot_table", }
    bingo_table.style.cell_padding = 0

    local team_label = flow.add{type="label", caption="", name = "team_label", single_line = false}
    team_label.style.font = "default-semibold"


    local mark_line_button_index = 0
    local create_mark_line_button = function(parent, title)
        local button = parent.add{type="button", caption = title or " ", style="bingo_table_button_style", name="mark_line_button_"..mark_line_button_index, tags = {index = mark_line_button_index}, tooltip = "Mark this line. Press again to unmark.", }
        mark_line_button_index = mark_line_button_index + 1
        return button
    end

    if board_gui.mode ~= "rows_only" then
        --bingo_table.add{type="flow", name="top_left_empty"}
        local button = create_mark_line_button(bingo_table)
        button.tooltip = "Unmark. "
        for i = 1, board_gui.n_cols do
            local b = create_mark_line_button(bingo_table, i)
            -- TODO this is a band-aid fix. Figure out why this is necessary.
            b.style.width = TaskGui.cell_width + 8
        end
    else
        mark_line_button_index = mark_line_button_index + 1
    end

    for i, task in pairs(board.tasks) do
        if i % board_gui.n_cols == 1 then
            local b = create_mark_line_button(bingo_table, (i-1)/board_gui.n_cols+1)
            -- TODO this is a band-aid fix. Figure out why this is necessary.
            b.style.height = TaskGui.cell_height + 12
        end

        local task_gui = TaskGui.create{
            index = i,
            board_gui = board_gui,
            task = task,
            player = board_gui.player,
            parent = bingo_table,
            is_player_active = is_player_active
        }
        board_gui.task_guis[i] = task_gui
    end

    --]]

    return flow
end


function BoardGui.destroy(player)
    local gui = BoardGui.get(player)
    for _, task_gui in pairs(gui.task_guis) do
        TaskGui.destroy(task_gui)
    end
    if not gui then return end
    if gui.button_flow and gui.button_flow.valid then gui.button_flow.destroy() end
    if gui.flow and gui.flow.valid then gui.flow.destroy() end

    ModUtil.remove_all(global.BoardGui.guis, function(bg) return bg == gui end)
end


Event.register(Event.generate_event_name("on_bingo_board_player_added"), function(args)
    local board = args.board
    local player = game.players[args.player_index]
    if BoardGui.exists(player) then
        BoardGui.destroy(player)
    end
    BoardGui.create(player, board)
end)

Event.register(Event.generate_event_name("on_bingo_board_player_removed"), function(args)
    local player = game.players[args.player_index]
    if BoardGui.exists(player) then
        BoardGui.destroy(player)
    end
end)

function BoardGui.exists(player)
    return global.BoardGui.guis[player.index] ~= nil
end

function BoardGui.get(player)
    local player_index = player
    if type(player_index) ~= type(1) then player_index = player.index end
    return global.BoardGui.guis[player_index]
end

function BoardGui.get_guis_of_board(board)
    local guis = {}
    for _, gui in pairs(global.BoardGui.guis) do
        if gui.board == board then
            table.insert(guis, gui)
        end
    end
    return guis
end


function BoardGui.get_flow(board_gui)
    return board_gui.flow
end

function BoardGui.get_task_gui(board_gui, index)
    return board_gui.task_guis[index]
end

function BoardGui.set_team_name(board_gui, team_name)
    board_gui.team_name = team_name
    local flow = BoardGui.get_flow(board_gui)
    --flow.caption = "Bingo. "..board_gui.team_name or ""
    flow.team_label.caption = "[color=1, 0.74, 0.40]Team:[/color] "..(board_gui.team_name or "")
end
Event.register(Event.generate_event_name("on_bingo_team_name_changed"), function(args)
    local team_name = args.board.team_name
    local board_guis = BoardGui.get_guis_of_board(args.board)
    for _, board_gui in pairs(board_guis) do
        BoardGui.set_team_name(board_gui, team_name)
    end
end)

function BoardGui.set_gui_won(board_gui, line_index)
    local text = "Ingame time: "..util.formattime(game.tick)
    local index = line_index
    if board_gui.mode ~= "rows_only" and line_index and line_index >= board_gui.n_cols then index = index - board_gui.n_cols end
    if not line_index then
        text = "finished! "..text
    else
        if line_index <= board_gui.n_cols and board_gui.mode ~= "rows_only" then
            text = "column "..index.." finished! "..text
        else
            text = "row "..index.."finished!"..text
        end
    end

    BoardGui.get_flow(board_gui).caption = "Bingo "..text
end

Event.register(Event.generate_event_name("on_bingo_board_won"), function(args)
    local line_index = args.line_index
    local board = args.board
    for _, board_gui in pairs(BoardGui.get_guis_of_board(board)) do
        BoardGui.set_gui_won(board_gui, line_index)
    end
end)

function BoardGui.update(board_gui)
    for _, task_gui in pairs(board_gui.task_guis) do
        TaskGui.update(task_gui)
    end
end

Event.register(Event.generate_event_name("on_bingo_marked_line_changed"), function(args)
    local board = args.board
    for _, board_gui in pairs(BoardGui.get_guis_of_board(board)) do
        BoardGui.update_task_marked(board_gui)
    end
end)

function BoardGui.update_task_marked(board_gui)
    local line_index = BoardGui.get_marked_line_index(board_gui)
    local line = board_gui.board.lines[line_index] or {}

    for _, task_gui in pairs(board_gui.task_guis) do
        TaskGui.set_marked(task_gui, ModUtil.contains(line, task_gui.index))
    end
end

function BoardGui.get_marked_line_index(board_gui)
    local marked_line = board_gui.marked_line_override
    local marked_line_of_board
    if board_gui.is_player_active then
        marked_line_of_board = Board.get_marked_line_index(board_gui.board)
    end
    return marked_line_of_board or marked_line
end

function BoardGui.set_marked_line_index(board_gui, line_index)
    local old_index = BoardGui.get_marked_line_index(board_gui)
    if board_gui.is_player_active then
        if old_index == line_index then
            Board.set_marked_line_index(board_gui.board, 0)
        else
            Board.set_marked_line_index(board_gui.board, line_index)
        end
    else
        if board_gui.marked_line_override == line_index then
            board_gui.marked_line_override = 0
        else
            board_gui.marked_line_override = line_index
        end
        BoardGui.update_task_marked(board_gui)
    end
end

local on_mark_line_button_click = function(event)
    local element = event.element
    local player_index = event.player_index
    local line_index = element.tags.index
    local player = game.players[player_index]
    local board_gui = BoardGui.get(player)

    if line_index < 0 or line_index > board_gui.n_rows+board_gui.n_cols then line_index = nil end

    BoardGui.set_marked_line_index(board_gui, line_index)
end
Gui.on_click("mark_line_button_.*", on_mark_line_button_click)



function BoardGui.is_task_marked(board_gui, index)
    local line = BoardGui.get_marked_line_index(board_gui)
    return ModUtil.contains(line, index)
end



function BoardGui.toggle_hide_gui(args)
    local player = game.players[args.player_index]
    --local element = args.element
    local board_gui = BoardGui.get(player)
    local flow = BoardGui.get_flow(board_gui)
    if flow.visible == nil then flow.visible = false else flow.visible = not flow.visible end
end
Gui.on_click("bingo_hide_button", BoardGui.toggle_hide_gui)


function BoardGui.on_configuration_changed()
    -- Rebuild ui
    for _, board_gui in pairs(global.BoardGui.guis) do
        BoardGui.destroy(board_gui.player)
        BoardGui.create(board_gui.player, board_gui.board)
    end
end
Event.on_configuration_changed(BoardGui.on_configuration_changed)

return BoardGui

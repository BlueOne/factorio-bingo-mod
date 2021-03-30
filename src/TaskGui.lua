
local TaskGui = {
    cell_width = 90,
    cell_height = 30,
}

local Task = require("src/Task")
local ModUtil = require("src/ModUtil")
local Event = require('__stdlib__/stdlib/event/event')

global.TaskGui = global.TaskGui or {
    guis_by_name = {}
}

function TaskGui.create(args)
    local parent = args.parent
    local board_gui = args.board_gui
    local task = args.task
    local index = args.index
    local player = args.player or game.players[parent.player_index]
    local is_marked = args.is_marked
    local is_player_active = args.is_player_active
    if is_player_active == nil then is_player_active = true end

    local task_gui = {
        index = index,
        board_gui = board_gui,
        flow = nil,
        frame = nil,
        task = task,
        parent = parent,
        player = player,
        is_marked = is_marked,
        is_player_active = is_player_active
    }

    if not global.TaskGui.guis_by_name[task.name] then global.TaskGui.guis_by_name[task.name] = {} end
    table.insert(global.TaskGui.guis_by_name[task.name], task_gui)

    -- Flow inside the frame so that we can change the color of the frame without changing the dimension and alignments inside the flow.
    local task_frame = parent.add{type="frame", name="bingo_task_"..index, direction="vertical", style="bingo_table_item_style"}
    local task_flow = task_frame.add{type="flow", name="flow", direction="vertical"}
    task_flow.style.width = TaskGui.cell_width
    task_flow.style.height = TaskGui.cell_height
    task_frame.style.horizontal_align = "center"
    task_frame.style.vertical_align = "center"
    task_flow.style.horizontal_align = "center"
    task_flow.style.vertical_align = "center"

    task_gui.flow = task_flow
    task_gui.frame = task_frame

    Task.create_gui(task_gui, task_flow)

    TaskGui.update(task_gui)

    return task_gui
end

function TaskGui.set_marked(task_gui, is_marked)
    task_gui.is_marked = is_marked
    TaskGui.update_frame(task_gui)
end

function TaskGui.set_player_active(task_gui, active)
    task_gui.is_player_active = active
    TaskGui.update_frame(task_gui)
end

function TaskGui.destroy(task_gui)
    if not task_gui then return end
    local task = task_gui.task
    ModUtil.remove_all(global.TaskGui.guis_by_name[task.name], function(gui) return gui == task_gui end)

    if task_gui.frame and task_gui.frame.valid then task_gui.frame.destroy() end
end


function TaskGui.update_frame(task_gui)
    local is_marked = task_gui.is_marked
    local frame = task_gui.frame
    if Task.is_done(task_gui.task) then
        frame.style = "bingo_table_finished_item_style"
    elseif is_marked then
        frame.style = "bingo_table_pending_item_style"
    else
        frame.style = "bingo_table_item_style"
    end
end

function TaskGui.update(task_gui, args)
    TaskGui.update_frame(task_gui)
    Task.update_gui(task_gui, args)
end

function TaskGui.get_guis_of_task(task)
    local guis = {}
    if not global.TaskGui.guis_by_name[task.name] then return {} end
    for _, task_gui in pairs(global.TaskGui.guis_by_name[task.name]) do
        if task_gui.task == task then
            table.insert(guis, task_gui)
        end
    end

    return guis
end


Event.register(Event.generate_event_name("on_bingo_task_done"), function(args)
    for _, task_gui in pairs(TaskGui.get_guis_of_task(args.task)) do
        TaskGui.update_frame(task_gui)
    end
end)

Event.register(Event.generate_event_name("on_bingo_task_state_changed"), function(args)
    for _, task_gui in pairs(TaskGui.get_guis_of_task(args.task)) do
        TaskGui.update(task_gui, args)
    end
end)

Event.register(Event.generate_event_name("on_bingo_task_destroyed"), function(args)
    for _, task_gui in pairs(TaskGui.get_guis_of_task(args.task)) do
        TaskGui.destroy(task_gui)
    end
end)


return TaskGui
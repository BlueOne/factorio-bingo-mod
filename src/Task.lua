

local Task = {
    _initialized_event_types = {},
    modules = {}
}

package.loaded[...] = Task

local TaskPrototypes = require("TaskPrototypes")
local ModUtil = require("src/ModUtil")
local Event = require('__stdlib__/stdlib/event/event')


local type_func = type -- save in case it gets overwritten in local scopes

global.Task = global.Task or { task_registry = {} }


function Task.on_load()
    local registry = global.Task.task_registry
    for type, _ in pairs(registry) do
        Task.init_events(type)
    end
end
Event.on_load(Task.on_load)

function Task.create(args)
    local prototype = TaskPrototypes.get(args.name)
    local task = util.merge{prototype, {
        index = args.index,
        done = prototype.done or false,
        name = args.name,
        force = args.force,
        marked = false
    }}
    task.board = args.board

    local registry = global.Task.task_registry
    if not registry[task.type] then registry[task.type] = {} end
    table.insert(registry[task.type], task)

    if not Task._initialized_event_types[task.type] then Task.init_events(task.type) end

    Event.dispatch{
        name = Event.generate_event_name("on_bingo_task_created"),
        task = task
    }
    return task
end

function Task.destroy(task)
    local tasks = global.Task.task_registry[task.type]
    ModUtil.remove_all(tasks, function(t) return t == task end)
    Event.dispatch({
        name = Event.generate_event_name("on_bingo_task_destroyed"),
        task = task,
    })
end

function Task.is_done(task)
    return task.done
end

function Task.set_done(task, done)
    local event_data = {
        name = Event.generate_event_name("on_bingo_task_done"),
        task = task,
        done = done,
        task_index = task.index
    }
    Event.dispatch(event_data)

    task.done = done
end

function Task.is_active(task)
    return not task.board.won
end

function Task.get_board(task)
    return task.board
end

function Task.set_marked(task, marked)
    task.marked = marked
end

function Task.get_type(task)
    return task.type
end


function Task.init_events(type)
    if Task._initialized_event_types[type] then return end
    local task_impl = Task.get_type_impl(type)
    for event_id, handler in pairs(task_impl.handlers) do
        if event_id == "on_nth_tick" then
            for tick, h in pairs(handler) do
                Event.register(-1 * tick, h)
            end
        else
            if type_func(handler) == type_func({}) then
                Event.register(handler.event_id, handler.handler, handler.filter, handler.pattern)
            else
                Event.register(event_id, handler)
            end
        end
    end
    Task._initialized_event_types[type] = true
end

function Task.notify_task_state_changed(task, params)
    params = params or {}
    local event_data = util.merge{
        {
            name = Event.generate_event_name("on_bingo_task_state_changed"),
            task_index = task.index,
        },
        params
    }
    event_data.task = task
    Event.dispatch(event_data)
end


function Task.get_type_impl(type)
    assert(Task.modules[type], "Invalid task type: "..type)
    return Task.modules[type]
end

function Task.add_type_impl(type, implementation_module)
    Task.modules[type] = implementation_module
end

function Task.create_gui(task_gui, parent)
    local task = task_gui.task
    local task_impl = Task.get_type_impl(task.type)
    task_impl.create_gui(task_gui, parent)
end

function Task.update_gui(task_gui, args)
    local task_impl = Task.get_type_impl(task_gui.task.type)
    if task_impl.update_gui then
        task_impl.update_gui(task_gui, args)
    end
end

function Task.init(task)
    local task_impl = Task.get_type_impl(task.type)
    if task_impl.init then task_impl.init(task) end
end

function Task.check_prototype(task_prototype)
    assert(task_prototype.name ~= nil, "Task prototype is missing a name. \n" .. serpent.block(task_prototype))
    assert(task_prototype.short_title ~= nil, "Task prototype "..task_prototype.name.." is missing a title. ")
    assert(task_prototype.type ~= nil, "Task prototype "..task_prototype.name.." is missing a type. ")

    local task_impl = Task.get(task_prototype.type)
    if task_impl.check_prototype then task_impl.check_prototype(task_prototype) end
end


function Task.get_tasks_of_type(type)
    return global.Task.task_registry[type]
end

return Task

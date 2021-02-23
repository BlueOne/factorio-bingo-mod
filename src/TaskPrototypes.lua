local table = require("__stdlib__/stdlib/utils/table")
local Event = require('__stdlib__/stdlib/event/event')
--local Gui = require('__stdlib__/stdlib/event/gui')
local util = require("util")
local CustomEvent = require("customEvent")
local TaskEvent = require("src/TaskEvent")


local TaskPrototypes = {
    tasks = {}
}


local done_color = "[color=140, 255, 140]"
local default_color = "[color=222,222,222]"
-------------------------------------------------------------------------------
-- Primitives

-- Add task prototype
-- Parameters:
-- name (string) - the unique internal name of the task prototype
-- title (string) - the display title of the task
-- short_title (string, optional) - the abbreviated title
-- init (function) - the init function for this task which is called when the board is created and again during on_load. Use this to register event handlers. Called via init(task, board, is_on_load).
-- destroy (function, optional) the destroy function for this task, called when the board is won. Events do not need to be unregistered here as they are automatically unregistered by the board. Called via destroy(task, board)
-- finished (function, optional) called when the task is finished. finished(task, board)
-- create_ui (function) called for creation of the ui. Occurs upon task creation after init and after configuration change. create_ui(task, board)
-- @tparam string description (optional) description of the task
-- @param flags the list of flags that are used for board generation. Currently only "restriction"
TaskPrototypes.add = function(task)
    assert(task.name ~= nil, "Task prototype is missing a name. \n" .. serpent.block(task))
    assert(task.title ~= nil, "Task prototype "..task.name.." is missing a title.")
    assert(task.init ~= nil, "Task prototype "..task.name.." is missing an init function. ")
    TaskPrototypes.tasks[task.name] = task
end

-- Get task prototype. Asserts that the task exists
-- @tparam string name the name of the task
TaskPrototypes.get = function(name)
    assert(TaskPrototypes.tasks[name] ~= nil, "Task Prototype does not exist: "..name)
    return TaskPrototypes.tasks[name]
end

-- Check if task prototype exists
-- @tparam string name the name of the task
TaskPrototypes.exists = function(name)
    return TaskPrototypes.tasks[name]
end

TaskPrototypes.all = function()
    return TaskPrototypes.tasks
end
-- Raise task done event to notify the board.
-- pass done=false for not done, omit done is the same as true
local notify_task_done = function(player, task, board, done)
    if done == nil then done = true end
    local event_data = {
        name = CustomEvent.on_task_finished,
        task = task,
        player = player,
        board = board,
        done = done
    }
    Event.dispatch(event_data)
end

-------------------------------------------------------------------------------
-- Tools

local production_text = function(produced, target, icon)
    local text = ""
    if produced >= target then text = text .. done_color else text = text .. default_color end
    text = text .. icon.." " .. util.format_number(math.min(target, produced), true) .. " / " .. util.format_number(target, true) .. "[/color]" .. "\n"
    return text
end
-- Add production task. No fluids handled currently
-- Same arguments as add, but init and finished are overwritten.
-- TODO: not tested and probably not working for more than one ingredient.
-- TODO: Generalize this to flow stat task i.e. parameters of the form {{name, count, stat_type, icon_string}, ...}
-- TODO: Add a little production icon

TaskPrototypes.add_production_task = function(task_prototype)
    local prototype = table.deepcopy(task_prototype)
    prototype.init = function(task, board)
        if board.won then return end
        local on_nth_tick = function(_)
            local player = task.player
            local stats = player.force.item_production_statistics
            local text = ""
            local task_done = true
            for _, ingredient in pairs(task.target) do
                local name = ingredient[1]
                local amount = ingredient[2]
                local produced = stats.get_input_count(name)
                if produced < amount then task_done = false end
                text = text..production_text(produced, amount, "[item="..name.."]")
            end
            task.flow.description_text.caption = text
            if task_done and not task.done then
                notify_task_done(player, task, board)
            end
        end
        TaskEvent.register(task, {event_id=-60, handler=on_nth_tick})
    end

    prototype.finished = function(task)
        TaskEvent.remove_task(task)
    end

    prototype.create_ui = function(task, _)
        local label = task.flow.add{type="label", name="description_text", caption=""}
        label.style.font = "default-large-semibold"
        label.tooltip = task.description

        local player = task.player
        local stats = player.force.item_production_statistics
        local text = ""
        for _, ingredient in pairs(task.target) do
            local name = ingredient[1]
            local amount = ingredient[2]
            local produced = stats.get_input_count(name)
            text = text..production_text(produced, amount, "[item="..name.."]")
        end
        task.flow.description_text.caption = text

    end

    TaskPrototypes.add(prototype)
end


-- Convenience method for production task of a single item
TaskPrototypes.simple_production_task = function(item, count, title)
    --assert(game.item_prototypes[item], "Item for production task does not exist: "..item)
    if not title then
        title = {"", ""..count.." ", {"item-name."..item}}
    end
    --error("produce-"..count.."-"..item)
    TaskPrototypes.add_production_task({
        name = "produce-"..item,
        title = title,
        short_title = ""..count.." [item="..item.."]",
        description = {"", "Produce "..count.." x ", {"item-name."..item}},

        target = {
            {item, count}
        }
    })
end

-- Add a task that the player can mark as done by themselves.
-- Same arguments as add, but init is overwritten.
-- pass done = true to initialize the task as done
TaskPrototypes.add_self_verified_task = function(task_prototype)
    local prototype = table.deepcopy(task_prototype)
    prototype.init = function(task, board)
        if board.won then return end
        local on_button_clicked = function(event)
            local flow = task.flow
            if task.pid ~= event.player_index then return end
            local button = flow.inner_flow["task_button_"..task.name]
            task.done = button.state
            local player = game.players[event.player_index]
            if task.done then
                notify_task_done(player, task, board, true)
            else
                notify_task_done(player, task, board, false)
            end
            flow.inner_flow.description_text.caption = (task.done and done_color or default_color)..task.short_title.."[/color]"
        end
        TaskEvent.register(task, {event_id=defines.events.on_gui_checked_state_changed, handler=on_button_clicked, filter=Event.Filters.gui, pattern="task_button_"..task.name})
    end

    prototype.create_ui = function(task, _)
        local inner_flow = task.flow.add{type="flow", name="inner_flow", direction="horizontal"}
        local label = inner_flow.add{type="label", name="description_text", caption=task.short_title, tooltip=task.description}
        label.style.font = "default-large-semibold"
        label.tooltip = task.description
        label.style.horizontal_align = "center"
        label.style.vertical_align = "center"
        local button = inner_flow.add{type="checkbox", name="task_button_"..task.name, state=false}
        button.tooltip = "This task has no automatic verification. Verify it manually via this button. "
        button.style.top_margin = 6
    end

    TaskPrototypes.add(prototype)
end
-------------------------------------------------------------------------------
-- Task Data


TaskPrototypes.add_self_verified_task({
    name = "ammo_belt",
    title = "Ammo Belt around your base",
    short_title = "Ammo-Belt",--"[item=piercing-rounds-magazine] [item=transport-belt]",
    description = "Build a belt around your base and fill it completely with piercing rounds magazines on one side of the belt. The belt has to go around all assemblers, steam engines and furnaces at the end of the game. ",
})

TaskPrototypes.simple_production_task("iron-gear-wheel", 10000)
TaskPrototypes.simple_production_task("utility-science-pack", 40)
TaskPrototypes.simple_production_task("iron-plate", 60000)
TaskPrototypes.simple_production_task("electronic-circuit", 10000)
TaskPrototypes.simple_production_task("coal", 40000)
TaskPrototypes.simple_production_task("steel-plate", 5000)
TaskPrototypes.simple_production_task("stone", 20000)
TaskPrototypes.simple_production_task("electric-mining-drill", 250)
TaskPrototypes.simple_production_task("engine-unit", 400)
TaskPrototypes.simple_production_task("assembling-machine-1", 150)
TaskPrototypes.simple_production_task("oil-refinery", 30)
TaskPrototypes.simple_production_task("steam-engine", 40)
TaskPrototypes.simple_production_task("automation-science-pack", 3000)
TaskPrototypes.simple_production_task("explosive-rocket", 200)
TaskPrototypes.simple_production_task("grenade", 1000)
TaskPrototypes.simple_production_task("stone-wall", 1000)
TaskPrototypes.simple_production_task("piercing-rounds-magazine", 1000)
TaskPrototypes.simple_production_task("solar-panel-equipment", 40)
TaskPrototypes.simple_production_task("personal-roboport-equipment", 5)
TaskPrototypes.simple_production_task("flying-robot-frame", 200)
TaskPrototypes.simple_production_task("nuclear-reactor", 1)
TaskPrototypes.simple_production_task("electric-furnace", 48)
TaskPrototypes.simple_production_task("cluster-grenade", 100)
TaskPrototypes.simple_production_task("production-science-pack", 40)
TaskPrototypes.simple_production_task("effectivity-module-2", 40)
TaskPrototypes.simple_production_task("medium-electric-pole", 2000)




return TaskPrototypes
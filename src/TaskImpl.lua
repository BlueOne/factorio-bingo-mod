
local TaskImpl = {
    _initialized_types = {}
}

package.loaded[...] = TaskImpl

local Board = require("src/Board")

local table = require("__stdlib__/stdlib/utils/table")
local Event = require('__stdlib__/stdlib/event/event')
--local Gui = require('__stdlib__/stdlib/event/gui')
local util = require("util")
local CustomEvent = require("customEvent")
local TaskRegistry = require("src/TaskRegistry")


------------------------------------------------------------------------------
-- General


local done_color = "[color=180, 180, 180]"
--local done_color = "[color=140, 200, 140]"
local default_color = "[color=240,240,240]"
local default_font = "default-semibold"
local type_func = type

local notify_task_done = function(task, done)
    if done == nil then done = true end
    task.done = done
    local event_data = {
        name = CustomEvent.on_task_finished,
        task = task,
        done = done
    }
    --script.raise_event(CustomEvent.on_task_finished, event_data)
    Event.dispatch(event_data)
end



TaskImpl.init_events = function(type)
    if TaskImpl._initialized_types[type] then return end
    local task_type = TaskImpl[type]
    for event_id, handler in pairs(task_type.handlers) do
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
    TaskImpl._initialized_types[type] = true
end

------------------------------------------------------------------------------
-- Flow Stat Task

-- Task type that checks item production, fluid production, kill statistics or build statistics. Task is marked if all targets are satisfied.
-- Only input (the right side of the ui) is supported at the moment, except for build type where we use input - output.
-- TODO Only a single target per task is supported at the moment.
-- TODO the stat type is not made clear via UI currently, could add icons to differentiate build and produce.
-- Type specific fields: `targets`. list of `target`
-- each `target` is a list of the form { name, amount, stat_type, icon_string }. name is the internal name of the target. amount is the minimum number. stat_type (optional) is one of "item" (default), "fluid", "kill", "build". icon_string (optional) is the rich text string for the item icon, e.g. "[item=iron-ore]"

local FlowStat = {
    type = "FlowStat",
    handlers = {}
}

local production_text = function(produced, target, icon)
    local text = ""
    if produced >= target then text = text .. done_color else text = text .. default_color end
    text = text .. icon.." " .. util.format_number(math.min(target, produced), true) .. " / " .. util.format_number(target, true) .. "[/color]" .. "\n"
    return text
end

local FlowStat_get_value = function(target, force)
    local name = target[1]
    if target[3] == "item" or target[3] == nil then
        local itemStats = force.item_production_statistics
        return itemStats.get_input_count(name)
    elseif target[3] == "fluid" then
        local fluidStats = force.fluid_production_statistics
        return fluidStats.get_input_count(name)
    elseif target[3] == "kill" then
        local killStats = force.kill_count_statistics
        return killStats.get_input_count(name)
    elseif target[3] == "build" then
        local buildStats = force.entity_build_count_statistics
        return buildStats.get_input_count(name) - buildStats.get_output_count(name)
    else
        error("Invalid FlowStatTask target: " .. serpent.block(target))
    end
end

local FlowStat_update_ui = function(task, player)
    local text = ""
    for _, target in pairs(task.targets) do
        local amount = target[2]
        local produced = FlowStat_get_value(target, task.force)
        local icon_text = target[4] or "[item="..target[1].."]"
        text = text..production_text(produced, amount, icon_text)
    end
    Board.get_task_flow(task, player).description_text.caption = text
end

local FlowStat_check_finished = function(task)
    if not task.done and not Board.get_board_of_task(task).won then
        local task_done = true
        for _, target in pairs(task.targets) do
            local want = target[2]
            local have = FlowStat_get_value(target, task.force)
            if have < want then task_done = false end
        end
        if task_done and not task.done then
            notify_task_done(task)
        end
    end
end

FlowStat.handlers.on_nth_tick = {
    [60] = function()
        for _, task in pairs(TaskRegistry.get_tasks_of_type("FlowStat")) do
            if not Board.get_board_of_task(task).won then
                FlowStat_check_finished(task)
                for _, player in pairs(Board.get_board_of_task(task).ui_players) do
                    FlowStat_update_ui(task, player)
                end
            end
        end
    end
}
FlowStat.init = function(task, on_load)
    if not on_load then
        FlowStat_check_finished(task)
        for _, player in pairs(Board.get_board_of_task(task).ui_players) do
            FlowStat_update_ui(task, player)
        end
    end
end

FlowStat.create_ui = function(task, player)
    local flow = Board.get_task_flow(task, player)
    local label = flow.add{type="label", name="description_text", caption=""}
    label.style.font = default_font
    label.tooltip = task.description

    FlowStat_update_ui(task, player)
end

FlowStat.check_prototype = function(task_prototype)
    assert(type(task_prototype.targets) == type({}), "Production Task Prototype has invalid targets field. "..serpent.block(task_prototype))
    for i, target in pairs(task_prototype.targets) do
        assert(type(target[1]) == type(""), "Production target "..i.." of FlowStat task is invalid. "..serpent.block(task_prototype))
        assert(type(target[2]) == type(1), "Production target "..i.." of FlowStat task is invalid. "..serpent.block(task_prototype))
        assert(target[3] == nil or type(target[3]) == type(""), "Production target "..i.." of FlowStat task is invalid. "..serpent.block(task_prototype))
        assert(target[4] == nil or type(target[4]) == type(""), "Production target "..i.." of FlowStat task is invalid. "..serpent.block(task_prototype))
    end
end

TaskImpl.FlowStat = FlowStat


------------------------------------------------------------------------------
-- Self Verified Task
-- Task type which is marked as done by the user via a gui element.
-- Task Specific fields:
-- done (bool, default false) determines if the task starts as verified.
local SelfVerified = {
    type = "SelfVerified",
    handlers = {}
}

local SelfVerified_update_ui = function(task, player)
    local flow = Board.get_task_flow(task, player)
    flow.inner_flow.description_text.caption = (task.done and done_color or default_color)..task.short_title.."[/color]"
    flow.inner_flow["SelfVerified_checkbox_"..task.name].state = task.done
end

local SelfVerified_on_checkbox_clicked = function(event)
    local element = event.element
    local player_index = event.player_index
    for _, task in pairs(TaskRegistry.get_tasks_of_type("SelfVerified")) do
        if not Board.get_board_of_task(task).won and element.name == "SelfVerified_checkbox_"..task.name and table.any(Board.get_board_of_task(task).active_players, function(p) return p.index == player_index end) then
            task.done = element.state
            if task.done then
                notify_task_done(task, true)
            else
                notify_task_done(task, false)
            end
            for _, player in pairs(Board.get_board_of_task(task).ui_players) do
                SelfVerified_update_ui(task, player)
            end
        end
    end
end

SelfVerified.handlers = {
    on_gui_checked_state_changed = { event_id = defines.events.on_gui_checked_state_changed, handler = SelfVerified_on_checkbox_clicked, filter = Event.Filters.gui, pattern = "SelfVerified_checkbox_.*" }
}

SelfVerified.create_ui = function(task, player)
    local flow = Board.get_task_flow(task, player)
    local inner_flow = flow.add{type="flow", name="inner_flow", direction="horizontal"}
    local label = inner_flow.add{type="label", name="description_text", caption=task.short_title, tooltip=task.description}
    label.style.font = default_font
    label.tooltip = task.description
    label.style.horizontal_align = "center"
    label.style.vertical_align = "center"
    local checkbox = inner_flow.add{type="checkbox", name="SelfVerified_checkbox_"..task.name, state=false}
    checkbox.tooltip = "This task has no automatic verification. Verify it manually via this checkbox. "
    checkbox.style.top_margin = 3
    checkbox.state = task.done

    SelfVerified_update_ui(task, player)
end



TaskImpl.SelfVerified = SelfVerified


return TaskImpl

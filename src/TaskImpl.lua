local table = require("__stdlib__/stdlib/utils/table")
local Event = require('__stdlib__/stdlib/event/event')
--local Gui = require('__stdlib__/stdlib/event/gui')
local util = require("util")
local CustomEvent = require("customEvent")
local Tasks = require("src/TaskRegistry")

local TaskImpl = {
    _initialized_types = {}
}


------------------------------------------------------------------------------
-- General

--local done_color = "[color=180, 180, 180]"
local done_color = "[color=140, 200, 140]"
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

-- TODO build task is supported but idk if it counts subtracts deconstructed buildings, probably not.
local FlowStat = {
    type = "FlowStat",
    handlers = {}
}
-- FlowStat.init = nil
-- FlowStat.finished = nil

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
        return buildStats.get_input_count(name)
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
    task.flows[player.index].description_text.caption = text
end

local FlowStat_check_finished = function(task)
    if not task.done and not task.board.won then
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
        for _, task in pairs(Tasks.get_tasks_of_type("FlowStat")) do
            FlowStat_check_finished(task)
            for _, player in pairs(task.board.ui_players) do
                FlowStat_update_ui(task, player)
            end
        end
    end
}
FlowStat.init = function(task, on_load)
    if not on_load then
        FlowStat_check_finished(task)
        for _, player in pairs(task.board.ui_players) do
            FlowStat_update_ui(task, player)
        end
    end
end

FlowStat.create_ui = function(task, player)
    local flow = task.flows[player.index]
    local label = flow.add{type="label", name="description_text", caption=""}
    label.style.font = default_font
    label.tooltip = task.description

    FlowStat_update_ui(task, player)
end

TaskImpl.FlowStat = FlowStat


------------------------------------------------------------------------------
-- Self Verified Tasks
local SelfVerified = {
    type = "SelfVerified",
    handlers = {}
}

local SelfVerified_update_ui = function(task, player)
    local flow = task.flows[player.index]
    flow.inner_flow.description_text.caption = (task.done and done_color or default_color)..task.short_title.."[/color]"
    flow.inner_flow["SelfVerified_checkbox_"..task.name].state = task.done
end

local SelfVerified_on_checkbox_clicked = function(event)
    local element = event.element
    local player_index = event.player_index
    for _, task in pairs(Tasks.get_tasks_of_type("SelfVerified")) do
        if element.name == "SelfVerified_checkbox_"..task.name and table.any(task.board.active_players, function(p) return p.index == player_index end) then
            task.done = element.state
            if task.done then
                notify_task_done(task, true)
            else
                notify_task_done(task, false)
            end
            for _, player in pairs(task.board.ui_players) do
                SelfVerified_update_ui(task, player)
            end
        end
    end
end

SelfVerified.handlers = {
    on_gui_checked_state_changed = { event_id = defines.events.on_gui_checked_state_changed, handler = SelfVerified_on_checkbox_clicked, filter = Event.Filters.gui, pattern = "SelfVerified_checkbox_.*" }
}

SelfVerified.create_ui = function(task, player)
    local flow = task.flows[player.index]
    local inner_flow = flow.add{type="flow", name="inner_flow", direction="horizontal"}
    local label = inner_flow.add{type="label", name="description_text", caption=task.short_title, tooltip=task.description}
    label.style.font = default_font
    label.tooltip = task.description
    label.style.horizontal_align = "center"
    label.style.vertical_align = "center"
    local checkbox = inner_flow.add{type="checkbox", name="SelfVerified_checkbox_"..task.name, state=false}
    checkbox.tooltip = "This task has no automatic verification. Verify it manually via this checkbox. "
    checkbox.style.top_margin = 3

    SelfVerified_update_ui(task, player)
end



TaskImpl.SelfVerified = SelfVerified


return TaskImpl

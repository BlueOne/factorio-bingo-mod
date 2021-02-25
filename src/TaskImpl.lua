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

local done_color = "[color=140, 255, 140]"
local default_color = "[color=222,222,222]"
local default_font = "default-semibold"
local type_func = type

local notify_task_done = function(player, task, done)
    if done == nil then done = true end
    local event_data = {
        name = CustomEvent.on_task_finished,
        task = task,
        player = player,
        done = done
    }
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

local FlowStat_get_value = function(target, player)
    local name = target[1]
    local force = player.force
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

local FlowStat_update_ui = function(task)
    local player = task.player
    local text = ""
    for _, target in pairs(task.targets) do
        local amount = target[2]
        local produced = FlowStat_get_value(target, player)
        local icon_text = target[4] or "[item="..target[1].."]"
        text = text..production_text(produced, amount, icon_text)
    end
    task.flow.description_text.caption = text
end


FlowStat.handlers.on_nth_tick = {
    [60] = function()
        for _, task in pairs(Tasks.get_tasks_of_type("FlowStat")) do
            if not task.done and not task.board.won then
                local player = task.player
                local task_done = true
                for _, target in pairs(task.targets) do
                    local want = target[2]
                    local have = FlowStat_get_value(target, player)
                    if have < want then task_done = false end
                end
                FlowStat_update_ui(task)
                if task_done and not task.done then
                    notify_task_done(player, task)
                end
            end
        end
    end
}

FlowStat.create_ui = function(task)
    local label = task.flow.add{type="label", name="description_text", caption=""}
    label.style.font = default_font
    label.tooltip = task.description

    FlowStat_update_ui(task)
end

TaskImpl.FlowStat = FlowStat


------------------------------------------------------------------------------
-- Self Verified Tasks
local SelfVerified = {
    type = "SelfVerified",
    handlers = {}
}

local SelfVerified_update_ui = function(task)
    task.flow.inner_flow.description_text.caption = (task.done and done_color or default_color)..task.short_title.."[/color]"
end

local SelfVerified_on_checkbox_clicked = function(event)
    local element = event.element
    for _, task in pairs(Tasks.get_tasks_of_type("SelfVerified")) do
        local player_index = element.tags.player_index
        if task.player_index == player_index and event.player_index == player_index then
            task.done = element.state
            local player = game.players[player_index]
            if task.done then
                notify_task_done(player, task, true)
            else
                notify_task_done(player, task, false)
            end
            SelfVerified_update_ui(task)
        end
    end
end

SelfVerified.handlers = {
    on_gui_checked_state_changed = { event_id = defines.events.on_gui_checked_state_changed, handler = SelfVerified_on_checkbox_clicked, filter = Event.Filters.gui, pattern = "SelfVerified_checkbox_.*" }
}


SelfVerified.create_ui = function(task)
    local inner_flow = task.flow.add{type="flow", name="inner_flow", direction="horizontal"}
    local label = inner_flow.add{type="label", name="description_text", caption=task.short_title, tooltip=task.description}
    label.style.font = default_font
    label.tooltip = task.description
    label.style.horizontal_align = "center"
    label.style.vertical_align = "center"
    local checkbox = inner_flow.add{type="checkbox", name="SelfVerified_checkbox_"..task.name, state=false}
    checkbox.tooltip = "This task has no automatic verification. Verify it manually via this checkbox. "
    checkbox.style.top_margin = 6
    checkbox.tags = {player_index = task.player_index}

    SelfVerified_update_ui(task)
end



TaskImpl.SelfVerified = SelfVerified


return TaskImpl

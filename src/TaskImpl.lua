


local table = require("__stdlib__/stdlib/utils/table")
local Event = require('__stdlib__/stdlib/event/event')
local util = require("util")

local Task = require("src/Task")

------------------------------------------------------------------------------
-- General


local default_color = "[color=240,240,240]"
local default_font = "default-semibold"
--local done_color = "[color=180, 180, 180]"
--local done_color = "[color=140, 200, 140]"
local done_color = default_color



------------------------------------------------------------------------------
-- Flow Stat Task

-- Task type that checks item production, fluid production, kill statistics or build statistics. Task is marked if all targets are satisfied.
-- Only input (the right side of the ui) is supported at the moment, except for build type where we use input - output.
-- TODO Only a single target per task is supported at the moment.
-- TODO the stat type is not made clear via UI currently, could add icons to differentiate build and produce.
-- Type specific fields: `targets`. list of `target`
-- each `target` is a list of the form { name, amount, stat_type, icon_string }. name is the internal name of the target. amount is the minimum number. stat_type (optional) is one of "item" (default), "fluid", "kill", "build". icon_string (optional) is the rich text string for the item icon, e.g. "[item=iron-ore]"

do
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

    local get_stat = function(target, force)
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


    local check_finished = function(task)
        if not Task.is_done(task) and Task.is_active(task) then
            local task_done = true
            local diff = {}
            for k, target in pairs(task.targets) do
                local want = target[2]
                local have = get_stat(target, task.force)
                local old_have = target.have
                target.have = have
                if have < want then task_done = false end
                if old_have ~= have then
                    table.insert(diff, {target[1], old_have, have})
                end
            end
            if #diff > 0 or Task.is_done(task) ~= task_done then
                Task.notify_task_state_changed(task, { changes = diff })
            end
            if task_done and not Task.is_done(task) then
                Task.set_done(task, task_done)
            end
        end
    end

    FlowStat.handlers.on_nth_tick = {
        [60] = function()
            for _, task in pairs(Task.get_tasks_of_type("FlowStat")) do
                if Task.is_active(task) then
                    check_finished(task)
                end
            end
        end
    }

    FlowStat.init = function(task)
        check_finished(task)
    end

    FlowStat.create_gui = function(task_gui)
        local label = task_gui.flow.add{type="label", name="description_text", caption=""}
        label.style.font = default_font
        local task = task_gui.task
        label.tooltip = task.description

        FlowStat.update_gui(task_gui)
    end

    FlowStat.update_gui = function(task_gui, args) --luacheck: ignore 212
        local task = task_gui.task
        local text = ""
        for _, target in pairs(task.targets) do
            local amount = target[2]
            local produced = get_stat(target, task.force)
            local icon_text = target[4] or "[item="..target[1].."]"
            text = text..production_text(produced, amount, icon_text)
        end
        task_gui.flow.description_text.caption = text
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

    Task.add_type_impl("FlowStat", FlowStat)
end

------------------------------------------------------------------------------
-- Self Verified Task
-- Task type which is marked as done by the user via a gui element.
-- Task Specific fields:
-- done (bool, default false) determines if the task starts as verified.

do
    local SelfVerified = {
        type = "SelfVerified",
        handlers = {}
    }

    function SelfVerified.update_ui(task_gui, args) --luacheck: ignore 212
        local task = task_gui.task
        local flow = task_gui.flow
        flow.inner_flow.description_text.caption = (Task.is_done(task) and done_color or default_color)..task.short_title.."[/color]"
        flow.inner_flow["SelfVerified_checkbox_"..task.name].state = Task.is_done(task)
    end

    local on_checkbox_clicked = function(event)
        local element = event.element
        local player_index = event.player_index

        local found = false
        for _, task in pairs(Task.get_tasks_of_type("SelfVerified")) do
            if Task.is_active(task) and element.name == "SelfVerified_checkbox_"..task.name and table.any(Task.get_board(task).active_players, function(p) return p.index == player_index end) then
                Task.set_done(task, element.state)
                Task.notify_task_state_changed(task)
                local done = element.state
                if done == nil then done = true end
                Task.set_done(task, done)

                found = true
            end
        end

        -- If player is not active on any board then they're not allowed to change this
        if not found then element.state = not element.state end
    end

    SelfVerified.update_gui = function(task_gui)
        task_gui.flow.inner_flow["SelfVerified_checkbox_"..task_gui.task.name].state = Task.is_done(task_gui.task)
    end

    SelfVerified.handlers = {
        on_gui_checked_state_changed = { event_id = defines.events.on_gui_checked_state_changed, handler = on_checkbox_clicked, filter = Event.Filters.gui, pattern = "SelfVerified_checkbox_.*" }
    }

    SelfVerified.create_gui = function(task_gui)
        local flow = task_gui.flow
        local task = task_gui.task
        local inner_flow = flow.add{type="flow", name="inner_flow", direction="horizontal"}
        local label = inner_flow.add{type="label", name="description_text", caption=task.short_title, tooltip=task.description}
        label.caption = (Task.is_done(task) and done_color or default_color)..task.short_title.."[/color]"
        label.style.font = default_font
        label.tooltip = task.description
        label.style.horizontal_align = "center"
        label.style.vertical_align = "center"
        label.style.single_line = false
        local checkbox = inner_flow.add{type="checkbox", name="SelfVerified_checkbox_"..task.name, state=false}
        checkbox.tooltip = "This task has no automatic verification. Verify it manually via this checkbox. "
        checkbox.style.top_margin = 3
        checkbox.state = Task.is_done(task)
        if checkbox.state == nil then checkbox.state = false end
    end

    Task.add_type_impl("SelfVerified", SelfVerified)
end

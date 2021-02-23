local table = require('__stdlib__/stdlib/utils/table')
local Event = require('__stdlib__/stdlib/event/event')


-- This enables tasks to register their events during runtime and retrieve the handlers later for unregistration.
-- Events are keyed by player id and task id in the task table. We assume that player-id and task-id in combination determine the task uniquely.
-- event_params is a table with keys event_id, handler[, filter][, pattern]. These are passed to stdlib's Event.register.

local TaskEvent = {
    event_registry = {}
}

TaskEvent.register = function(task, event_params)
    if not TaskEvent.event_registry[task.pid] then TaskEvent.event_registry[task.pid] = {} end
    local player_registry = TaskEvent.event_registry[task.pid]
    if not player_registry[task.index] then player_registry[task.index] = {} end
    table.insert(player_registry[task.index], event_params)
    Event.register(event_params.event_id, event_params.handler, event_params.filter, event_params.pattern)
end

TaskEvent.get_events = function(task)
    local player_registry = TaskEvent.event_registry[task.pid]
    assert(player_registry ~= nil, "Attempting to retrieve events for player, but no events were registered!")
    assert(player_registry[task.index] ~= nil, "Attempting to retrieve events for task, but no events were registered!")
    return player_registry[task.index]
end

-- Unregisters all events for specific task, if any were registered
TaskEvent.remove_task = function(task)
    local player_registry = TaskEvent.event_registry[task.pid]
    if player_registry then
        local task_registry = player_registry[task.index]
        if task_registry then
            for _, v in pairs(task_registry) do
                Event.remove(v.event_id, v.handler, v.filter, v.pattern)
            end
        end
    end
    player_registry[task.index] = {}
end

-- Unregister specific event(s). Checks equality for all entries of event_params. Removes all hits. Errors if nothing was matched
TaskEvent.remove = function(task, event_params)
    assert(event_params ~= nil)
    local task_registry = TaskEvent.get_events(task)
    local events = table.filter(task_registry, function(other_event)
        for k, value in pairs(event_params) do
            if other_event[k] ~= value then
                return false
            end
        end
        return true
    end)
    assert(next(events, nil) ~= nil, "Attempted to remove event, but no event was found. ".. serpent.block(event_params))
    for _, event in pairs(events) do
        Event.remove(event.event_id, event.handler, event.filter, event.pattern)
    end
end

return TaskEvent
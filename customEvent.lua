local Event = require('__stdlib__/stdlib/event/event')

local CustomEvent = {
    on_task_finished = Event.generate_event_name("on_task_finished")
}

return CustomEvent

local TaskRegistry = { }

TaskRegistry.g = global.TaskRegistry or {}
global.TaskRegistry = global.TaskRegistry or TaskRegistry.g

TaskRegistry.add = function(task)
    if not TaskRegistry.g[task.type] then TaskRegistry.g[task.type] = {} end
    table.insert(TaskRegistry.g[task.type], task)
end

TaskRegistry.get_tasks_of_type = function(type)
    return TaskRegistry.g[type]
end


return TaskRegistry

local table = require("__stdlib__/stdlib/utils/table")
local util = require("util")


local TaskPrototypes = {
    tasks = {}
}

-------------------------------------------------------------------------------
-- Primitives

-- Add task prototype
-- Parameters:
-- name (string) - the unique internal name of the task prototype
-- title (string) - the display title of the task
-- short_title (string, optional) - the abbreviated title
-- @tparam string description (optional) description of the task
-- @param flags the list of flags that are used for board generation. Currently only "restriction"
TaskPrototypes.add = function(task)
    assert(task.name ~= nil, "Task prototype is missing a name. \n" .. serpent.block(task))
    assert(task.title ~= nil, "Task prototype "..task.name.." is missing a title. ")
    assert(task.type ~= nil, "Task prototype "..task.name.." is missing a type. ")
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

-- name is the internal name of the item to check
-- stat_type is one of "item", "fluid", "kill", "build" (or nil which is the same as item)
-- Warning, build only semi supported
-- localized_name is the localized name of the item, e.g. "entity-name.assembling-machine". Auto-generated as `"item-name."..name` if omitted.
-- icon_str is the rich text string of the item, e.g. [item=iron-plate]. Auto-generated as `"[item="..name.."]" if omitted.
local simple_stat_task = function(name, count, stat_type, localized_name, icon_str)
    --assert(game.item_prototypes[item], "Item for production task does not exist: "..item)
    localized_name = localized_name or "item-name."..name
    icon_str = icon_str or "[item="..name.."]"
    stat_type = stat_type or "item"
    local title = {"", ""..count.." ", {localized_name}}
    local verb = "Produce "
    if stat_type == "kill" then verb = "Kill" end
    if stat_type == "build" then verb = "Build" end
    local description = {"", verb .." "..count.." x ", {localized_name}}
    --error("produce-"..count.."-"..item)

    TaskPrototypes.add{
        name = stat_type.."-"..name.."-"..count,
        type = "FlowStat",
        title = title,
        short_title = ""..count.." "..icon_str,
        description = description,

        targets = {
            {name, count, stat_type, icon_str}
        }
    }
end

-------------------------------------------------------------------------------
-- Task Data


TaskPrototypes.add{
    name = "ammo_belt",
    type = "SelfVerified",
    title = "Ammo Belt around your base",
    short_title = "Ammo-Belt",--"[item=piercing-rounds-magazine] [item=transport-belt]",
    description = "Build a belt around your base and fill it completely with piercing rounds magazines on one side of the belt. The belt has to go around all assemblers, steam engines and furnaces at the end of the game. ",
}

TaskPrototypes.add{
    name = "pet_cat",
    type = "SelfVerified",
    short_title = "Pet the cat",
    description = "Pet the cat. ",
    title = "Pet the cat."
}

simple_stat_task("small-biter", 1000, "kill", "entity-name.small-biter", "[entity=small-biter]")
simple_stat_task("iron-gear-wheel", 10000)
simple_stat_task("utility-science-pack", 40)
simple_stat_task("iron-plate", 60000)
simple_stat_task("electronic-circuit", 10000)
simple_stat_task("coal", 40000)
simple_stat_task("steel-plate", 5000)
simple_stat_task("stone", 20000)
simple_stat_task("electric-mining-drill", 250, nil, "entity-name.electric-mining-drill")
simple_stat_task("engine-unit", 400)
simple_stat_task("assembling-machine-1", 150, nil, "entity-name.assembling-machine-1")
simple_stat_task("oil-refinery", 30, nil, "entity-name.oil-refinery")
simple_stat_task("steam-engine", 40, nil, "entity-name.steam-engine")
simple_stat_task("automation-science-pack", 3000)
simple_stat_task("explosive-rocket", 200)
simple_stat_task("grenade", 1000)
simple_stat_task("stone-wall", 1000, nil, "entity-name.stone-wall")
simple_stat_task("piercing-rounds-magazine", 1000)
simple_stat_task("solar-panel-equipment", 40, nil, "equipment-name.solar-panel-equipment")
simple_stat_task("personal-roboport-equipment", 5, nil, "equipment-name.personal-roboport-equipment")
simple_stat_task("flying-robot-frame", 200)
simple_stat_task("nuclear-reactor", 1, nil, "entity-name.nuclear-reactor")
simple_stat_task("electric-furnace", 48, nil, "entity-name.electric-furnace")
simple_stat_task("cluster-grenade", 100)
simple_stat_task("production-science-pack", 40)
simple_stat_task("effectivity-module-2", 40)
simple_stat_task("medium-electric-pole", 2000, nil, "medium-electric-pole")




return TaskPrototypes
local table = require("__stdlib__/stdlib/utils/table")
local util = require("util")
local production_score = require("src/production-score")
local Event = require('__stdlib__/stdlib/event/event')
local ModUtil = require("src/ModUtil")

local TaskPrototypes = {
    tasks = {}
}

global.TaskPrototypes = global.TaskPrototypes or {
    price_list = nil
}

-------------------------------------------------------------------------------
-- Primitives

-- Add task prototype
-- Parameters:
-- name (string) - the unique internal name of the task prototype
-- short_title (string) - the abbreviated title
-- type (string) - type field determines the logic that is used to determine if the task is done.
-- title (optional, string) - not used currently. the display title of the task
-- description (optional, string) - description of the task, used in the tooltip.
-- depending on type further properties may be necessary
TaskPrototypes.add = function(task)
    TaskPrototypes.tasks[task.name] = task
end

-- Get task prototype. Asserts that the task exists
-- @tparam string name the name of the task
TaskPrototypes.get = function(name)
    TaskPrototypes.setup_tasks()
    assert(TaskPrototypes.tasks[name] ~= nil, "Task Prototype does not exist: "..name)
    return TaskPrototypes.tasks[name]
end

-- Check if task prototype exists
-- @tparam string name the name of the task
TaskPrototypes.exists = function(name)
    TaskPrototypes.setup_tasks()
    return TaskPrototypes.tasks[name]
end

TaskPrototypes.all = function()
    TaskPrototypes.setup_tasks()
    return TaskPrototypes.tasks
end


-- The price list assigns to every item a value, it is used to balance production tasks automatically.
local function setup_price_list()
    local params = {}
    params.energy_addition = function(energy, recipe, ingredient_cost)
        local category_values = {
            crafting = 1.,
            smelting = 0.4,
            chemistry = 1.,
            ["oil-processing"] = 3,
            ["centrifuging"] = 40,
            ["rocket-building"] = 600,
        }
        local category_value = category_values[recipe.category] or 1.
        local category_multiplier = category_value
        return energy * category_multiplier --+ ingredient_cost * 0.05
    end
    params.seed_prices =   {
        ["iron-ore"] = 1.,
        ["copper-ore"] = 1.,
        ["coal"] = 1.,
        ["stone"] = 1.,
        ["crude-oil"] = 0.2,
        ["water"] = 1./1000,
        ["steam"] = 2./1000,
        ["wood"] = 4.,
        ["raw-fish"] = 100,
        ["energy"] = 1,
        ["uranium-ore"] = 8.
      }
    params.ingredient_exponent = 1.15
    params.default_raw_resource_price = 1.
    local price_list = production_score.generate_price_list(params)
    global.TaskPrototypes.price_list = price_list

    --[[
    local t = {}
    for k, v in pairs(price_list) do if not game.recipe_prototypes[k] or (game.recipe_prototypes[k].group.name == "intermediate-products" or game.recipe_prototypes[k].group.name == "production" or game.recipe_prototypes[k].group.name == "logistics") then t[k] = v end end
    game.print(serpent.line(t))
    --]]
end


-- name is the internal name of the item to check
-- stat_type is one of "item", "fluid", "kill", "build" (or nil which is the same as item)
-- Warning, build only semi supported
-- localized_name is the localized name of the item, e.g. "entity-name.assembling-machine". Auto-generated as `"item-name."..name` if omitted.
-- icon_str is the rich text string of the item, e.g. [item=iron-plate]. Auto-generated as `"[item="..name.."]" if omitted.
local simple_stat_task = function(name, count, difficulty, localized_name, icon_str, stat_type, balancing_type)
    localized_name = localized_name or "item-name."..name
    icon_str = icon_str or "[item="..name.."]"
    stat_type = stat_type or "item"
    local title = {"", ""..count.." ", {localized_name}}
    local verb = "Produce "
    if stat_type == "kill" then verb = "Kill" end
    if stat_type == "build" then verb = "Build" end
    local description = {"", verb .." "..count.." x ", {localized_name}}

    TaskPrototypes.add{
        name = stat_type.."-"..name.."-"..count,
        type = "FlowStat",
        title = title,
        short_title = ""..count.." "..icon_str,
        description = description,

        targets = {
            {name, count, stat_type, icon_str}
        },
        balancing = { difficulty = difficulty, type = balancing_type or "production" }
    }
end

local scored_stat_task = function(name, difficulty, localized_name, icon_str, stat_type, count_factor)
    local difficulty_to_score = {
        30000,
        75000,
        150000,
        300000,
        500000,
        1000000,
    }
    local score = difficulty_to_score[difficulty]
    if not global.TaskPrototypes.price_list then setup_price_list() end
    local price = global.TaskPrototypes.price_list[name]
    if not price then error("Item has no score: "..name) end
    local count = ModUtil.round_int(score / price)
    --local count = score / price
    if count == 0 then error("Count computed by auto balancing for production task is zero. "..name..", "..difficulty) end
    simple_stat_task(name, count * (count_factor or 1), difficulty, localized_name, icon_str, stat_type)
end

commands.add_command("dbg_prices", "Debug: Print prices to console. ", function(_)
    setup_price_list()
    local t = {}
    for k, p in pairs(global.TaskPrototypes.price_list) do
        table.insert(t, {k, p})
    end
    table.sort(t, function(a, b) return a[1] < b[1] end)

    local s = ""
    for _, v in pairs(t) do
        local k = v[1]
        local p = v[2]
        s = s..k..": "..ModUtil.round_int(p)..", "
    end
    game.print(s)
end)

-------------------------------------------------------------------------------
-- Task Data



function TaskPrototypes.setup_tasks()
    if global.TaskPrototypes.is_set_up then return end
    global.TaskPrototypes.is_set_up = true
    TaskPrototypes.add{
        name = "ammo_belt",
        type = "SelfVerified",
        title = "Ammo Belt around your base",
        short_title = "Ammo-Belt",--"[item=piercing-rounds-magazine] [item=transport-belt]",
        description = "Build an ammo belt around your base and fill it completely with piercing rounds magazines on one side of the belt. The belt has to go around all assemblers, steam engines and furnaces at the end of the game. ",
    }

    TaskPrototypes.add{
        name = "pet_cat",
        type = "SelfVerified",
        short_title = "Pet the cat",
        description = "Pet the cat. ",
        title = "Pet the cat."
    }

    TaskPrototypes.add{
        name = "no_splitters",
        type = "SelfVerified",
        done = true,
        short_title = "No [item=splitter]",
        description = "Do not build any splitters or fast splitters.",
        balancing = { type = "restriction" }
    }

    --[[
    TaskPrototypes.add{
        name = "restrict_boilers",
        type = "SelfVerified",
        done = true,
        short_title = "≤ 15 [item=boiler]",
        description = "Build at most 15 boilers.",
        balancing = { type = "restriction" }
    }
    --]]

    TaskPrototypes.add{
        name = "restrict_furnaces",
        type = "SelfVerified",
        done = true,
        short_title = "≤ 24 [item=stone-furnace]",
        description = "Build at most 24 stone furnaces.",
        balancing = { type = "restriction" }
    }

    TaskPrototypes.add{
        name = "only_red_inserters",
        type = "SelfVerified",
        done = true,
        short_title = "No [item=inserter] [item=fast-inserter]",
        description = "You are not allowed to build any normal or fast inserters. Burner, long handed, filter, stack and stack filter inserters are allowed. ",
        balancing = { type = "restriction" }
    }

    TaskPrototypes.add{
        name = "restrict_chests",
        type = "SelfVerified",
        done = true,
        short_title = "≤ 5 chests",
        description = "You are allowed to build only a total of five chests. Build as many cars and cargo wagons as you like. ",
        balancing = { type = "restriction" }
    }

    TaskPrototypes.add{
        name = "red_iron",
        type = "SelfVerified",
        done = true,
        short_title = "[item=iron-plate] on [item=fast-transport-belt]",
        description = "Iron plates may not be transported on [item=transport-belt],[item=underground-belt] and [item=splitter]. Allowed are: fast belts, cars on yellow belt, cargo wagons. ",
        balancing = { type = "restriction" }
    }


    TaskPrototypes.add{
        name = "no_red_inserters",
        type = "SelfVerified",
        done = true,
        short_title = "No [item=long-handed-inserter]",
        description = "You are not allowed to build any long handed inserters. ",
        balancing = { type = "restriction" }
    }

    simple_stat_task("biter-spawner", 60, nil, "entity-name.biter-spawner", "[entity=biter-spawner]", "kill", "gather")
    simple_stat_task("small-biter", 800, nil, "entity-name.small-biter", "[entity=small-biter]", "kill", "gather")
    simple_stat_task("big-worm-turret", 1, nil, "entity-name.big-worm-turret", "[entity=big-worm-turret]", "kill", "gather")
    simple_stat_task("landfill", 3000, nil, "item-name.landfill", "[item=landfill]", "item", "gather")

    TaskPrototypes.add{
        name = "have-500-fish",
        type = "SelfVerified",
        done = false,
        short_title = "500 [item=raw-fish]",
        description = "Have 500 fish in your inventory at one point in the game.",
        balancing = { type = "gather" }
    }

    TaskPrototypes.add{
        name = "have-3000-wood",
        type = "SelfVerified",
        done = false,
        short_title = "3000 [item=wood]",
        description = "Have 3000 wood in your inventory at one point in the game. ",
        balancing = { type = "gather" }
    }

    --[[
    local dumb_task = function(name)
        TaskPrototypes.add{
            name=name,
            type="SelfVerified",
            short_title=name,
            description=name,
            title=name
        }
    end

    for _, name in pairs({"lorem", "ipsum", "dolor", "sit", "amet", "consectetur", "adipiscing", "elit", "sed", "do", "eiusmod", "tempor", "icididunt"}) do
        dumb_task(name)
    end
    --]]

    scored_stat_task("automation-science-pack", 2)
    scored_stat_task("logistic-science-pack", 2)
    scored_stat_task("utility-science-pack", 2)
    scored_stat_task("assembling-machine-3", 2, "entity-name.assembling-machine-3")
    scored_stat_task("production-science-pack", 2)
    scored_stat_task("fast-transport-belt", 2, "entity-name.fast-transport-belt")
    scored_stat_task("stack-inserter", 2, "entity-name.stack-inserter")
    --scored_stat_task("substation", 2, "entity-name.substation")
    scored_stat_task("personal-laser-defense-equipment", 2, "equipment-name.personal-laser-defense-equipment")
    scored_stat_task("artillery-wagon", 2, "entity-name.artillery-wagon")
    scored_stat_task("roboport", 2, "entity-name.roboport")
    scored_stat_task("solar-panel", 2, "entity-name.solar-panel")
    scored_stat_task("electric-furnace", 2, "entity-name.electric-furnace")
    scored_stat_task("piercing-rounds-magazine", 2)
    scored_stat_task("refined-concrete", 2)
    scored_stat_task("exoskeleton-equipment", 2, "equipment-name.exoskeleton-equipment")
    scored_stat_task("military-science-pack", 2)
    scored_stat_task("rocket-fuel", 2)
    scored_stat_task("stone-wall", 2, "entity-name.stone-wall")
    --[[
    scored_stat_task("laser-turret", 2)
    scored_stat_task("chemical-science-pack", 2)
    scored_stat_task("rocket-control-unit", 2)
    scored_stat_task("low-density-structure", 2)
    scored_stat_task("flying-robot-frame", 2)
    scored_stat_task("effectivity-module-2", 2)
    scored_stat_task("cluster-grenade", 2)
    scored_stat_task("uranium-rounds-magazine", 2)
    scored_stat_task("uranium-cannon-shell", 2)
    scored_stat_task("defender-capsule", 2)
    scored_stat_task("explosive-rocket", 2)
    scored_stat_task("solar-panel-equipment", 2, "equipment-name.solar-panel-equipment")
    scored_stat_task("grenade", 2)
    scored_stat_task("personal-roboport-equipment", 2, "equipment-name.personal-roboport-equipment")
    --]]
    scored_stat_task("nuclear-reactor", 4, "entity-name.nuclear-reactor")
    scored_stat_task("satellite", 4)
    scored_stat_task("nuclear-fuel", 4)
    scored_stat_task("destroyer-capsule", 4)
    scored_stat_task("rocket-silo", 4, "entity-name.rocket-silo")
    scored_stat_task("personal-roboport-mk2-equipment", 4, "equipment-name.personal-roboport-mk2-equipment")
    scored_stat_task("fusion-reactor-equipment", 4, "equipment-name.fusion-reactor-equipment")
    scored_stat_task("nuclear-reactor", 5, "entity-name.nuclear-reactor")
    scored_stat_task("satellite", 5)
    scored_stat_task("nuclear-fuel", 5)
    scored_stat_task("destroyer-capsule", 5)
    scored_stat_task("rocket-silo", 5, "entity-name.rocket-silo")
    scored_stat_task("personal-roboport-mk2-equipment", 5, "equipment-name.personal-roboport-mk2-equipment")
    scored_stat_task("fusion-reactor-equipment", 5, "equipment-name.fusion-reactor-equipment")
    scored_stat_task("spidertron", 6, "entity-name.spidertron")
    scored_stat_task("power-armor-mk2", 5, "armor.power-armor-mk2")
end

return TaskPrototypes
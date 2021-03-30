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
        ["crude-oil"] = 0.8,
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
local simple_stat_task = function(name, count, difficulty, localized_name, icon_str, stat_type)
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
        },
        difficulty = difficulty
    }
end

local scored_stat_task = function(name, difficulty, localized_name, icon_str, stat_type, count_factor)
    local difficulty_to_score = {
        100,
        300,
        1000,
        3000,
        10000,
        30000,
        100000,
        300000,
        1000000,
        3000000,
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
    if global.TaskPrototypes.is_setup then return end
    global.TaskPrototypes.is_setup = true
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
        restriction = true
    }

    TaskPrototypes.add{
        name = "restrict_boilers",
        type = "SelfVerified",
        done = true,
        short_title = "≤ 15 [item=boiler]",
        description = "Build at most 15 boilers.",
        restriction = true
    }

    TaskPrototypes.add{
        name = "restrict_furnaces",
        type = "SelfVerified",
        done = true,
        short_title = "≤ 24 [item=stone-furnace]",
        description = "Build at most 24 stone furnaces.",
        restriction = true
    }

    TaskPrototypes.add{
        name = "only_red_inserters",
        type = "SelfVerified",
        done = true,
        short_title = "No [item=inserter] [item=fast-inserter]",
        description = "You are not allowed to build any normal or fast inserters. Burner, long handed, filter, stack and stack filter inserters are allowed. ",
        restriction = true
    }

    TaskPrototypes.add{
        name = "restrict_chests",
        type = "SelfVerified",
        done = true,
        short_title = "≤ 5 chests",
        description = "You are allowed to build only a total of five chests. Build as many cars and cargo wagons as you like. ",
        restriction = true
    }

    --[[
    TaskPrototypes.add{
        name = "restrict_belt_sides",
        type = "SelfVerified",
        done = true,
        short_title = "One side [item=transport-belt]",
        description = "Items are only allowed on one side of every belt. ",
        restriction = true
    }
    --]]

    TaskPrototypes.add{
        name = "red_iron",
        type = "SelfVerified",
        done = true,
        short_title = "[item=iron-plate] on [item=fast-transport-belt]",
        description = "Iron plates may not be transported on [item=transport-belt],[item=underground-belt] and [item=splitter]. Allowed are: fast belts, cars on yellow belt, cargo wagons. ",
        restriction = true
    }


    TaskPrototypes.add{
        name = "no_red_inserters",
        type = "SelfVerified",
        done = true,
        short_title = "No [item=long-handed-inserter]",
        description = "You are not allowed to build any long handed inserters. ",
        restriction = true
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

    --simple_stat_task("small-biter", 1000, 5, "entity-name.small-biter", "[entity=small-biter]", "kill")
    scored_stat_task("automation-science-pack", 6) -- adjusted up from 800
    scored_stat_task("logistic-science-pack", 6) -- adjusted up from 350
    scored_stat_task("utility-science-pack", 6)
    scored_stat_task("assembling-machine-3", 6, "entity-name.assembling-machine-3")
    scored_stat_task("production-science-pack", 6)
    scored_stat_task("fast-transport-belt", 6, "entity-name.fast-transport-belt") -- adjusted up from 300
    scored_stat_task("stack-inserter", 6, "entity-name.stack-inserter") -- adjusted up from 40
    --scored_stat_task("substation", 6, "entity-name.substation")
    scored_stat_task("personal-laser-defense-equipment", 6, "equipment-name.personal-laser-defense-equipment")
    scored_stat_task("artillery-wagon", 6, "entity-name.artillery-wagon")
    scored_stat_task("roboport", 6, "entity-name.roboport") -- adjusted up from 4
    scored_stat_task("solar-panel", 6, "entity-name.solar-panel") -- adjusted up from 40
    scored_stat_task("electric-furnace", 6, "entity-name.electric-furnace")
    scored_stat_task("piercing-rounds-magazine", 6) -- adjusted up from 200
    scored_stat_task("refined-concrete", 6)
    scored_stat_task("exoskeleton-equipment", 6, "equipment-name.exoskeleton-equipment")
    --[[
    scored_stat_task("laser-turret", 6) -- adjusted up from 15
    scored_stat_task("chemical-science-pack", 6)
    scored_stat_task("military-science-pack", 6)
    scored_stat_task("rocket-fuel", 6)
    scored_stat_task("rocket-control-unit", 6)
    scored_stat_task("low-density-structure", 6)
    scored_stat_task("flying-robot-frame", 6)
    scored_stat_task("effectivity-module-2", 6)
    scored_stat_task("cluster-grenade", 6)
    scored_stat_task("uranium-rounds-magazine", 6)
    scored_stat_task("uranium-cannon-shell", 6)
    scored_stat_task("defender-capsule", 6) -- adjusted from 45
    scored_stat_task("explosive-rocket", 6)
    scored_stat_task("stone-wall", 6, "entity-name.stone-wall") -- adjusted up from 300
    scored_stat_task("solar-panel-equipment", 6, "equipment-name.solar-panel-equipment")
    scored_stat_task("grenade", 6) -- adjusted up from 330
    scored_stat_task("personal-roboport-equipment", 6, "equipment-name.personal-roboport-equipment") -- adjusted up from 6
    --]]
    scored_stat_task("nuclear-reactor", 8, "entity-name.nuclear-reactor") -- adjusted up from 3
    scored_stat_task("satellite", 8)
    scored_stat_task("nuclear-fuel", 8)
    scored_stat_task("destroyer-capsule", 8)
    scored_stat_task("rocket-silo", 8, "entity-name.rocket-silo")
    scored_stat_task("personal-roboport-mk2-equipment", 8, "equipment-name.personal-roboport-mk2-equipment")
    scored_stat_task("fusion-reactor-equipment", 8, "equipment-name.fusion-reactor-equipment")
    scored_stat_task("spidertron", 10, "entity-name.spidertron")
    scored_stat_task("power-armor-mk2", 9, "armor.power-armor-mk2")
end

return TaskPrototypes
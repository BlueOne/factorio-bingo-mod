local TaskPrototypes = require("src/TaskPrototypes")

local BoardCreator = {}

local random_permutation = function(n, rng)
    local numbers = {}
    local values = {}
    for i = 1, n do numbers[i] = i end
    for i = 1, n do
        local offset = rng(1, n - i + 1)
        values[i] = numbers[offset]
        table.remove(numbers, offset)
    end
    return values
end

local shuffle = function(t, perm)
    local result = {}
    for i = 1, #t do
        result[i] = t[perm[i]]
    end
    return result
end

-- TODO: This is just a stub.
BoardCreator.roll_board = function(settings) --luacheck:ignore
    local seed = 1
    if settings and settings.seed then
        seed = settings.seed
    end
    local rng = game.create_random_generator(seed)
    local tasks_all = TaskPrototypes.all()
    local tasks = {}

    local any_task = ""
    for name, _ in pairs(tasks_all) do
        table.insert(tasks, name)
        any_task = name
        if #tasks == 25 then break end
    end
    local fill = math.max(0, 25 - #tasks)
    for _ = 1, fill do
        table.insert(tasks, any_task)
    end
    local permutation = random_permutation(25, rng)
    return shuffle(tasks, permutation)
end

return BoardCreator
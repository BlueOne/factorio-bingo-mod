local TaskPrototypes = require("TaskPrototypes")

local BoardCreator = {}

-- random injective mapping from {1..k} to {1..n}
-- O(nk)
local generate_random_injection = function(n, k, rng)
    local numbers = {}
    local values = {}
    for i = 1, n do numbers[i] = i end
    for i = 1, k do
        local offset = rng(1, n - i + 1)
        values[i] = numbers[offset]
        table.remove(numbers, offset)
    end
    return values
end

local generate_random_permutation = function(n, rng)
    return generate_random_injection(n, n, rng)
end

local shuffle = function(t, perm)
    local result = {}
    for i = 1, #t do
        result[i] = t[perm[i]]
    end
    return result
end



local function get_tasks_by_balancing_category()
    if not BoardCreator.tasks_sorted then
        local tasks_sorted = {}
        BoardCreator.tasks_sorted = tasks_sorted
        for _, task in pairs(TaskPrototypes.all()) do
            if task.balancing then
                local difficulty = task.balancing.difficulty
                if difficulty then
                    if not tasks_sorted[difficulty] then tasks_sorted[difficulty] = {} end
                    table.insert(tasks_sorted[difficulty], task)
                end
                local t = task.balancing.type
                if t then
                    if not tasks_sorted[t] then tasks_sorted[t] = {} end
                    table.insert(tasks_sorted[t], task)
                end
            end
        end
    end
    return BoardCreator.tasks_sorted
end



local colorings = {
    {1},
    {
        1, 2,
        2, 1
    },
    {
        1, 2, 3,
        3, 1, 2,
        2, 3, 1,
    },
    {
        1, 2, 3, 4,
        2, 1, 4, 3,
        3, 4, 1, 2,
        4, 3, 2, 1,
    },
    {
        5, 1, 2, 3, 4,
        4, 5, 1, 2, 3,
        3, 4, 5, 1, 2,
        2, 3, 4, 5, 1,
        1, 2, 3, 4, 5,
    }
--[[
    {
        5, 1, 2, 3, 4,
        2, 5, 3, 4, 1,
        3, 4, 5, 1, 2,
        4, 2, 1, 5, 3,
        1, 3, 4, 2, 5
    }
--]]
}


-- Takes general settings for bingo board, returns specific tasks for the board
-- settings = { n=5, seed = ..., tasks_per_line=... }
-- n is the number of rows and columns,
-- seed is the rng seed
-- tasks_per_line determines which tasks are selected in every row/column. For example tasks_per_line = {9, 7, 7, 7, gather} ensures that every row/column contains a task with difficulty 9, three with difficulty 7, one of type gather.

function BoardCreator.roll_board(settings)
    local n = settings.n or settings.n_cols or #settings.tasks_per_line or 5
    local n_cols = n
    local n_rows = settings.n_rows or n

    if n_rows ~= n and settings.mode == "default" then
        error("Bad settings for board generator: n_rows ~= n_columns but mode is default!")
    end

    assert(n <= 5)
    local seed = settings.seed or 1

    game.print(settings.mode)
    local mode = settings.mode or "default"
    local rng = game.create_random_generator(seed)

    local coloring

    if mode == "default" then
        coloring = colorings[n]
    elseif mode == "rows_only" then
        coloring = {}
        for _ = 1, n_rows do
            for i = 1, n_cols do
                table.insert(coloring, i)
            end
        end
    end
    local tasks_per_line = settings.tasks_per_line


    if tasks_per_line then
        -- Select tasks. For each item in tasks_per_line we select five random tasks of this type, such that all tasks selected are distinct.
        local tasks_sorted = get_tasks_by_balancing_category()
        local task_indices_left_per_category = {}
        local tasks_selected = {}

        for category_index, category in pairs(settings.tasks_per_line) do
            assert(tasks_sorted[category], "Board Generator: Tasks with balancing property "..category.." not available!")
            if task_indices_left_per_category[category] == nil then
                task_indices_left_per_category[category] = {}
                for j = 1, #tasks_sorted[category] do task_indices_left_per_category[category][j] = j end
            end
            tasks_selected[category_index] = {}
            assert(#task_indices_left_per_category[category] >= n_cols, "Board Generator: Not enough tasks provided for category "..category..", found "..#task_indices_left_per_category[category])
            for j = 1, n_cols do
                local offset = rng(1, #task_indices_left_per_category[category])
                local task_index = task_indices_left_per_category[category][offset]
                tasks_selected[category_index][j] = tasks_sorted[category][task_index]
                table.remove(task_indices_left_per_category[category], offset)
            end
        end

        -- Assign tasks to board according to board coloring. Tasks are already shuffled in the previous step.
        local result = {}
        for i, category_index in pairs(coloring) do
            result[i] = tasks_selected[category_index][1].name
            table.remove(tasks_selected[category_index], 1)
        end

        return result
    else
        error("Board Generator: Settings Error, missing tasks_per_line value. "..serpent.block(settings))
    end

end

return BoardCreator
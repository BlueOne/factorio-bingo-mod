data:extend({
    {
        type = "string-setting",
        name = "bingo-start-preset",
        setting_type = "runtime-global",
        default_value = "unset",
        allowed_values = {"unset", "default", "rows-only", "rows-only-large", "large"},
        order = "a"
    },
    {
        type = "int-setting",
        name = "bingo-start-columns-count",
        setting_type = "runtime-global",
        default_value = 4,
        allowed_values = {1, 2, 3, 4, 5, 6},
        order = "b"
    },
    {
        type = "bool-setting",
        name = "bingo-start-enable-gather-tasks",
        setting_type = "runtime-global",
        default_value = true,
        order = "c1"
    },
    {
        type = "bool-setting",
        name = "bingo-start-enable-restriction-tasks",
        setting_type = "runtime-global",
        default_value = false,
        order = "c2"
    },

    {
        type = "bool-setting",
        name = "bingo-start-rows-only",
        setting_type = "runtime-global",
        default_value = false,
        order = "d"
    },
    {
        type = "int-setting",
        name = "bingo-start-rows-count",
        setting_type = "runtime-global",
        default_value = 3,
        allowed_values = {1, 2, 3, 4, 5, 6},
        order = "e"
    },

})
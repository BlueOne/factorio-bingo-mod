
local ModUtil = require("src/ModUtil")


ModUtil.merge{data.raw["spectator-controller"].default, {
    enemy_map_color = {0,0,0,0},
    friendly_map_color = {0,0,0,0},
    map_color = {0,0,0,0},
}}

local default_gui = data.raw["gui-style"].default

default_gui.bingo_table_item_style = util.merge{default_gui.statistics_table_item_frame, {
    left_padding = 0,
    right_padding = 0,
    bottom_padding = 0,
    graphical_set = {
        base = {
            position = {0, 17},
            corner_size = 8,
            tint = {125, 125, 125}
        },
    }
}}


default_gui.bingo_table_disabled_item_style = util.merge{default_gui.bingo_table_item_style,{
    graphical_set = { base = {
        tint = {80, 80, 80},
    } },
}}
default_gui.bingo_table_finished_item_style = util.merge{default_gui.bingo_table_item_style,{
    graphical_set = { base = {
        tint = {80, 150, 80},
    } },
}}
default_gui.bingo_table_pending_item_style = util.merge{default_gui.bingo_table_item_style,{
    graphical_set = { base = {
        tint = {150, 150, 20},
    } },
}}

--default_gui.bingo_table_disabled_item_style = default_gui.bingo_table_item_style

default_gui.bingo_table_button_style = util.merge{default_gui.button, {
    left_padding = 0,
    right_padding = 0,
    top_padding = 0,
    bottom_padding = 0,
    minimal_width = 24,
    minimal_height = 24,
    default_font_color = {0.9, 0.9, 0.9},
    default_graphical_set =
    {
        base = {
            position = {0, 17},
            corner_size = 8,
            tint = {160, 160, 160},
        }
    },
}}
default_gui.bingo_table_button_clicked_style = util.merge{default_gui.bingo_table_button_style, {
    default_font_color = {},
    default_graphical_set =
    {
      base = {position = {51, 17}, corner_size = 8, tint=ModUtil._nil},
    },
}}
require("src/color")

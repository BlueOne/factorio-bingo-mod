
local table = require("__stdlib__/stdlib/utils/table")
local ModUtil = require("src/ModUtil")

local colors = {}

local is_data = data ~= nil and data.raw ~= nil

local add_color = function(name, color)
    local frame_style_name = "frame_style_"..name
    if is_data then
        local default_gui = data.raw["gui-style"].default
        default_gui[frame_style_name] = ModUtil.copy_and_recursive_merge(default_gui.inside_deep_frame, {
            graphical_set = { base = { center = {
                position = {8, 24},
                tint = color,
            } } },
        })
    end
    colors[name] = {
        color = color,
        frame_style = frame_style_name
    }
end

add_color("dark_red", {120, 50, 50})
add_color("dark_green", {50, 120, 50})
add_color("dark_blue", {50, 50, 120})
add_color("dark_yellow", {90, 90, 50})
add_color("dark_purple", {90, 50, 90})
add_color("dark_cyan", {50, 90, 90})


return colors

local table = require("__stdlib__/stdlib/utils/table")


local default_gui = data.raw["gui-style"].default

local _nil = {}
local copy_merge = function(t1, t2)
    local result = table.deepcopy(t1)
    local merge
    merge = function(a, b)
        for k, v in pairs(b) do
            if a[k] and b[k] and type(a[k]) == type({}) then
                merge(a[k], b[k])
            elseif b[k] == _nil then
                a[k] = nil
            else
                a[k] = b[k]
            end
        end
    end
    merge(result, t2)
    return result
end

default_gui.dark_green_frame = copy_merge(default_gui.inside_deep_frame, {
    graphical_set = { base = { center = { position = {88, 28} } } },
})


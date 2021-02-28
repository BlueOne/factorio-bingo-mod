
local Util = {}

Util.table_contains = function(t, v)
    for _, val in pairs(t) do
        if val == v then return true end
    end
    return false
end
return Util
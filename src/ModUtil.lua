
local Util = {}

Util.table_contains = function(t, v)
    for _, val in pairs(t) do
        if val == v then return true end
    end
    return false
end

Util.remove_all = function(t, check_fn, ...)
    local keys = {}
    for k, v in pairs(t) do
        if check_fn(v, k, ...) then
            table.insert(keys, k)
        end
    end
    for _, k in pairs(keys) do
        table.remove(t, k)
    end
end

return Util
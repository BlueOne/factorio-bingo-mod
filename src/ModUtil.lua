
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

Util._nil = {}
Util.copy_and_recursive_merge = function(t1, t2)
    local result = table.deepcopy(t1)
    local merge
    merge = function(a, b)
        for k, v in pairs(b) do
            if a[k] and b[k] and type(a[k]) == type({}) then
                merge(a[k], b[k])
            elseif b[k] == Util._nil then
                a[k] = nil
            else
                a[k] = b[k]
            end
        end
    end
    merge(result, t2)
    return result
end

return Util


local ModUtil = {}
ModUtil.contains = function(t, v)
    for _, val in pairs(t) do
        if val == v then return true end
    end
    return false
end

ModUtil.remove_all = function(t, check_fn, ...)
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

ModUtil.copy_and_recursive_merge = function(t1, t2)
    local copy = table.deepcopy(t1)
    return util.merge{copy, t2}
end

ModUtil._nil = ModUtil._nil or {}
ModUtil.merge = function(tables)
    local ret = {}
    for i, tab in ipairs(tables) do
        for k, v in pairs(tab) do
            if (type(v) == "table") then
                if (type(ret[k] or false) == "table") then
                    ret[k] = util.merge{ret[k], v}
                else
                    ret[k] = table.deepcopy(v)
                end
            elseif v == ModUtil._nil then
                ret[k] = nil
            else
                ret[k] = v
            end
        end
    end
    return ret
end

ModUtil.round = function (num, numDecimalPlaces)
    local mult = 10^(numDecimalPlaces or 0)
    return math.floor(num * mult + 0.5) / mult
  end

ModUtil.round_int = function(i)
    if i < 15 then return ModUtil.round(i) end
    if i < 50 then
        local rmd = i % 5
        if rmd < 2.5 then return i - rmd end
        return i - rmd + 5
    end
    return ModUtil.round_int(i / 10) * 10
end

return ModUtil
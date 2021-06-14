
local inventory = {
    ["iron-plate"] = 200,
    ["pipe"] = 200,
    ["pipe-to-ground"] = 50,
    ["copper-plate"] = 200,
    ["steel-plate"] = 200,
    ["iron-gear-wheel"] = 250,
    ["transport-belt"] = 600,
    ["underground-belt"] = 40,
    ["splitter"] = 40,
    ["gun-turret"] = 8,
    ["stone-wall"] = 50,
    ["repair-pack"] = 20,
    ["inserter"] = 100,
    ["burner-inserter"] = 50,
    ["small-electric-pole"] = 50,
    ["medium-electric-pole"] = 50,
    ["big-electric-pole"] = 15,
    ["burner-mining-drill"] = 50,
    ["electric-mining-drill"] = 50,
    ["stone-furnace"] = 35,
    ["steel-furnace"] = 20,
    ["electric-furnace"] = 8,
    ["assembling-machine-1"] = 50,
    ["assembling-machine-2"] = 20,
    ["assembling-machine-3"] = 8,
    ["electronic-circuit"] = 200,
    ["fast-inserter"] = 100,
    ["long-handed-inserter"] = 100,
    ["substation"] = 10,
    ["boiler"] = 10,
    ["offshore-pump"] = 1,
    ["steam-engine"] = 20,
    ["chemical-plant"] = 20,
    ["oil-refinery"] = 5,
    ["pumpjack"] = 10,
    ["small-lamp"] = 20
}

local function get_chest_offset(n)
    local root_2 = 1.4142
    local offset_x = 0
    n = n / 2
    if n % 1 == 0.5 then
      offset_x = -1
      n = n + 0.5
    end
    local root = n ^ 0.5
    local nearest_root = math.floor(root + 0.5)
    local upper_root = math.ceil(root)
    local root_difference = math.abs(nearest_root ^ 2 - n)
    local x, y
    if nearest_root == upper_root then
      x = upper_root - root_difference
      y = nearest_root
    else
      x = upper_root
      y = root_difference
    end
    local orientation = 2 * math.pi * (45/360)
    x = x * root_2
    y = y * root_2
    local rotated_x = math.floor(0.5 + x * math.cos(orientation) - y * math.sin(orientation))
    local rotated_y = math.floor(0.5 + x * math.sin(orientation) + y * math.cos(orientation))
    return {x = rotated_x + offset_x, y = rotated_y}
end

local function set_tiles_safe(surface, tiles)
    local grass = util.get_walkable_tile()
    local grass_tiles = {}
    for k, tile in pairs (tiles) do
        grass_tiles[k] = {position = {x = (tile.position.x or tile.position[1]), y = (tile.position.y or tile.position[2])}, name = grass}
    end
    surface.set_tiles(grass_tiles, false)
    surface.set_tiles(tiles)
end

local function create_starting_chest(surface, starting_point)
    local force = game.forces.player
    if not (table_size(inventory) > 0) then return end
    local chest_name = "iron-chest"
    local prototype = game.entity_prototypes[chest_name]
    if not prototype then
    log("Starting chest "..chest_name.." is not a valid entity prototype, picking a new container from prototype list")
    for name, chest in pairs (game.entity_prototypes) do
        if chest.type == "container" then
            chest_name = name
            prototype = chest
            break
        end
    end
    end
    local size = math.ceil(prototype.radius * 2)
    local origin = {x = starting_point.x, y = starting_point.y}
    local index = 1
    local position = {x = origin.x + get_chest_offset(index).x * size, y = origin.y + get_chest_offset(index).y * size}
    local chest = surface.create_entity{name = chest_name, position = position, force = force, create_build_effect_smoke = false}
    for k, v in pairs (surface.find_entities_filtered{force = "neutral", area = chest.bounding_box}) do
      v.destroy()
    end
    local tiles = {}
    local tile_name = "refined-concrete"
    if not game.tile_prototypes[tile_name] then tile_name = util.get_walkable_tile() end
    table.insert(tiles, {name = tile_name, position = {x = position.x, y = position.y}})
    chest.destructible = false
    local items = game.item_prototypes
    for name, count in pairs (inventory) do
      if items[name] then
        local count_to_insert = math.ceil(count)
        local difference = count_to_insert - chest.insert{name = name, count = count_to_insert}
        while difference > 0 do
          index = index + 1
          position = {x = origin.x + get_chest_offset(index).x * size, y = origin.y + get_chest_offset(index).y * size}
          chest = surface.create_entity{name = chest_name, position = position, force = force, create_build_effect_smoke = false}
          for k, v in pairs (surface.find_entities_filtered{force = "neutral", area = chest.bounding_box}) do
            v.destroy()
          end
          table.insert(tiles, {name = tile_name, position = {x = position.x, y = position.y}})
          chest.destructible = false
          difference = difference - chest.insert{name = name, count = difference}
        end
      end
    end
    set_tiles_safe(surface, tiles)
end

return { create_starting_chest = create_starting_chest, inventory = inventory }

local StartingItems = {}

StartingItems.respawn_items = {
    ["modular-armor"] = 1,
    ["exoskeleton-equipment"] = 1,
    ["personal-roboport-mk2-equipment"] = 1,
    ["battery-equipment"] = 1,
    ["solar-panel-equipment"] = 11
  }


StartingItems.on_player_respawned = function(event)
    StartingItems.give_respawn_equipment(game.players[event.player_index])
end


local is_player_force = function(force)
    return force == game.forces.player
end


StartingItems.give_respawn_equipment = function(player)
    if not player.character then return end
    if not is_player_force(player.force) then return end
    local equipment = StartingItems.respawn_items
    local items = game.item_prototypes
    local list = {items = {}, armor = false, equipment = {}}
    for name, count in pairs (equipment) do
        local item = items[name]
        if item then
        if item.type == "armor" then
            local count = count
            if not list.armor then
            list.armor = item
            end
            count = count - 1
            if count > 0 then
            list.items[item] = (list.items[item] or 0) + count
            end
        elseif item.place_as_equipment_result then
            list.equipment[item] = (list.equipment[item] or 0) + count
        else
            list.items[item] = (list.items[item] or 0) + count
        end
        else
        equipment[name] = nil
        end
    end
    if list.armor then
        local stack = player.get_inventory(defines.inventory.character_armor)[1]
        stack.set_stack{name = list.armor.name}
        local grid = stack.grid
        if grid then
        for prototype, count in pairs (list.equipment) do
            local equipment = prototype.place_as_equipment_result
            for k = 1, count do
            local equipment = grid.put{name = equipment.name}
            if equipment then
                equipment.energy = equipment.max_energy
            else
                player.insert{name = prototype.name}
            end
            end
        end
        end
    end
end

return StartingItems
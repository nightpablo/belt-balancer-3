require("objects.storage")
require("objects.balancer")
require("objects.part")
require("objects.belt")
require("helper.message-handler")

-- test.lua is ~2000 lines and only used by the debug commands below, so don't load it in normal games
if debug and script.active_mods["creative-mod"] then
    require("test")
end

-- on new savegame and on adding mod to existing save
script.on_init(function()
    -- set defaults and initialize values in storage table
    storage.next_balancer_unit_number = 1
    storage.next_lane_unit_number = 1
    storage.next_belt_check = nil
    storage.balancer = {}
    storage.parts = {}
    storage.belts = {}
    storage.lanes = {}
    storage.events = {}
end)

script.on_load(reregister_on_tick)

-- If some mod is changed, check if boblogistics got added and do stuff :)
script.on_configuration_changed(
    function(e)
        ---@type ModConfigurationChangedData
        local boblogistics_changes = e.mod_changes["boblogistics"]

        if boblogistics_changes and boblogistics_changes.old_version == nil and boblogistics_changes.new_version and settings.startup["bobmods-logistics-beltoverhaul"].value == true then
            -- on boblogistics got added!
            for _, force in pairs(game.forces) do
                local technologies = force.technologies
                local recipes = force.recipes

                technologies["belt-balancer-0"].researched = technologies["belt-balancer-1"].researched
                recipes["belt-balancer-basic-belt"].enabled = technologies["belt-balancer-1"].researched
            end
        end
    end
)


-- Custom command to print out some statistics
commands.add_command("belt-balancer-statistics", "", function(e)
    local balancer_amount = table_size(storage.balancer)
    local balancer_part_amount = table_size(storage.parts)
    local balancer_input_belt_amount = 0
    local balancer_output_belt_amount = 0
    local balancer_input_lane_amount = 0
    local balancer_output_lane_amount = 0

    for _, balancer in pairs(storage.balancer) do
        for _, v in pairs(balancer.parts) do
            balancer_input_belt_amount = balancer_input_belt_amount + table_size(storage.parts[v].input_belts)
            balancer_output_belt_amount = balancer_output_belt_amount + table_size(storage.parts[v].output_belts)
        end
        balancer_input_lane_amount = balancer_input_lane_amount + table_size(balancer.input_lanes)
        balancer_output_lane_amount = balancer_output_lane_amount + table_size(balancer.output_lanes)
    end

    local output = "balancers: " .. balancer_amount ..
        "\nbalancer-parts: " .. balancer_part_amount ..
        "\nbalancer_input_belts: " .. balancer_input_belt_amount ..
        "\nbalancer_output_belts: " .. balancer_output_belt_amount ..
        "\nbalancer_input_lanes: " .. balancer_input_lane_amount ..
        "\nbalancer_output_lanes: " .. balancer_output_lane_amount
    game.get_player(e.player_index).print(output)
    print(output)
end)

-- only add this command, if `debug` is available and creative-mod is activated
-- `debug` can be activated, when calling factorio with `--instrument-mod belt-balancer`
if debug and script.active_mods["creative-mod"] then
    commands.add_command("belt-balancer-test", "", function(e)
        test_mod(e.player_index)
    end)

    commands.add_command("belt-balancer-test-logic", "", function(e)
        test_mod_logic(e.player_index)
    end)

    commands.add_command("belt-balancer-print", "", function(e)
        print("Balancer:")
        print(serpent.block(storage.balancer))
        print("Parts:")
        print(serpent.block(storage.parts))
        print("Belts:")
        print(serpent.block(storage.belts))
        print("Lanes:")
        print(serpent.block(storage.lanes))
    end)
end

-- entity types handled like belts (loader types cover every loader mod, no name matching needed)
local BELT_TYPES = {
    ["transport-belt"] = true,
    ["underground-belt"] = true,
    ["linked-belt"] = true,
    ["loader"] = true,
    ["loader-1x1"] = true,
}

function built_entity(e)
    ---@type LuaEntity
    local entity = e.entity or e.destination -- `destination` comes from on_entity_cloned

    if not entity or not entity.valid then
        return
    end

    local entity_type = entity.type
    if entity.name == "balancer-part" then
        part_functions.built(entity)
    elseif BELT_TYPES[entity_type] then
        belt_functions.built_belt(entity)
    elseif entity_type == "splitter" then
        belt_functions.built_splitter(entity)
    end
end

script.on_event(
    {
        defines.events.on_built_entity,
        defines.events.on_robot_built_entity,
        defines.events.script_raised_built,
        defines.events.on_space_platform_built_entity,
        defines.events.script_raised_revive,
        defines.events.on_entity_cloned -- fix compatability with region cloner
    },
    built_entity
)

function remove_entity(e)
    ---@type LuaEntity
    local entity = e.entity

    if not entity or not entity.valid then
        return
    end

    local entity_type = entity.type
    if entity.name == "balancer-part" then
        part_functions.remove(entity, e.buffer)
    elseif BELT_TYPES[entity_type] then
        belt_functions.remove_belt(entity)
    elseif entity_type == "splitter" then
        belt_functions.remove_splitter(entity)
    end
end

script.on_event(
    {
        defines.events.on_entity_died,
        defines.events.on_player_mined_entity,
        defines.events.on_robot_mined_entity,
        defines.events.script_raised_destroy
    },
    remove_entity
)

script.on_event({ defines.events.on_player_rotated_entity },
    function(e)
        local entity = e.entity
        if not entity.valid then
            return
        end
        local entity_type = entity.type

        if entity_type == "transport-belt" or entity_type == "loader" or entity_type == "loader-1x1" then
            belt_functions.remove_belt(entity, e.previous_direction)
            belt_functions.built_belt(entity)
        elseif entity_type == "underground-belt" then
            belt_functions.remove_belt(entity, e.previous_direction)
            belt_functions.built_belt(entity)

            -- Neighbour is only the other end (`neighbours` was replaced by `underground_belt_neighbour` in 2.1)
            local neighbour = entity.underground_belt_neighbour
            if neighbour and neighbour.valid then
                -- rotating one end turns the whole pair by 180 degrees (16 directions since 2.0)
                local previous_direction = (neighbour.direction + defines.direction.south) % 16
                belt_functions.remove_belt(neighbour, previous_direction)
                belt_functions.built_belt(neighbour)
            end
        elseif entity_type == "splitter" then
            belt_functions.remove_splitter(entity, e.previous_direction)
            belt_functions.built_splitter(entity)
        end
    end
)

script.on_event(defines.events.on_tick, function()
    local unit_number = storage.next_belt_check
    local belt = storage.belts[unit_number]

    -- check if belt direction got changed
    if belt and belt.entity.valid and belt.direction ~= belt.entity.direction then
        -- remove belt and readd it
        if belt.type == "splitter" then
            belt_functions.remove_splitter(belt.entity, belt.direction, unit_number, belt.entity.surface, belt.position)
            belt_functions.built_splitter(belt.entity)
        else
            belt_functions.remove_belt(belt.entity, belt.direction, unit_number, belt.entity.surface, belt.position)
            belt_functions.built_belt(belt.entity)
        end
    end

    storage.next_belt_check, _ = next(storage.belts, unit_number)
end)

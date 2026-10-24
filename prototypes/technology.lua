require("helper.technology_calc")

data:extend {
    {
        type = "technology",
        name = "belt-balancer-1",
        icon = "__belt-balancer-3__/graphics/icons/balancer.png",
        icon_size = 200,
        effects = {
            {
                type = "unlock-recipe",
                recipe = "belt-balancer-normal-belt",
            }
        },
        prerequisites = { "logistics" },
        unit = {
            count = data.raw.technology["logistics"].unit.count,
            ingredients = data.raw.technology["logistics"].unit.ingredients,
            time = data.raw.technology["logistics"].unit.time
        },
    },
    {
        type = "technology",
        name = "belt-balancer-2",
        icon = "__belt-balancer-3__/graphics/icons/balancer.png",
        icon_size = 200,
        effects = {
            {
                type = "unlock-recipe",
                recipe = "belt-balancer-fast-belt",
            }
        },
        prerequisites = { "logistics-2", "belt-balancer-1" },
        unit = {
            count = technology.calc_cost_round(data.raw.technology["logistics-2"].unit.count, 10),
            ingredients = data.raw.technology["logistics-2"].unit.ingredients,
            time = data.raw.technology["logistics-2"].unit.time
        },
    },
    {
        type = "technology",
        name = "belt-balancer-3",
        icon = "__belt-balancer-3__/graphics/icons/balancer.png",
        icon_size = 200,
        effects = {
            {
                type = "unlock-recipe",
                recipe = "belt-balancer-express-belt",
            }
        },
        prerequisites = { "logistics-3", "belt-balancer-2" },
        unit = {
            count = technology.calc_cost_round(data.raw.technology["logistics-3"].unit.count, 25),
            ingredients = data.raw.technology["logistics-3"].unit.ingredients,
            time = data.raw.technology["logistics-3"].unit.time
        },
    }
}

if mods["space-age"] then
    data:extend {
        {
            type = "technology",
            name = "belt-balancer-4",
            icon = "__belt-balancer-3__/graphics/icons/balancer.png",
            icon_size = 200,
            effects = {
                {
                    type = "unlock-recipe",
                    recipe = "belt-balancer-turbo-belt",
                }
            },
            prerequisites = { "turbo-transport-belt", "belt-balancer-3" },
            unit = {
                count = technology.calc_cost_round(data.raw.technology["turbo-transport-belt"].unit.count, 50),
                ingredients = data.raw.technology["turbo-transport-belt"].unit.ingredients,
                time = data.raw.technology["turbo-transport-belt"].unit.time
            },
        }
    }
end
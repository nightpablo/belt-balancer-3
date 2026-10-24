require("helper.table")

---register_on_tick
---@param tick number
---@param balancer_index uint the balancer that runs on this tick
function register_on_tick(tick, balancer_index)
    if storage.events[tick] then
        table.insert(storage.events[tick], balancer_index)
    else
        storage.events[tick] = {}
        table.insert(storage.events[tick], balancer_index)

        script.on_nth_tick(tick, on_tick)
    end
end

---unregister_on_tick
---@param balancer_index uint
function unregister_on_tick(balancer_index)
    for tick, arr in pairs(storage.events) do
        if remove_from_table(arr, balancer_index) then
            if #storage.events[tick] == 0 then
                -- unregister this tick
                script.on_nth_tick(tick, nil)
                storage.events[tick] = nil
            end
        end
    end
end

function on_tick(e)
    local balancers = storage.events[e.nth_tick]
    if not balancers then
        return
    end
    for _, balancer_id in pairs(balancers) do
        balancer_functions.run(balancer_id)
    end
end

function reregister_on_tick()
    -- reregister balancer
    for tick, _ in pairs(storage.events) do
        script.on_nth_tick(tick, on_tick)
    end
end

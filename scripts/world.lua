local MAX_LEVEL = 8
local WATER_ID = block.index("base:water")
local AIR_ID = block.index("base:air")

local active = {}
local next_tick = {}

local function key(x, y, z)
    return x .. "," .. y .. "," .. z
end

local function enqueue(tbl, x, y, z)
    local k = key(x, y, z)
    if not tbl[k] then
        tbl[k] = {x = x, y = y, z = z}
    end
end

local function get_level(x, y, z)
    if block.get(x, y, z) ~= WATER_ID then return 0 end
    return block.get_user_bits(x, y, z, 0, 8) or 0
end

local function set_level(x, y, z, level)
    level = math.min(level, MAX_LEVEL)
    local current = get_level(x, y, z)

    if current == level then return false end  -- уровень не изменился, не трогаем

    if level <= 0 then
        block.set(x, y, z, AIR_ID, 0)
        block.set_user_bits(x, y, z, 0, 8, 0)
    else
        if block.get(x, y, z) ~= WATER_ID then
            block.set(x, y, z, WATER_ID, 0)
        end
        block.set_user_bits(x, y, z, 0, 8, level)
    end

    return true  -- уровень изменился
end

local function neighbors(x, y, z)
    return {
        {x + 1, y, z},
        {x - 1, y, z},
        {x, y, z + 1},
        {x, y, z - 1},
    }
end

local function update_block(x, y, z)
    local level = get_level(x, y, z)
    if level == 0 then return end

    -- Падение вниз
    if block.is_replaceable_at(x, y - 1, z) then
        if set_level(x, y - 1, z, MAX_LEVEL) then
            enqueue(next_tick, x, y - 1, z)
        end
        if set_level(x, y, z, level - 1) then
            enqueue(next_tick, x, y, z)
        end
        return
    end

    -- Растекание по сторонам
    for _, n in ipairs(neighbors(x, y, z)) do
        local nx, ny, nz = n[1], n[2], n[3]
        if block.is_replaceable_at(nx, ny, nz) and level > 1 then
            local nlevel = get_level(nx, ny, nz)
            if nlevel + 2 <= level then
                if set_level(nx, ny, nz, level - 1) then
                    enqueue(next_tick, nx, ny, nz)
                end
                if set_level(x, y, z, level - 1) then
                    enqueue(next_tick, x, y, z)
                end
            end
        end
    end
end

function on_world_tick()
    local current = active
    active = next_tick
    next_tick = {}

    for _, pos in pairs(current) do
        update_block(pos.x, pos.y, pos.z)
    end
end

function on_block_placed(blockid, x, y, z, playerid)
    if blockid == WATER_ID then
        set_level(x, y, z, MAX_LEVEL)
        enqueue(active, x, y, z)
    else
        enqueue(active, x, y + 1, z)
        for _, n in ipairs(neighbors(x, y, z)) do
            enqueue(active, n[1], n[2], n[3])
        end
    end
end

function on_block_broken(blockid, x, y, z, playerid)
    enqueue(active, x, y + 1, z)
    for _, n in ipairs(neighbors(x, y, z)) do
        enqueue(active, n[1], n[2], n[3])
    end
end

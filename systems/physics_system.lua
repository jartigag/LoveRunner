local bump = require('../lib/bump')
local entities = require "entities"

local debugEnabled = false

local physicsSystem = {
    bumpWorld = nil,
    ss = nil,
    isGameOver = false
}

function physicsSystem.init(soundSystem)
    debug("Physics System - Init")
    physicsSystem.bumpWorld = bump.newWorld(64)
    -- Walls left and right of the world
    -- We need an extra pixel on each side for ladders on the edge of the map (eg level 4)
    physicsSystem.bumpWorld:add(entities.newBrick(1, 1), -1, -1, 1, 256)
    physicsSystem.bumpWorld:add(entities.newBrick(1, 1), 449, 0, 1, 256)
    physicsSystem.ss = soundSystem
end

function physicsSystem.add(entity)
    if not physicsSystem.bumpWorld:hasItem(entity) then
        physicsSystem.bumpWorld:add(entity, entity.x, entity.y, 16, 16)
        debug(("Adding entity to x=%d y=%d"):format(entity.x, entity.y))
    end
end

function physicsSystem.remove(entity)
    if physicsSystem.bumpWorld:hasItem(entity) then
        physicsSystem.bumpWorld:remove(entity, entity.x, entity.y, 16, 16)
        debug(("Removing entity to x=%d y=%d"):format(entity.x, entity.y))
    end
end

function physicsSystem.clear()
    for _, e in ipairs(physicsSystem.bumpWorld:getItems()) do
        physicsSystem.remove(e)
    end

    physicsSystem.bumpWorld = nil
    physicsSystem.ss = nil
end

function physicsSystem.move(entity, inputX, inputY)
    oldY = entity.y
    local items, len = physicsSystem.bumpWorld:queryRect(entity.x, entity.y + 16, 16, 1, groundFilter)
    if len == 0 then
        -- TODO: player is not falling completely to the ground because move() rounds it
        inputY = 0.25
    end
    local actualX, actualY, cols, len = physicsSystem.bumpWorld:move(entity, entity.x + inputX, entity.y + inputY, collisionFilter)
    entity.x = actualX
    entity.y = actualY

    -- Process collisions
    if #cols > 0 then

        debug(("Had %d collisions"):format(#cols))
        for i, col in pairs(cols) do

            local collidedEntity = col.other
            debug((" - Collision type: %s"):format(col.type))
            debug((" -    Entity type: %s"):format(collidedEntity.type))

            if collidedEntity.type == "rope" and inputY <= 0 then
                entity.y = collidedEntity.y - 1
            end

            if collidedEntity.type == "ladder" or collidedEntity.type == "endladder" then
                if not(entity.vy == 0) then
                    local w = 20
                    local h = 20
                    local l = entity.x
                    local t = entity.y
                    local items, len = physicsSystem.bumpWorld:queryRect(l,t,w,h)
                    local nearest = nil
                    for _,i in ipairs(items) do
                        if i.type == "ladder" or i.type == "endladder" then
                            if nearest == nil then
                                nearest = i
                            elseif math.abs( i.x - entity.x ) < math.abs( nearest.x - entity.x ) then
                                nearest = i
                            end
                        end
                    end
                    if not(nearest == nil) then
                        entity.x = nearest.x
                    end
                end
            end

            if entity.type == "player" and collidedEntity.type == "heart" then
                collidedEntity.x = -10000
                collidedEntity.y = -10000
                entity.hearts = entity.hearts + 1
                physicsSystem.ss.play('getHeart')
                debug(("player has %d hearts"):format(entity.hearts))
                physicsSystem.remove(collidedEntity)
            end

            if entity.type == "enemy" and collidedEntity.type == "player" then
                physicsSystem.isGameOver = true
            end
        end

    end
end

function physicsSystem.dig(player, offset)
    local actualX, actualY, cols, len = physicsSystem.bumpWorld:check(player, player.x+8 + offset, player.y+16)
    --                                                                               ^^^ middle of player ^^^ under the player
    if #cols > 0 then
        if cols[1]["other"].type=="brick" then
            cols[1]["other"].y = 500 --TODO: it should just hide without changing `.y`
            cols[1]["other"].time_to_appear=10
        end
    end
end

function collisionFilter(item, other)
    if other.type == "ladder" or other.type == "endladder" or other.type == "heart" or other.type == "rope" then
        return "cross"
    end
    return "slide"
end

function groundFilter(item)
    return not (item.type == "heart")
end

function debug(text)
    if (debugEnabled) then print(text) end
end

return physicsSystem

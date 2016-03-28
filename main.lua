-- Libraries
local HC        = require 'hardoncollider'
local Gamestate = require 'hump.gamestate'
local Class     = require 'hump.class'
local Vector    = require 'hump.vector'
local Shapes    = require 'hardoncollider.shapes'

-- LÖVE shortcuts
local gfx = love.graphics
local key = love.keyboard
local sin = math.sin
local cos = math.cos
local rnd = math.random
local pi  = math.pi

-- Game states
local Menu  = {}
local Game  = {}
local Pause = {}

-- Globals
local Debug    = true
local Collider = HC.new(150)
local W        = gfx.getWidth()
local H        = gfx.getHeight()

-- --------------------------------------------------------------------------

Point = Class{
    init = function(self, x, y)
        self.x = x
        self.y = y
    end,
    x=0, y=0
}

-- --------------------------------------------------------------------------

Ship = Class{
    init = function(self, position, rotation, configuration)
        self.rotation = rotation or pi/-2
        self:setConfiguration(configuration)
        self.shape = Collider:polygon(unpack(self.vertices))
        self.shape:moveTo(W/2, H/2)
        self.shape.parent = self
    end,
    type = 'Ship',
    velocity = Vector(),
    tweenVertices = {},
}

Ship.adventurer = {
    thrustPower      = 4,
    retroFactor      = -0.5,
    weaponTimerDelay = 0.25,
    weaponTimer      = 0.25,
    weaponPower      = 2,
    vertices         = { 20,-2, 20,2,
        5,5, -5,10, -10,10,
        -5,2, -5,-2,
        -10,-10, -5,-10, 5,-5 },
}

Ship.speedster = {
    thrustPower      = 6,
    retroFactor      = -0.75,
    weaponTimerDelay = 0.35,
    weaponTimer      = 0.35,
    weaponPower      = 1,
    vertices         = { 23,-1, 23,1,
        5,3, -3,7, -12,10,
        -8,3, -8,-3,
        -12,-10, -3,-7, 5,-3 },
}

Ship.warrior = {
    thrustPower      = 2,
    retroFactor      = -0.75,
    weaponTimerDelay = 0.15,
    weaponTimer      = 0.15,
    weaponPower      = 3,
    vertices         = { 16,-3, 16,3,
        7,8, 5,11, -5,12,
        -3,1, -3,-1,
        -5,-12, 5,-11, 7,-8 },
}

function Ship:update(dt)
    local x,y = self.shape:center()
    if self.isTransforming and #self.tweenVertices > 0 then
        local vertices = self.tweenVertices[1]
        self.shape = Collider:polygon(unpack(vertices))
        self.shape:moveTo(x, y)
        table.remove(self.tweenVertices, 1)
    else
        self.isTransforming = false
    end
    self.shape:move(self.velocity.x, self.velocity.y)
    self:updatePosition()
    self.shape:setRotation(self.rotation)
    self.weaponTimer = self.weaponTimer - dt
end

function Ship:draw()
    gfx.reset()
    self.shape:draw('line')

    if Debug then
        gfx.setColor(255,255,0)
        local ox,oy = self.shape:center()
        gfx.line(ox,oy, ox+50*cos(self.rotation),oy+50*sin(self.rotation))

        gfx.setColor(255,0,0)
        -- Bounding box
        local bx1,by1, bx2,by2 = self.shape:bbox()
        gfx.rectangle('line', bx1,by1, bx2-bx1,by2-by1)
        -- Movement vector
        gfx.line(ox,oy, ox+self.velocity.x*20,oy+self.velocity.y*20)

        gfx.print("Thrust: " .. self.thrustPower, 100, 100)

    end
end

function Ship:thrust(dt)
    if not self.isTransforming then
        local r      = self.rotation
        local p      = self.thrustPower
        local deltaV = Vector(p*cos(r), p*sin(r))

        self.velocity = self.velocity + deltaV * dt
    end
end

function Ship:retro(dt)
    if not self.isTransforming then
        local r      = self.rotation
        local p      = self.thrustPower
        local rf     = self.retroFactor
        local deltaV = Vector(p*cos(r)*rf, p*sin(r)*rf)

        self.velocity = self.velocity + deltaV * dt
    end
end

function Ship:rotate(dt, theta)
    self.rotation = self.rotation + theta * dt
end

function Ship:updatePosition()
    local x,y = self.shape:center()
    if (x > W) then x = x - W end
    if (x < 0) then x = W - x end
    if (y > H) then y = y - H end
    if (y < 0) then y = H - y end
    self.shape:moveTo(x,y)
end

function Ship:shoot(dt)
    local bullet = nil
    if not self.isTransforming then
        if self.weaponTimer < 0 then
            local x,y = self.shape:center()
            local r = self.shape:rotation()
            local bulletPosition = Point(x + 20 * cos(r), y + 20 * sin(r))
            bullet = Bullet(bulletPosition, r, self.weaponPower)
            self.weaponTimer = self.weaponTimerDelay
        end
    end
    return bullet
end

function Ship:transform(toConfiguration)
    self.isTransforming = true

    local sourceVertices = self.configuration.vertices
    local targetVertices = toConfiguration.vertices
    local tweenVertices  = {}
    local steps          = 30

    for i = 1, steps do -- 30 frames of animimation, about half a second
                        -- at 60fps?
        local vertices = {}
        for j = 1, #targetVertices do
            local perStepDifference = (targetVertices[j] - sourceVertices[j])
                  / steps
            vertices[j] = sourceVertices[j] + (perStepDifference * i)
        end
        tweenVertices[i] = vertices
    end
    self.tweenVertices = tweenVertices
    self:setConfiguration(toConfiguration)
end

function Ship:setConfiguration(configuration)
    self.configuration    = configuration

    self.vertices         = self.configuration.vertices
    self.thrustPower      = self.configuration.thrustPower
    self.retroFactor      = self.configuration.retroFactor
    self.weaponTimerDelay = self.configuration.weaponTimerDelay
    self.weaponTimer      = self.configuration.weaponTimer
    self.weaponPower      = self.configuration.weaponPower
end

-- --------------------------------------------------------------------------

Bullet = Class{
    init = function(self, position, direction, power)
        self.shape    = Collider:circle(position.x, position.y, 1)
        self.shape:rotate(direction)
--        self.direction = direction
        self.shape.parent = self
        self.power    = power
        self.velocity = Vector()
    end,
    type = 'Bullet',
    speed = 500,
    lifeTimer = 1.5,
}

function Bullet:update(dt)
    local r = self.shape:rotation()
    local v = self.speed
    self.lifeTimer  = self.lifeTimer - dt
    self.shape:move(v * dt * cos(r), v * dt * sin(r))
    self:updatePosition()
end

function Bullet:draw()
    gfx.reset()
    self.shape:draw('line')

    if Debug then
        local ox,oy = self.shape:center()
        local r = self.shape:rotation()
        gfx.setColor(255,0,0)
        -- Bounding box
        local bx1,by1, bx2,by2 = self.shape:bbox()
        gfx.rectangle('line', bx1,by1, bx2-bx1,by2-by1)
        -- Movement vector
        gfx.line(ox,oy, ox + self.speed * cos(r),oy + self.speed * sin(r))
    end
end

function Bullet:updatePosition()
    local x,y = self.shape:center()
    if (x > W) then x = x - W end
    if (x < 0) then x = W - x end
    if (y > H) then y = y - H end
    if (y < 0) then y = H - y end
    self.shape:moveTo(x,y)
end

function Bullet:die()
    self.lifeTimer = 0
end

-- --------------------------------------------------------------------------

Asteroid = Class{
    init = function(self, position, speed)
        self.direction = rnd() * 2 * pi
        self.rotation  = rnd() * 2 - 1
        self.speed     = speed
        self.velocity  = Vector(
            self.speed * cos(self.direction),
            self.speed * sin(self.direction)
        )
        self.vertices  = self:generateVertices()
        self.shape     = Collider:polygon(unpack(self.vertices))
        self.shape:moveTo(0,0)
        self.shape.parent = self
    end,
    type = 'Asteroid',
    life = 20 + rnd(10),
}

function Asteroid:update(dt)
    self.shape:move(self.velocity.x, self.velocity.y)
    self.shape:rotate(self.rotation * dt)
    self:updatePosition()
end

function Asteroid:draw()
    gfx.reset()
    self.shape:draw('line')

    if Debug then
        local ox,oy = self.shape:center()
        local r = self.shape:rotation()
        gfx.setColor(255,0,0)
        -- Bounding box
        local bx1,by1, bx2,by2 = self.shape:bbox()
        gfx.rectangle('line', bx1,by1, bx2-bx1,by2-by1)
        -- Movement vector
        gfx.line(ox,oy, ox + self.velocity.x,oy + self.velocity.y)
        -- Life
        gfx.print(self.life, ox,oy)
    end
end

function Asteroid:updatePosition()
    local x,y = self.shape:center()
    if (x > W) then x = x - W end
    if (x < 0) then x = W - x end
    if (y > H) then y = y - H end
    if (y < 0) then y = H - y end
    self.shape:moveTo(x,y)
end

function Asteroid.generateVertices()
    local vertexCount = 8 + rnd(6)
    local vertices = {}
    for i = 1, vertexCount do
        local r = 30 + rnd(10)
        table.insert(vertices, r * cos(2 * pi * (i-1)/vertexCount))
        table.insert(vertices, r * sin(2 * pi * (i-1)/vertexCount))
    end
    return vertices
end

-- --------------------------------------------------------------------------

function Menu:update(dt) --[[ intentionally blank --]] end

function Menu:draw()
    gfx.setColor(255,255,255)
    gfx.print('Press <space> to start', 10, 10)
    gfx.print('Press <escape> to quit', 10, 580)
end

function Menu:keyreleased(key)
    if key == 'escape' then love.event.push('quit') end
    if key == 'space' then Gamestate.switch(Game) end
end

-- --------------------------------------------------------------------------

function Game:init()
    local startPos = Point(W/2, H/2) -- centre of the screen
    self.ship      = Ship(startPos, pi/-2, Ship.adventurer) -- rotate 90° CCW
    self.bullets   = {}
    self.asteroids = {}
    for i = 1, 10 do
        table.insert(self.asteroids, Asteroid(
            Point(rnd(0,1) * W, rnd(0,1) * H),
            rnd()+0.25
        ))
    end
end

function Game:enter()
    self.gameTime = 0
end

function Game:update(dt)
    self.gameTime = self.gameTime + dt

    if key.isDown('z') then self.ship:rotate(dt, -2) end
    if key.isDown('x') then self.ship:rotate(dt,  2) end
    if key.isDown('k') then self.ship:thrust(dt) end
    if key.isDown('m') then self.ship:retro(dt) end
    if key.isDown('l') then
        local bullet = self.ship:shoot(dt)
        if bullet then self.bullets[#self.bullets+1] = bullet end
    end
    if key.isDown('space') then
        -- brake
        -- ship:brake(dt)
    end

    self.ship:update(dt)

    for k, asteroid in pairs(self.asteroids) do
        for shape, delta in pairs(Collider:collisions(asteroid.shape)) do
            if shape and shape.parent then
                if shape.parent.type == 'Bullet' then
                    local p = shape.parent.power
                    -- asteroid loses some life, depending on the power of the
                    -- bullet
                    asteroid.life = asteroid.life - p * dt
                    -- alter the course of the asteroid, but just a bit
                    -- @TODO change this so that it's not just the velocity, but
                    -- the rotational angle (in proportion to the angle of
                    -- incidence)
                    asteroid.velocity = Vector(
                        asteroid.velocity.x + (delta.x * dt * p/50),
                        asteroid.velocity.y + (delta.y * dt * p/50)
                    )
                    shape.parent:die()
                end
                if shape.parent.type == 'Ship' then
                    asteroid.life = asteroid.life - 10 * dt
                    asteroid.velocity, shape.parent.velocity = shape.parent.velocity/2, asteroid.velocity*2
                    shape.parent:update(dt)
                end
            end
        end
        asteroid:update(dt)
        if asteroid.life <= 0 then
            table.remove(self.asteroids, k)
        end
    end

--    for k, asteroid in pairs(self.asteroids) do
--        asteroid:update(dt)
--        if (asteroid.shape:collidesWith(self.ship.shape)) then
--            asteroid.life = 0
--        end
--        if asteroid.life <= 0 then
--            table.remove(self.asteroids, k)
--        end
--    end

    for k, bullet in pairs(self.bullets) do
        if (bullet.lifeTimer <= 0) then
            table.remove(self.bullets, k)
        end
        bullet:update(dt)
    end

    self.ship:update(dt)

end

function Game:draw()
    for i = 1, #self.asteroids do self.asteroids[i]:draw() end
    for i = 1, #self.bullets   do self.bullets[i]:draw()   end
    self.ship:draw()

    gfx.reset()
    gfx.print('Playing game, for ' .. string.format('%.3f', self.gameTime)
           .. ' seconds...', 10, 10)
    gfx.print('Press <escape> to quit to menu', 10, 580)
end

function Game:keyreleased(key)
    if key == 'escape' then Gamestate.switch(Menu) end
    if key == 'p' then return Gamestate.push(Pause) end
    if key == 'tab' then Debug = not Debug end
    if key == 't' then
        if not self.ship.isTransforming then
            local newConfiguration = Ship.adventurer
            if self.ship.configuration == Ship.adventurer then
                newConfiguration = Ship.speedster
            elseif self.ship.configuration == Ship.speedster then
                newConfiguration = Ship.warrior
            end
            self.ship:transform(newConfiguration)
        end
    end
end

-- --------------------------------------------------------------------------

function Pause:enter(from)
    self.from = from
end

function Pause:update(dt) --[[ intentionally blank --]] end

function Pause:draw()
    Game:draw()
    gfx.reset()
    gfx.print('Paused', 10, 30)
    gfx.print('Press <p> to resume', 10, 560)
end

function Pause:keyreleased(key)
    if key == 'escape' then Gamestate.switch(Menu) end
    if key == 'p'      then return Gamestate.pop() end
end

-- --------------------------------------------------------------------------

function love.load()
    Gamestate.registerEvents()
    Gamestate.switch(Menu)
end

function love.update(dt) --[[ intentionally blank --]] end

function love.draw()     --[[ intentionally blank --]] end

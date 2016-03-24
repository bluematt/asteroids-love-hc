-- Libraries
local HC = require 'hardoncollider'
local Gamestate = require 'hump.gamestate'
local Class = require 'hump.class'
local Vector = require 'hump.vector'
local Shapes = require 'hardoncollider.shapes'

-- Game states
local Menu = {}
local Game = {}
local Pause = {}

-- Shortcuts
local gfx = love.graphics
local key = love.keyboard

-- Globals
local Debug = true
local Collider = HC.new(150)

-- ----------------------------------------------------------------------------

Point = Class{
    init = function(self, x, y)
        self.x = x
        self.y = y
    end,
    x=0, y=0
}

-- ----------------------------------------------------------------------------

Ship = Class{
    init = function(self, position, rotation)
        self.position = position or Point(gfx.getWidth()/2, gfx.getHeight()/2)
        self.rotation = rotation or math.pi/-2
        self.shape = Shapes.newPolygonShape(20,-2, 20,2, 5,5, -5,10, -10,10, -5,0, -10,-10, -5,-10, 5,-5)
    end,
    velocity = Vector(),
    thrustPower = 4,
    retroFactor = -0.5,
    weaponTimerDelay = 0.2,
    weaponTimer = 0.2,
}

function Ship:update(dt)
    self.position.x = self.position.x + self.velocity.x
    self.position.y = self.position.y + self.velocity.y
    self:updatePosition()
    self.shape:setRotation(self.rotation)
    self.shape:moveTo(self.position.x, self.position.y)
    self.weaponTimer = self.weaponTimer - dt
end

function Ship:draw()
    gfx.reset()
    self.shape:draw('line')

    if Debug then
        gfx.setColor(255,255,0)
        local ox,oy = self.shape:center()
        gfx.line(ox,oy, ox+50*math.cos(self.rotation),oy+50*math.sin(self.rotation))

        gfx.setColor(255,0,0)
        -- Bounding box
        local bx1,by1, bx2,by2 = self.shape:bbox()
        gfx.rectangle('line', bx1,by1, bx2-bx1,by2-by1)
        -- Movement vector
        gfx.line(ox,oy, ox+self.velocity.x*20,oy+self.velocity.y*20)

    end
end

function Ship:thrust(dt)
    local deltaV = Vector(
        math.cos(self.rotation) * self.thrustPower,
        math.sin(self.rotation) * self.thrustPower
    )
    self.velocity = self.velocity + deltaV * dt
end

function Ship:retro(dt)
    local deltaV = Vector(
        math.cos(self.rotation) * self.thrustPower * self.retroFactor,
        math.sin(self.rotation) * self.thrustPower * self.retroFactor
    )
    self.velocity = self.velocity + deltaV * dt
end

function Ship:rotate(dt, theta)
    self.rotation = self.rotation + theta * dt
end

function Ship:updatePosition()
    if (self.position.x > gfx.getWidth()) then
        self.position.x = self.position.x - gfx.getWidth()
    end
    if (self.position.x < 0) then
        self.position.x = gfx.getWidth() - self.position.x
    end
    if (self.position.y > gfx.getHeight()) then
        self.position.y = self.position.y - gfx.getHeight()
    end
    if (self.position.y < 0) then
        self.position.y = gfx.getHeight() - self.position.y
    end
end

function Ship:shoot(dt)
    local bullet = nil
    if self.weaponTimer < 0 then
        local bulletPosition = Point(self.position.x + 20 * math.cos(self.rotation), self.position.y + 20 * math.sin(self.rotation))
        bullet = Bullet(bulletPosition, self.rotation)
        self.weaponTimer = self.weaponTimerDelay
    end
    return bullet
end

-- ----------------------------------------------------------------------------

Bullet = Class{
    init = function(self, position, rotation)
        self.position = position
        self.rotation = rotation
        self.shape = Shapes.newCircleShape(self.position.x, self.position.y, 1)
    end,
    speed = 5,
    lifeTimer = 1.5
}

function Bullet:update(dt)
    self.velocity = Vector(
        self.speed * math.cos(self.rotation),
        self.speed * math.sin(self.rotation)
    )
    self.lifeTimer = self.lifeTimer - dt
    self.position.x = self.position.x + self.velocity.x
    self.position.y = self.position.y + self.velocity.y
    self:updatePosition()
    self.shape:moveTo(self.position.x, self.position.y)
end

function Bullet:draw()
    gfx.reset()
    self.shape:draw('line')

    if Debug then
        local ox,oy = self.shape:center()
        gfx.setColor(255,0,0)
        -- Bounding box
        local bx1,by1, bx2,by2 = self.shape:bbox()
        gfx.rectangle('line', bx1,by1, bx2-bx1,by2-by1)
        -- Movement vector
        gfx.line(ox,oy, ox+self.velocity.x*20,oy+self.velocity.y*20)

    end
end

function Bullet:updatePosition()
    if (self.position.x > gfx.getWidth()) then
        self.position.x = self.position.x - gfx.getWidth()
    end
    if (self.position.x < 0) then
        self.position.x = gfx.getWidth() - self.position.x
    end
    if (self.position.y > gfx.getHeight()) then
        self.position.y = self.position.y - gfx.getHeight()
    end
    if (self.position.y < 0) then
        self.position.y = gfx.getHeight() - self.position.y
    end
end

-- ----------------------------------------------------------------------------

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

-- ----------------------------------------------------------------------------

function Game:init()
    local startPosition = Point(gfx.getWidth()/2, gfx.getHeight()/2) -- centre of the screen
    self.ship = Ship(startPosition, math.pi/-2) -- rotate 90° CCW
    self.bullets = {}
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
        if bullet then
            self.bullets[#self.bullets+1] = bullet
        end
    end
    if key.isDown('space') then
        -- brake
        -- ship:brake(dt)
    end

    self.ship:update(dt)
    for k, bullet in pairs(self.bullets) do
        bullet:update(dt)
        if (bullet.lifeTimer < 0) then
            table.remove(self.bullets, k)
        end
    end
end

function Game:draw()
    self.ship:draw()
    for i = 1, #self.bullets do
        self.bullets[i]:draw()
    end
    gfx.reset()
    gfx.print('Playing game, for ' .. string.format('%.3f', self.gameTime) .. ' seconds...', 10, 10)
    gfx.print('Press <escape> to quit to menu', 10, 580)
end

function Game:keyreleased(key)
    if key == 'escape' then Gamestate.switch(Menu) end
    if key == 'p' then return Gamestate.push(Pause) end
    if key == 'tab' then Debug = not Debug end
end

-- ----------------------------------------------------------------------------

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
    if key == 'p' then return Gamestate.pop() end
end

-- ----------------------------------------------------------------------------

function love.load()
    Gamestate.registerEvents()
    Gamestate.switch(Menu)
end

function love.update(dt) --[[ intentionally blank --]] end

function love.draw() --[[ intentionally blank --]] end

-- Libraries
local HC = require 'hardoncollider'
local Gamestate = require "hump.gamestate"

-- Game states
local Menu = {}
local Game = {}
local Pause = {}

-- Shortcuts
local gfx = love.graphics

-- Globals
local Debug = true

-- ----------------------------------------------------------------------------

function Menu:update(dt) --[[ intentionally blank --]] end

function Menu:draw()
    gfx.print('Press <space> to start', 10, 10)
    gfx.print('Press <escape> to quit', 10, 580)
end

function Menu:keyreleased(key)
    if key == 'escape' then love.event.push('quit') end
    if key == 'space' then Gamestate.switch(Game) end
end

-- ----------------------------------------------------------------------------

function Game:init()
    self.collider = HC.new(150)

    self.ship = self.collider:rectangle(100,100,20,10)
end

function Game:enter()
    self.gameTime = 0
end

function Game:update(dt)
    self.gameTime = self.gameTime + dt
    self.ship:rotate(0.1)
--    if Debug then
--        local x1,y1, x2,y2 = self.ship:bbox()
--        gfx.setColor(255,0,0)
--        gfx.rectangle('line', x1,y1, x2-x1,y2-y1)
--    end
end

function Game:draw()
    self.ship:draw('line')
    gfx.print('Playing game, for ' .. string.format('%.3f', self.gameTime) .. ' seconds...', 10, 10)
    gfx.print('Press <escape> to quit to menu', 10, 580)
end

function Game:keyreleased(key)
    if key == 'escape' then Gamestate.switch(Menu) end
    if key == 'p' then return Gamestate.push(Pause) end
end

-- ----------------------------------------------------------------------------

function Pause:enter(from)
    self.from = from
end

function Pause:update(dt) --[[ intentionally blank --]] end

function Pause:draw()
    Game:draw()
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

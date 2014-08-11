-- this, like gui.mouse, should go somewhere else ...
-- maybe openglapp?

local class = require 'ext.class'
local sdl = require 'ffi.sdl'

local Timer = class()

function Timer:init()
	self.last = -.1
	self.time = 0
	self.delta = self.time - self.last
end

function Timer:update()
	self.last = self.time
	self.time = sdl.SDL_GetTicks() / 1000
	if self.timescale then self.time = self.time * self.timescale end
	self.delta = self.time - self.last
end

return Timer

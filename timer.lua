-- this, like gui.mouse, should go somewhere else ...
-- maybe openglapp?

local class = require 'ext.class'
local timer = require 'ext.timer'.getTime

local Timer = class()

function Timer:init()
	self.last = -.1
	self.time = 0
	self.delta = self.time - self.last
end

function Timer:update()
	self.last = self.time
	self.time = timer()
	if self.timescale then self.time = self.time * self.timescale end
	self.delta = self.time - self.last
end

return Timer

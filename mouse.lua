--[[
I went and tied mouse closely with gui, then tried to separate gui from tactics ...
this might end up in openglapp ...
--]]

local ffi = require 'ffi'
local gl = require 'ffi.OpenGL'
local sdl = require 'ffi.sdl'
local bit = require 'bit'
local class = require 'ext.class'
local vec2 = require 'vec.vec2'

local Mouse = class()

function Mouse:init()
	self.pos = vec2()
	self.lastPos = vec2()
	self.deltaPos = vec2()
	self.dz = 0
	
	self.leftDown = false
	self.rightDown = false
end

local mouseX = ffi.new('int[1]')
local mouseY = ffi.new('int[1]')

local viewportInt = ffi.new('GLint[4]')

function Mouse:update()
	-- store last state
	self.lastPos[1] = self.pos[1]
	self.lastPos[2] = self.pos[2]

	-- update new state
	
	local sdlButtons = sdl.SDL_GetMouseState(mouseX, mouseY)

	gl.glGetIntegerv(gl.GL_VIEWPORT, viewportInt)
	local viewWidth, viewHeight = viewportInt[2], viewportInt[3]
	
	-- not working ... might need sdl event handling for this (i.e. openglapp)
	self.dz = 0
	if bit.band(sdlButtons, bit.lshift(1, sdl.SDL_BUTTON_WHEELUP-1)) ~= 0 then self.dz = self.dz + 1 end
	if bit.band(sdlButtons, bit.lshift(1, sdl.SDL_BUTTON_WHEELDOWN-1)) ~= 0 then self.dz = self.dz - 1 end
	-- sdl + mouse wheel is not working:
	if self.dz ~= 0 then print('mousedz',self.dz) end
	
	self.pos[1] = mouseX[0] / viewWidth
	self.pos[2] = 1 - mouseY[0] / viewHeight
	
	-- TODO dz in windows should be scaled down ... alot
	self.deltaPos[1] = self.pos[1] - self.lastPos[1]
	self.deltaPos[2] = self.pos[2] - self.lastPos[2]
	
	-- rest of the story
	
	self.lastLeftDown = self.leftDown
	self.lastRightDown = self.rightDown
	self.leftDown = bit.band(sdlButtons, bit.lshift(1, sdl.SDL_BUTTON_LEFT-1)) ~= 0
	self.rightDown = bit.band(sdlButtons, bit.lshift(1, sdl.SDL_BUTTON_RIGHT-1)) ~= 0
	
	-- immediate frame states
	self.leftClick = false
	self.rightClick = false
	self.leftPress = false
	self.leftRelease = false
	self.rightPress = false
	self.rightRelease = false
	self.leftDragging = false
	self.rightDragging = false
	
	do	-- TODO used to not happen if the gui got input
		if self.leftDown then
			if not self.lastLeftDown then
				self.leftPress = true
				self.leftDragged = false
			else
				if self.deltaPos[1] ~= 0 or self.deltaPos[2] ~= 0 then
					self.leftDragging = true
					self.leftDragged = true
				end
			end
		else		-- left up
			if self.lastLeftDown
			and not self.leftDown			-- mouse recorded the leftdown ... to make sure we didnt mousedown on gui and then drag out
			then	
				self.leftRelease = true
				if not self.leftDragged then	-- left click -- TODO - a millisecond test?
					self.leftClick = true
				end
				self.leftDragged = false
				self.leftDown = false
			end
		end

		if self.rightDown then	-- right down
			if not self.lastRightDown then	-- right press
				self.rightPress = true
				self.rightDown = true
				self.rightDragged = false
			else
				if self.deltaPos[1] ~= 0 or self.deltaPos[2] ~= 0 then
					self.rightDragging = true
					self.rightDragged = true
				end
			end
		else		-- right up
			if self.lastRightDown
			and not self.rightDown			-- mouse recorded the rightdown ... to make sure we didnt mousedown on gui and then drag out
			then	
				self.rightRelease = true
				if not self.rightDragged then	-- right click -- TODO - a millisecond test?
					self.rightClick = true
				end
				self.rightDragged = false
				self.rightDown = false
			end
		end	
	end
	
end

return Mouse

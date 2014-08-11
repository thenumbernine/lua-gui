local ffi = require 'ffi'
local gl = require 'ffi.OpenGL'
local glu = require 'ffi.glu'
local sdl = require 'ffi.sdl'
local class = require 'ext.class'
local vec2 = require 'vec.vec2'
local box2 = require 'vec.box2'
local Font = require 'gui.font'
local Widget = require 'gui.widget'
local Mouse = require 'gui.mouse'
local Timer = require 'gui.timer'
local Tex2D = require 'gl.tex2d'
require 'ext'


-- for scope of Widget functions ... 
local GUI = class()

function GUI:gotInput()
	return self.gotInputFlag
end

function GUI:sysSize()
	return unpack(self.root.sizeValue)
end

function GUI:widget(args)
	if not args then args = {} end
	args.gui = self
	local class = args.class or Widget
	args.class = nil
	return class(args)
end

function GUI:getInput(menu, event, eventPos)

	local mouse = self.mouse

	if self.ignoreCapture and menu == self.captureMenu then return 'continue' end
	eventPos = eventPos - menu.posValue
	eventPos[1] = eventPos[1] / menu.scaleValue[1]
	eventPos[2] = eventPos[2] / menu.scaleValue[2]
	
	menu.selectedChild = nil
	
	if menu.parent then menu.parent.selectedChild = menu end
	
	local res
	if not menu.visible then
		res = 'stop'
	else
		if menu.preMouseEvent then
			res = menu:preMouseEvent(event, unpack(eventPos)) or 'continue'
		end
	end

	if res == 'continue' then
	elseif res == 'stop' then
		self.gotInputFlag = true
		return 'continue'
	elseif res == 'halt' then
		self.gotInputFlag = true
		return 'halt'
	end

	if mouse.leftPress then
		self.nextFocusCandidate = menu
	end
	
	local childSpacePos = eventPos - menu.childOfsValue

	for i=#menu.children,1,-1 do
		local c = menu.children[i]
		if c then	-- if a widget is removed before being processed then input can be processed twice ...
			if not (self.ignoreCapture and c == self.captureMenu) then 
				local childPos = vec2(unpack(childSpacePos))
				if childPos[1] > c.posValue[1] 
				and childPos[2] > c.posValue[2]
				and childPos[1] < c.posValue[1] + c.sizeValue[1]
				and childPos[2] < c.posValue[2] + c.sizeValue[2]
				then
					res = self:getInput(c, event, childPos)
					if res == 'continue' then
					elseif res == 'stop' then
						return 'stop'
					elseif res == 'halt' then
						return 'halt'
					end
					
					if c.occludesInput and c.visible then break end
				end
			end
		end
	end
	
	if menu.mouseEvent then
		local res = menu:mouseEvent(event, unpack(eventPos)) or 'continue'
		if res ~= 'continue' then
			self.gotInputFlag = true
		end
		return res
	else
		return 'continue'
	end	
end

local double4 = ffi.new('GLdouble[4]')

local function loadDouble4(x,y,z,w)
	double4[0] = x
	double4[1] = y
	double4[2] = z
	double4[3] = w
	return double4
end

local menuCount = 0
local function display(menu, rect)
	menuCount = menuCount + 1
	rect = rect - menu.posValue
	local menubox = box2(0, 0, unpack(menu.sizeValue))
	if not rect:touches(menubox) then return end
	
	rect:clamp(menubox)
	
	gl.glPushMatrix()
	gl.glTranslatef(menu.posValue[1], menu.posValue[2], 0)
	
	gl.glClipPlane(gl.GL_CLIP_PLANE0, loadDouble4(0, 1, 0, -rect.min[2]))
	gl.glClipPlane(gl.GL_CLIP_PLANE1, loadDouble4(0, -1, 0, rect.max[2]))
	gl.glClipPlane(gl.GL_CLIP_PLANE2, loadDouble4(1, 0, 0, -rect.min[1]))
	gl.glClipPlane(gl.GL_CLIP_PLANE3, loadDouble4(-1, 0, 0, rect.max[1]))
	gl.glEnable(gl.GL_CLIP_PLANE0)
	gl.glEnable(gl.GL_CLIP_PLANE1)
	gl.glEnable(gl.GL_CLIP_PLANE2)
	gl.glEnable(gl.GL_CLIP_PLANE3)
	
	gl.glScalef(menu.scaleValue[1], menu.scaleValue[2], 1)
	
	local drawChildren = menu:display()
	
	gl.glDisable(gl.GL_CLIP_PLANE0)
	gl.glDisable(gl.GL_CLIP_PLANE1)
	gl.glDisable(gl.GL_CLIP_PLANE2)
	gl.glDisable(gl.GL_CLIP_PLANE3)
	
	if drawChildren then
		gl.glTranslatef(-menu.childOfsValue[1], -menu.childOfsValue[2], 0)
		local childRect = rect + menu.childOfsValue
		for _,child in ipairs(menu.children) do
			display(child, childRect)
		end
		gl.glTranslatef(menu.childOfsValue[1], menu.childOfsValue[2], 0)
	end
	
	gl.glClipPlane(gl.GL_CLIP_PLANE0, loadDouble4(0, 1, 0, -rect.min[2]))
	gl.glClipPlane(gl.GL_CLIP_PLANE1, loadDouble4(0, -1, 0, rect.max[2]))
	gl.glClipPlane(gl.GL_CLIP_PLANE2, loadDouble4(1, 0, 0, -rect.min[1]))
	gl.glClipPlane(gl.GL_CLIP_PLANE3, loadDouble4(-1, 0, 0, rect.max[1]))
	gl.glEnable(gl.GL_CLIP_PLANE0)
	gl.glEnable(gl.GL_CLIP_PLANE1)
	gl.glEnable(gl.GL_CLIP_PLANE2)
	gl.glEnable(gl.GL_CLIP_PLANE3)
	
	if menu.postDisplay then
		menu:postDisplay()
		-- border anyone?
	end
	
	gl.glDisable(gl.GL_CLIP_PLANE0)
	gl.glDisable(gl.GL_CLIP_PLANE1)
	gl.glDisable(gl.GL_CLIP_PLANE2)
	gl.glDisable(gl.GL_CLIP_PLANE3)
	
	gl.glPopMatrix()
end

function GUI:setFocus(menu)
	if self.currentFocus then
		if self.currentFocus.onBlur then	
			self.currentFocus:onBlur()
		end
	end
	self.currentFocus = menu
	if self.currentFocus then
		if self.currentFocus.onFocus then
			self.currentFocus:onFocus()
		end
	end
end

function GUI:setCapture(menu)
	self.nextCapture = menu
end

local function updateTopmostPriority(menu)
	local doAgain = true
	while doAgain do
		doAgain = false
		for childIndex,child in ipairs(menu.children) do
			if child.topmostPriority and child.topmostPriority ~= 0 then
				child.topmostPriority = 0
				menu.children:insert(menu.children:remove(childIndex))
				doAgain = true
				break
			end
			updateTopmostPriority(child)
		end
	end
end

local viewportInt = ffi.new('GLint[4]')

function GUI:event(event)
	if event.type == sdl.SDL_KEYUP
	or event.type == sdl.SDL_KEYDOWN 
	then
		if event.key.keysym.sym == sdl.SDLK_LGUI
		or event.key.keysym.sym == sdl.SDLK_RGUI
		then
			if not self.keyDownMap then self.keyDownMap = table() end
			self.keyDownMap[event.key.keysym.sym] = event.type == sdl.SDL_KEYDOWN
		end
	end
end

function GUI:update()
	local mouse = self.mouse

	if self.ownMouse then mouse:update() end
	if self.ownTimer then self.timer:update() end
	
	local captured = {}	--pointers in scripting languages...
	
	gl.glGetIntegerv(gl.GL_VIEWPORT, viewportInt)
	local viewWidth, viewHeight = viewportInt[2], viewportInt[3]
	
	do
		if self.root then
			self.root.sizeValue:set(
				viewWidth / self.root.scaleValue[1],
				viewHeight / self.root.scaleValue[2]
			)
		end
	
		gl.glPushAttrib(gl.GL_ALL_ATTRIB_BITS)
		
		gl.glUseProgram(0)
		gl.glDisable(gl.GL_CULL_FACE)
		gl.glDisable(gl.GL_DEPTH_TEST)
		gl.glDisable(gl.GL_ALPHA_TEST)
		gl.glDisable(gl.GL_LIGHTING)
		gl.glPolygonMode(gl.GL_FRONT_AND_BACK, gl.GL_FILL)
		
		for i=7,0,-1 do
			gl.glActiveTexture(gl.GL_TEXTURE0 + i)
			gl.glBindTexture(gl.GL_TEXTURE_2D, 0)
			gl.glDisable(gl.GL_TEXTURE_2D)
		end
		
		gl.glMatrixMode(gl.GL_PROJECTION)
		gl.glPushMatrix()
		gl.glLoadIdentity()
		gl.glOrtho(0, viewWidth, viewHeight, 0, -1000, 1000)
		
		gl.glMatrixMode(gl.GL_MODELVIEW)
		gl.glPushMatrix()
		gl.glLoadIdentity()
		
		if self.root then
			gl.glBlendFunc(gl.GL_SRC_ALPHA, gl.GL_ONE_MINUS_SRC_ALPHA)
			gl.glEnable(gl.GL_BLEND)
			menuCount = 0
			display(self.root, box2(0, 0, viewWidth, viewHeight))
			gl.glDisable(gl.GL_BLEND)
		end
		
		gl.glPopMatrix()
		gl.glMatrixMode(gl.GL_PROJECTION)
		gl.glPopMatrix()
		gl.glMatrixMode(gl.GL_MODELVIEW)
		gl.glPopAttrib()
		
	end
	
	self.gotInputFlag = false
	if self.root then
	
		local event = 0
		
		if self.keyDownMap and (self.keyDownMap[sdl.SDLK_LGUI] or self.keyDownMap[sdl.SDLK_RGUI]) then
			if mouse.leftPress then event = bit.bor(event, 2)
			elseif mouse.leftRelease then event = bit.bor(event, 128)
			elseif mouse.leftDown then event = bit.bor(event, 16)
			end
		else
			if mouse.leftPress then event = bit.bor(event, 1)
			elseif mouse.leftRelease then event = bit.bor(event, 64)
			elseif mouse.leftDown then event = bit.bor(event, 8)
			end
		end
		
		if mouse.rightPress then event = bit.bor(event, 2)
		elseif mouse.rightRelease then event = bit.bor(event, 128)
		elseif mouse.rightDown then event = bit.bor(event, 16)
		end

		local mousepos = vec2(
			mouse.pos[1] * viewWidth,
			(1 - mouse.pos[2]) * viewHeight)
			
		if self.captureMenu then
			self.ignoreCapture = false
			local pos = vec2(unpack(mousepos))
			local rootToCapture = table()
			local o = self.captureMenu.parent
			while o do
				rootToCapture:insert(1, o)
				o = o.parent
			end
			for _,o in ipairs(rootToCapture) do
				mousepos = mousepos - o.posValue
				mousepos[1] = mousepos[1] / o.scaleValue[1]
				mousepos[2] = mousepos[2] / o.scaleValue[2]
				mousepos = mousepos - o.childOfsValue
			end
			mousepos = mousepos - self.captureMenu.posValue
			mousepos[1] = mousepos[1] / self.captureMenu.scaleValue[1]
			mousepos[2] = mousepos[2] / self.captureMenu.scaleValue[2]
			local response = self:getInput(self.captureMenu, event, mousepos)
			self.gotInputFlag = response ~= 'continue'
		end
		
		if not result then
			response = self:getInput(self.root, event, mousepos)
			self.gotInputFlag = response ~= 'continue'
		end
		
		if mouse.leftPress then
			if self.nextFocusCandidate and self.nextFocusCandidate ~= self.currentFocus then
				self:setFocus(self.nextFocusCandidate)
			end
		end
		
		updateTopmostPriority(self.root)
		
		-- * doKeyPress() used to be here *
		
		self.captureMenu = self.nextCapture
		
	end
end

function GUI:doKeyPress(sdlevent)
	if self.currentFocus then
		local hit = false
		-- for all key-down keys ...
		if self.currentFocus.doKeyPress then
			self.currentFocus:doKeyPress(sdlevent)
		end
		--if not self.currentFocus then break end
		if hit then
			self.gotInputFlag = true
		end
	end
end

--[[
args:
	font
	mouse - (optional) - if mouse isn't provided then one will be created, and it'll be updated during GUI:update
--]]
function GUI:init(args)
	self.font = Font()
	
	self.mouse = args and args.mouse
	if not self.mouse then
		self.mouse = Mouse()
		self.ownMouse = true
	end
	
	self.timer = args and args.timer
	if not self.timer then
		self.timer = Timer()
		self.ownTimer = true
	end
	
	local fontfilename = 'font.png'
	if args and args.font then fontfilename = args.font end
	self.font.tex = Tex2D{
		filename = fontfilename,
		minFilter = gl.GL_NEAREST,
		magFilter = gl.GL_LINEAR,
	}
	self.font:calcWidths()

	self.root = self:widget{
		isroot = true,
		pos = {0,0},
		color = {0,0,0,0},
		backgroundColor = {0,0,0,0},
		size = {60,40},
		scale = args and args.scale or {12,12},
	}

	self.ignoreCapture = nil
	self.captureMenu = nil
	self.nextFocusCandidate = nil
	self.nextCapture = nil
end

return GUI

local ffi = require 'ffi'
local gl = require 'gl'
local sdl = require 'sdl'
local table = require 'ext.table'
local class = require 'ext.class'
local vec2 = require 'vec.vec2'
local box2 = require 'vec.box2'
local Image = require 'image'
local Mouse = require 'glapp.mouse'
local Font = require 'gui.font'
local Widget = require 'gui.widget'
local Timer = require 'gui.timer'
local GLTex2D = require 'gl.tex2d'
local GLSceneObject = require 'gl.sceneobject'

-- for scope of Widget functions ...
local GUI = class()

function GUI:gotInput()
	return self.gotInputFlag
end

function GUI:sysSize()
	return table.unpack(self.root.sizeValue)
end

function GUI:widget(args)
	if not args then args = {} end
	args.gui = self
	local cl = args.class or Widget
	args.class = nil
	return cl(args)
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
			res = menu:preMouseEvent(event, table.unpack(eventPos)) or 'continue'
		end
	end

	if res == 'stop' then
		self.gotInputFlag = true
		return 'continue'
	elseif res == 'halt' then
		self.gotInputFlag = true
		return 'halt'
	end
	-- res == 'continue'

	if mouse.leftPress then
		self.nextFocusCandidate = menu
	end

	local childSpacePos = eventPos - menu.childOfsValue

	for i=#menu.children,1,-1 do
		local c = menu.children[i]
		if c then	-- if a widget is removed before being processed then input can be processed twice ...
			if not (self.ignoreCapture and c == self.captureMenu) then
				local childPos = vec2(table.unpack(childSpacePos))
				if childPos[1] > c.posValue[1]
				and childPos[2] > c.posValue[2]
				and childPos[1] < c.posValue[1] + c.sizeValue[1]
				and childPos[2] < c.posValue[2] + c.sizeValue[2]
				then
					res = self:getInput(c, event, childPos)
					if res == 'stop' then
						return 'stop'
					elseif res == 'halt' then
						return 'halt'
					end
					-- res == 'continue'

					if c.occludesInput and c.visible then break end
				end
			end
		end
	end

	if menu.mouseEvent then
		res = menu:mouseEvent(event, table.unpack(eventPos)) or 'continue'
		if res ~= 'continue' then
			self.gotInputFlag = true
		end
		return res
	else
		return 'continue'
	end
end

local double4 = ffi.new('double[4]')
local function loadDouble4(x,y,z,w)
	double4[0] = x
	double4[1] = y
	double4[2] = z
	double4[3] = w
	return double4
end

local menuCount = 0
local function display(menu, rect)
	local gui = menu.gui
	local view = gui and gui.view

	menuCount = menuCount + 1
	rect = rect - menu.posValue
	local menubox = box2(0, 0, table.unpack(menu.sizeValue))
	if not rect:touches(menubox) then return end

	rect:clamp(menubox)

	local pushMvMat
	if not gui.drawImmediateMode then
		pushMvMat = view.mvMat:clone()
		view.mvMat
			:applyTranslate(menu.posValue[1], menu.posValue[2], 0)
			:applyScale(menu.scaleValue[1], menu.scaleValue[2], 1)
		view.mvProjMat:mul4x4(view.projMat, view.mvMat)
		-- TODO ... glClipPlane applies relative to the current modelview matrix ... but this does not ...
		-- so FIXME do.
		--gui.quadSceneObj.uniforms.clipBox = {rect.min[1], rect.min[2], rect.max[1], rect.max[2]}
		gui.quadSceneObj.uniforms.useClip = true
	else
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
	end

	local drawChildren = menu:display()

	if gui.drawImmediateMode then
		gl.glDisable(gl.GL_CLIP_PLANE0)
		gl.glDisable(gl.GL_CLIP_PLANE1)
		gl.glDisable(gl.GL_CLIP_PLANE2)
		gl.glDisable(gl.GL_CLIP_PLANE3)
	end

	if drawChildren then
		if gui.drawImmediateMode then
			gl.glTranslatef(-menu.childOfsValue[1], -menu.childOfsValue[2], 0)
		else
			-- TODO disable clip plane?
			view.mvMat:applyTranslate(-menu.childOfsValue[1], -menu.childOfsValue[2], 0)
			view.mvProjMat:mul4x4(view.projMat, view.mvMat)
			GUI.quadSceneObj.uniforms.useClip = false
		end
		local childRect = rect + menu.childOfsValue
		for _,child in ipairs(menu.children) do
			display(child, childRect)
		end
		if gui.drawImmediateMode then
			gl.glTranslatef(menu.childOfsValue[1], menu.childOfsValue[2], 0)
		else
			view.mvMat:applyTranslate(-menu.childOfsValue[1], -menu.childOfsValue[2], 0)
			view.mvProjMat:mul4x4(view.projMat, view.mvMat)
		end
	end

	if gui.drawImmediateMode then
		gl.glClipPlane(gl.GL_CLIP_PLANE0, loadDouble4(0, 1, 0, -rect.min[2]))
		gl.glClipPlane(gl.GL_CLIP_PLANE1, loadDouble4(0, -1, 0, rect.max[2]))
		gl.glClipPlane(gl.GL_CLIP_PLANE2, loadDouble4(1, 0, 0, -rect.min[1]))
		gl.glClipPlane(gl.GL_CLIP_PLANE3, loadDouble4(-1, 0, 0, rect.max[1]))
		gl.glEnable(gl.GL_CLIP_PLANE0)
		gl.glEnable(gl.GL_CLIP_PLANE1)
		gl.glEnable(gl.GL_CLIP_PLANE2)
		gl.glEnable(gl.GL_CLIP_PLANE3)
	else
		GUI.quadSceneObj.uniforms.useClip = true
	end

	if menu.postDisplay then
		menu:postDisplay()
		-- border anyone?
	end

	if gui.drawImmediateMode then
		gl.glDisable(gl.GL_CLIP_PLANE0)
		gl.glDisable(gl.GL_CLIP_PLANE1)
		gl.glDisable(gl.GL_CLIP_PLANE2)
		gl.glDisable(gl.GL_CLIP_PLANE3)

		gl.glPopMatrix()
	else
		view.mvMat:copy(pushMvMat)
		view.mvProjMat:mul4x4(view.projMat, view.mvMat)
		GUI.quadSceneObj.uniforms.useClip = false
	end
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

local vec4i = require 'vec-ffi.vec4i'
local viewportInt = vec4i()

function GUI:event(event)
	if event[0].type == sdl.SDL_EVENT_KEY_UP
	or event[0].type == sdl.SDL_EVENT_KEY_DOWN
	then
		if event[0].key.key == sdl.SDLK_LGUI
		or event[0].key.key == sdl.SDLK_RGUI
		then
			if not self.keyDownMap then self.keyDownMap = table() end
			self.keyDownMap[event[0].key.key] = event[0].type == sdl.SDL_EVENT_KEY_DOWN
		end
	end
end

function GUI:update()
	local mouse = self.mouse

	if self.ownMouse then mouse:update() end
	if self.ownTimer then self.timer:update() end

	--local captured = {}	--pointers in scripting languages...

	gl.glGetIntegerv(gl.GL_VIEWPORT, viewportInt.s)
	local viewWidth, viewHeight = viewportInt.z, viewportInt.w

	if self.root then
		self.root.sizeValue:set(
			viewWidth / self.root.scaleValue[1],
			viewHeight / self.root.scaleValue[2]
		)
	end

	local pushMvMat
	local pushProjMat
	if not self.drawImmediateMode then
		pushMvMat = self.view.mvMat:clone()
		pushProjMat = self.view.projMat:clone()

		self.view.mvMat:setIdent()
		self.view.projMat:setOrtho(0, viewWidth, viewHeight, 0, -1000, 1000)
		self.view.mvProjMat:copy(self.view.projMat)

		-- TODO push and pop
		gl.glUseProgram(0)
		gl.glPolygonMode(gl.GL_FRONT_AND_BACK, gl.GL_FILL)
		gl.glDisable(gl.GL_DEPTH_TEST)
		--gl.glDisable(gl.GL_CULL_FACE)
		--gl.glDisable(gl.GL_ALPHA_TEST)
		--gl.glDisable(gl.GL_LIGHTING)
		for i=7,0,-1 do
			gl.glActiveTexture(gl.GL_TEXTURE0 + i)
			gl.glBindTexture(gl.GL_TEXTURE_2D, 0)
			--gl.glDisable(gl.GL_TEXTURE_2D)
		end
	else
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
	end

	if self.root then
		gl.glBlendFunc(gl.GL_SRC_ALPHA, gl.GL_ONE_MINUS_SRC_ALPHA)
		gl.glEnable(gl.GL_BLEND)
		menuCount = 0
		display(self.root, box2(0, 0, viewWidth, viewHeight))
		gl.glDisable(gl.GL_BLEND)
	end

	if self.drawImmediateMode then
		gl.glPopMatrix()
		gl.glMatrixMode(gl.GL_PROJECTION)
		gl.glPopMatrix()
		gl.glMatrixMode(gl.GL_MODELVIEW)
		gl.glPopAttrib()
	else
		self.view.mvMat:copy(pushMvMat)
		self.view.projMat:copy(pushProjMat)
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
			mouse.pos.x * viewWidth,
			(1 - mouse.pos.y) * viewHeight)

		local response
		if self.captureMenu then
			self.ignoreCapture = false
			local rootToCapture = table()
			do
				local o = self.captureMenu.parent
				while o do
					rootToCapture:insert(1, o)
					o = o.parent
				end
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
			response = self:getInput(self.captureMenu, event, mousepos)
			self.gotInputFlag = response ~= 'continue'
		end

		if not response then
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

-- Hack for the time being
-- In theory setting this on vs off should work all the same ...
-- TODO merge with Font
GUI.drawImmediateMode = false

--[[
args:
	font
	mouse - (optional) - if mouse isn't provided then one will be created, and it'll be updated during GUI:update
--]]
function GUI:init(args)
	self.drawImmediateMode = args.drawImmediateMode
	if not self.drawImmediateMode then
		self.view = require 'glapp.view'()
		self.view.ortho = true

		self.lineSceneObj = GLSceneObject{
			program = {
				version = 'latest',
				precision = 'best',
				vertexCode = [[
in vec2 vertex;
uniform mat4 mvProjMat;
void main() {
	gl_Position = mvProjMat * vec4(vertex, 0., 1.);
}
]],
				fragmentCode = [[
out vec4 fragColor;
void main() {
	fragColor = vec4(0., 0., 0., 1.);
}
]],
			},
			geometry = {
				mode = gl.GL_LINES,
			},
			vertexes = {
				useVec = true,
				dim = 2,
			},
			uniforms = {
				mvProjMat = self.view.mvProjMat.ptr,
			},
		}

		-- singleton because I don't have another way to communicate to drawRect in gui/widget.lua but I should fix that ...
		GUI.quadSceneObj = GLSceneObject{
			program = {
				version = 'latest',
				precision = 'best',
				vertexCode = [[
in vec4 vertex;	//[x,y,tx,ty]
out vec2 vertexv;
out vec2 tcv;
uniform mat4 mvProjMat;
void main() {
	vertexv = vertex.xy;
	tcv = vertex.zw;
	gl_Position = mvProjMat * vec4(vertex.xy, 0., 1.);
}
]],
				fragmentCode = [[
in vec2 vertexv;
in vec2 tcv;
out vec4 fragColor;
uniform bool useTex;
uniform vec4 color;
uniform sampler2D tex;
uniform vec4 clipBox;	//[x1,y1,x2,y2]
uniform bool useClip;
void main() {
	if (useClip &&
		(
			vertexv.x < clipBox.x ||
			vertexv.x > clipBox.z ||
			vertexv.y < clipBox.y ||
			vertexv.y > clipBox.w
		)
	) {
		discard;
	}

	if (useTex) {
		fragColor = color * texture(tex, tcv);
	} else {
		fragColor = color;
	}
}
]],
			},
			geometry = {
				mode = gl.GL_TRIANGLES,
			},
			vertexes = {
				useVec = true,
				dim = 4,
			},
			uniforms = {
				mvProjMat = self.view.mvProjMat.ptr,
			},
		}

	end

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

	self.font = Font{
		filename = args.font,
		drawImmediateMode = self.drawImmediateMode,
		view = self.view,
	}

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

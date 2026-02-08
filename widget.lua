local assert = require 'ext.assert'
local gl = require 'gl'
local box2 = require 'vec.box2'
local vec2 = require 'vec.vec2'
local vec4 = require 'vec.vec4'
local class = require 'ext.class'
local table = require 'ext.table'
local GLTex2D = require 'gl.tex2d'

--[[
fields:

geometry:
pos
size

children:
childOfs
scale

primary display:
texture
color

text:
text
fontColor
fontSize
textPadding	-- left padding between side and text content
multiLine

background:
backgroundTexture
backgroundColor

--]]
local Widget = class()

-- default prim values here.  default vec values have to be instanciated
Widget.texture = 0
Widget.visible = true
Widget.topmostPriority = 0
Widget.allowFocus = false
Widget.occludesInput = false
Widget.useNinePatch = false
Widget.ninePatchUVBorder = .25
Widget.ninePatchBorder = 1
Widget.textPadding = 0
Widget.multiLine = true


-- TODO fix getters and setters of vector memebers
Widget.backgroundColorValue = vec4(0,0,0,1)
Widget.colorValue = vec4(0,0,0,1)

function Widget:init(args)
	-- a general means for modaless menus ...
	-- 1) keep track of a uid
	-- 2) hold a serverside active menu array
	-- send a 'store' on create and a 'clear' on delete with the menu's uid
	-- ... but the server makes a client call and the client creates menus ...
	--	how does the server know how to associate its client call with what ids are created ...

	self.gui = assert(args.gui)
	args.gui = nil	-- don't copy/paste this with the rest of the args

	self.posValue = vec2()
	self.scaleValue = vec2(1,1)
	self.backgroundScaleValue = vec2(1/4, 1/4)
	self.backgroundOffsetValue = vec2()
	self.sizeValue = vec2(1,1)
	self.colorValue = vec4(table.unpack(getmetatable(self).colorValue))
	self.fontColorValue = vec4(1,1,1,1)
	self.backgroundColorValue = vec4(table.unpack(getmetatable(self).backgroundColorValue))
	self.fontSizeValue = vec2(1.5, 1.5)
	self.childOfsValue = vec2(0, 0)	-- not used atm, but used for scroll areas

	self.children = table()

--[[ TODO implement this somewhere
		self.client.updateCallbacks:insertUnique(ClientSide.updateWidgets)

		-- current input context menus
		if not self.client.menuKeyPrompt then
			self.client.menuKeyPrompt = table()
		end

		-- root-level menus
		if not self.client.menus then
			self.client.menus = table()
		end
		self.client.menus:insert(self)
--]]

	local function handleargkv(k,v)
		if self[k] and type(self[k]) == 'function' then
			if type(args[k]) == 'table' then
				self[k](self, table.unpack(args[k]))
			else
				self[k](self, args[k])
			end
		else
			self[k] = args[k]
		end
	end

	-- fill whatever args are passed
	-- use setters when available
	-- use tables as parameter lists
	-- handle parent first
	if args.parent then
		assert(getmetatable(args.parent) ~= Widget)
		self:setParent(args.parent[1])
	end

	for k,v in pairs(args) do
		if k ~= 'parent' and k ~= 'class' then	-- already handled
			handleargkv(k,v)
		end
	end

--[[
	if self.hasPrompts then
		self.client.menuKeyPrompt:insert(self)
		self.client.menuKeyPromptIndex = self.firstPromptIndex or 1
	end
--]]

	if self.text then self.text = tostring(self.text) else self.text = '' end
end

local function vectorgetset(basefield)
	local field = basefield .. 'Value'	-- use *Value as the vector fields associated with * getter/setters
	return function(self, ...)
		local newv = {...}
		local oldv = {table.unpack(self[field])}
		if #newv > 0 then
			if type(newv[1]) == 'table' then
				self[field]:set(table.unpack(newv[1]))
			else
				assert(#oldv == #newv, "cannot set "..basefield.." to "..#field.." values.  needs 0, a single table, or "..#oldv)
				self[field]:set(table.unpack(newv))
			end
		end
		return table.unpack(oldv)
	end
end

function Widget:getParent() return self.parent end

function Widget:setParent(newv)
	if self.parent then
		self.parent:removeChild(self)
	end
	self.parent = newv
	if self.parent then
		self.parent.children:insertUnique(self)
	end
end

Widget.pos = vectorgetset('pos')
Widget.size = vectorgetset('size')
Widget.scale = vectorgetset('scale')
Widget.fontSize = vectorgetset('fontSize')
Widget.fontColor = vectorgetset('fontColor')
Widget.backgroundColor = vectorgetset('backgroundColor')
Widget.backgroundScale = vectorgetset('backgroundScale')
Widget.backgroundOffset = vectorgetset('backgroundOffset')
Widget.color = vectorgetset('color')

function Widget:child(index)
	return self.children[index]
end

function Widget:numChilds()
	return #self.children
end


function Widget:removeChild(child)
	self.children:removeObject(child)
	if self.childPrompts then
		self.childPrompts:removeObject(child)
	end
end

function Widget:delete()
	-- explicitly delete all children
	while #self.children > 0 do
		assert(self.children[1] ~= self)
		self.children[1]:delete()
	end

--	self.client.menuKeyPrompt:removeObject(self)

	if self.parent then
		self.parent:removeChild(self)
--[[
	else
		self.client.menus:removeObject(self)
--]]
	end
end


-- make a fake tex obj that doesn't destroy upon dtor ...
local tmpTex = setmetatable({}, GLTex2D)
tmpTex.__gc = function() end

--[[
args:
	pos
	size
	tcmin (optional)
	tcmax (optional)
	color
	textureID
	gui
--]]
local function drawRect(args)
	local gui = args.gui
	local tcmin = args.tcmin or {0,0}
	local tcmax = args.tcmax or {1,1}

	local color = args.color
	if color and color[4] == 0 then return end
	local textureID = args.textureID or 0

	if gui.drawImmediateMode then
		if color then
			gl.glColor4f(table.unpack(color))
		else
			gl.glColor4f(1,1,1,1)
		end

		if textureID ~= 0 then
			gl.glEnable(gl.GL_TEXTURE_2D)
			gl.glBindTexture(gl.GL_TEXTURE_2D, textureID)
		end

		gl.glBegin(gl.GL_QUADS)
		gl.glTexCoord2f(tcmin[1],tcmin[2]) gl.glVertex2f(args.pos[1], args.pos[2])
		gl.glTexCoord2f(tcmin[1],tcmax[2]) gl.glVertex2f(args.pos[1], args.pos[2] + args.size[2])
		gl.glTexCoord2f(tcmax[1],tcmax[2]) gl.glVertex2f(args.pos[1] + args.size[1], args.pos[2] + args.size[2])
		gl.glTexCoord2f(tcmax[1],tcmin[2]) gl.glVertex2f(args.pos[1] + args.size[1], args.pos[2])
		gl.glEnd()

		if textureID ~= 0 then
			gl.glDisable(gl.GL_TEXTURE_2D)
		end
	else
		local sceneObj = gui.quadSceneObj

		if textureID == 0 then
			sceneObj.uniforms.useTex = false
			sceneObj.texs[1] = nil
		else
			sceneObj.uniforms.useTex = true
			tmpTex.id = textureID
			sceneObj.texs[1] = tmpTex
		end

		if color then
			sceneObj.uniforms.color = {table.unpack(color)}
		else
			sceneObj.uniforms.color = {1,1,1,1}
		end

		local vertexCPU = sceneObj.attrs.vertex.buffer.vec
		sceneObj:beginUpdate()

		local x, y = table.unpack(args.pos)
		local w, h = table.unpack(args.size)

		vertexCPU:emplace_back():set(x,		y,		tcmin[1], tcmin[2])
		vertexCPU:emplace_back():set(x,		y + h,	tcmin[1], tcmax[2])
		vertexCPU:emplace_back():set(x + w,	y,		tcmax[1], tcmin[2])
		vertexCPU:emplace_back():set(x + w,	y,		tcmax[1], tcmin[2])
		vertexCPU:emplace_back():set(x,		y + h,	tcmin[1], tcmax[2])
		vertexCPU:emplace_back():set(x + w,	y + h,	tcmax[1], tcmax[2])
		sceneObj:endUpdate()
	end
end

function Widget:display(ofs)
	if not self.visible then return false end

	-- I could do this all in one sweep ...
	if self.backgroundTexture and self.backgroundColorValue[4] > 0 then
		drawRect{
			gui = self.gui,
			pos = vec2(0,0),
			size = self.sizeValue,
			tcmin = self.backgroundOffsetValue,
			tcmax = vec2(self.backgroundOffsetValue[1] + self.sizeValue[1] * self.backgroundScaleValue[1], self.backgroundOffsetValue[2] + self.sizeValue[2] * self.backgroundScaleValue[2]),
			textureID = self.backgroundTexture,
			color = self.backgroundColorValue,
		}
	end

	if self.colorValue[4] > 0 then
		if not self.useNinePatch then
			drawRect{
				gui = self.gui,
				pos = vec2(0, 0),
				size = self.sizeValue,
				color = self.colorValue,
				textureID = self.texture,
			}
		else
			local divs = {0, self.ninePatchUVBorder, 1 - self.ninePatchUVBorder, 1}
			local worldBoundsDivU = {0, self.ninePatchBorder / self.sizeValue[1], (self.sizeValue[1] - self.ninePatchBorder) / self.sizeValue[1], 1}
			local worldBoundsDivV = {0, self.ninePatchBorder / self.sizeValue[2], (self.sizeValue[2] - self.ninePatchBorder) / self.sizeValue[2], 1}
			if self.sizeValue[1] < 2 * self.ninePatchBorder then
				worldBoundsDivU[2] = .5
				worldBoundsDivU[3] = .5
			end
			if self.sizeValue[2] < 2 * self.ninePatchBorder then
				worldBoundsDivV[2] = .5
				worldBoundsDivV[3] = .5
			end
			for i=1,#divs-1 do
				for j=1,#divs-1 do
					local tc = box2{
						min = {divs[i], divs[j]},
						max = {divs[i+1], divs[j+1]}
					}
					local worldBounds = box2{
						min = {worldBoundsDivU[i], worldBoundsDivV[j]},
						max = {worldBoundsDivU[i+1], worldBoundsDivV[j+1]}
					}
					for k=1,2 do
						worldBounds.min[k] = worldBounds.min[k] * self.sizeValue[k]
						worldBounds.max[k] = worldBounds.max[k] * self.sizeValue[k]
					end
					drawRect{
						gui = self.gui,
						pos = worldBounds.min,
						size = worldBounds.max - worldBounds.min,
						tcmin = tc.min,
						tcmax = tc.max,
						color = self.colorValue,
						textureID = self.texture,
					}
				end
			end
		end
	end

	self:displayText(ofs)

	return true
end

function Widget:displayText(ofs)
	assert.eq(self.gui.drawImmediateMode, self.gui.font.drawImmediateMode)
--[[
print()
print('Widget:displayText', self.text)
print(debug.traceback())
print()
--]]
	self.gui.font:draw{
		pos = vec2(self.textPadding,0),
		size = vec2(self.sizeValue[1] - 2 * self.textPadding, self.sizeValue[2]),
		text = self.text,
		color = self.fontColorValue,
		fontSize = self.fontSizeValue,
		multiLine = self.multiLine
	}
end

function Widget:setFocus() self.gui:setFocus(self) end
function Widget:loseFocus() self.gui:setFocus(nil) end

return Widget

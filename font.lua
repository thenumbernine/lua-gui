local ffi = require 'ffi'
local bit = require 'bit'
local assert = require 'ext.assert'
local class = require 'ext.class'
local gl = require 'gl'
local GLProgram = require 'gl.program'
local GLGeometry = require 'gl.geometry'
local GLSceneObject = require 'gl.sceneobject'
local glreport = require 'gl.report'


local Font = class()

-- hack for the time being
Font.drawImmediateMode = true

function Font:init(args)
	self.widths = {}
	self:resetWidths()

	if args then
		if args.image then
			self.image = args.image
			self:calcWidths(args.image)
		end
		self.tex = args.tex
		self.drawImmediateMode = args.drawImmediateMode
	end

	if self.drawImmediateMode then
		if not self.drawBegin then self.drawBegin = self.drawBegin_immediate end
		if not self.drawEnd then self.drawEnd = self.drawEnd_immediate end
		if not self.drawQuad then self.drawQuad = self.drawQuad_immediate end
	else
		if not self.drawBegin then self.drawBegin = self.drawBegin_buffered end
		if not self.drawEnd then self.drawEnd = self.drawEnd_buffered end
		if not self.drawQuad then self.drawQuad = self.drawQuad_buffered end
	end
end

function Font:resetWidths()
	for i=1,256-32 do
		self.widths[i] =  {
			start = 0,
			finish = 1,
		}
	end
end

-- looks for font image in self.image
-- image is optional and is stored in self.image
function Font:calcWidths()
	local image = assert(self.image)
	local width = image.width
	local height = image.height
	local channels = image.channels
	local buffer = ffi.cast(image.format..'*', image.buffer)

	local letterWidth = width / 16
	local letterHeight = height / 16

	for j=0,15 do
		for i=0,15 do
			local firstx = 16
			local lastx = -1
			local index = i+j*16;
			if index < #self.widths-1 then
				local ch = index + 32
				for y=0,letterHeight-1 do
					for x=0,letterWidth-1 do
						local pixel = buffer[(channels-1) + channels*((i * letterWidth + x) + width * (j * letterHeight + y))]
						if pixel ~= 0 then
							if x < firstx then firstx = x end
							if x > lastx then lastx = x end
						end
					end
				end
				firstx = firstx - 1
				lastx = lastx + 2
				if firstx < 0 then firstx = 0 end
				if lastx > letterWidth then lastx = letterWidth end

				if lastx < firstx then firstx, lastx = 0, letterWidth/2 end

				self.widths[ch-32+1].start = firstx / letterWidth
				self.widths[ch-32+1].finish = lastx / letterWidth
			end
		end
	end
end

-- previously a member of gui.lua

--[[
args:
	pos
	fontSize
	text.  doesn't handle \r's
	size (optional)
	color (optional - defaults to 1,1,1)
	dontRender (optional) default to false
	multiLine (optional) default to true
--]]
function Font:draw(args)
	local packed = {}
	if args.pos then
		packed[1] = args.pos[1]
		packed[2] = args.pos[2]
	else
		packed[1] = 0
		packed[2] = 0
	end
	packed[3] = args.fontSize[1]
	packed[4] = args.fontSize[2]
	packed[5] = args.text
	if args.size then
		packed[6] = args.size[1]
		packed[7] = args.size[2]
	end
	if args.color then
		packed[8] = args.color[1]
		packed[9] = args.color[2]
		packed[10] = args.color[3]
		packed[11] = args.color[4]
	end
	packed[12] = args.dontRender
	packed[13] = not args.multiLine
	return self:drawUnpacked(unpack(packed, 1, 13))
end

function Font:drawUnpacked(...)
	local
		posX, posY,
		fontSizeX, fontSizeY,
		text,
		sizeX, sizeY,
		colorR, colorG, colorB, colorA,
		dontRender,
		singleLine
		= ...

	assert(self.tex)

	--local text = text:gsub('\r\n', '\n'):gsub('\r', '\n')

	if not dontRender then
		self:drawBegin(...)
	end

	local cursorX, cursorY = 0, 0
	local maxx = 0

	--local lastCharWasSpace = true
	local a = 1
	while a <= #text do
		local thisCharIsSpace = (text:byte(a) or 0) <= 32
		local nextCharIsSpace = (text:byte(a + 1) or 0) <= 32
		local newline = false

		if text:sub(a,a) == '\n' then
			newline = true
		else
			if thisCharIsSpace and not nextCharIsSpace then
				local wordlen = 0
				while (text:byte(a) or 0) <= 32 do
					a = a + 1
				end
				local finish = a
				while (text:byte(finish) or 0) > 32 do
					local widthIndex = (text:byte(finish) or 0) - 32 + 1	-- 1-based at char 32
					local charWidth
					if self.widths[widthIndex] then
						charWidth = self.widths[widthIndex].finish - self.widths[widthIndex].start
					else
						charWidth = 1
					end
					wordlen = wordlen + charWidth
					finish = finish + 1
				end
				if sizeX and cursorX + wordlen * fontSizeX + 1 >= sizeX then
					newline = true
				end
				a = a - 1
			end
		end

		if newline and not singleLine then
			cursorX = 0
			cursorY = cursorY + fontSizeY
			if sizeY and cursorY >= sizeY then break end
		else
			local charIndex = math.max(text:byte(a) or 0, 32)
			local widthIndex = charIndex - 32 + 1
			local startWidth, finishWidth
			if self.widths[widthIndex] then
				startWidth = self.widths[widthIndex].start
				finishWidth = self.widths[widthIndex].finish
			else
				startWidth = 0
				finishWidth = 1
			end
			local width = finishWidth - startWidth

			local lettermaxx = width * fontSizeX + cursorX
			if maxx < lettermaxx then maxx = lettermaxx end

			if not dontRender then
				local tx = bit.band(charIndex, 15)
				local ty = bit.rshift(charIndex, 4) - 2
				self:drawQuad(cursorX + posX, cursorY + posY, tx, ty, startWidth, finishWidth, fontSizeX, fontSizeY)
			end
			cursorX = cursorX + width * fontSizeX
		end

		a = a + 1
	end

	if not dontRender then
		self:drawEnd()
	end

	return maxx, cursorY + fontSizeY
end

-- [[ immediate-mode version

function Font:drawBegin_immediate(...)
	local
		posX, posY,
		fontSizeX, fontSizeY,
		text,
		sizeX, sizeY,
		colorR, colorG, colorB, colorA,
		dontRender,
		singleLine
		= ...

	if colorR then
		if colorA == 0 then return 0,0 end
		gl.glColor4f(colorR, colorG, colorB, colorA)
	else
		gl.glColor3f(1,1,1)
	end
	gl.glEnable(gl.GL_TEXTURE_2D)
	gl.glBindTexture(gl.GL_TEXTURE_2D, self.tex.id)
	gl.glBegin(gl.GL_QUADS)
end

function Font:drawQuad_immediate(drawX, drawY, tx, ty, startWidth, finishWidth, fontSizeX, fontSizeY)
	for i=0,3 do
		local vtxX, vtxY
		if bit.band(i, 2) == 0 then
			vtxX = startWidth
		else
			vtxX = finishWidth
		end
		if bit.band(i, 1) == bit.rshift(bit.band(i,2),1) then
			vtxY = 0
		else
			vtxY = 1
		end
		gl.glTexCoord2f((tx + vtxX) / 16, (ty + vtxY) / 16)
		gl.glVertex2f(
			(vtxX - startWidth) * fontSizeX + drawX,
			vtxY * fontSizeY + drawY)
	end
end

function Font:drawEnd_immediate(...)
	local
		posX, posY,
		fontSizeX, fontSizeY,
		text,
		sizeX, sizeY,
		colorR, colorG, colorB, colorA,
		dontRender,
		singleLine
		= ...

	gl.glEnd()
	gl.glDisable(gl.GL_TEXTURE_2D)
end

--]]
-- [=[ buffered geometry mode
-- this runs by issuing lots of draw calls for single-quads, and it runs surprisingly faster than other APIs which jump through hoops to collect buffers and issue single draw calls ...
-- TODO switch zeta2d to use this instead of its own builtin version of this same thing ...

function Font:drawBegin_buffered(
	posX, posY,
	fontSizeX, fontSizeY,
	text,
	sizeX, sizeY,
	colorR, colorG, colorB, colorA
)
	if colorR then
		self.colorR = colorR
		self.colorG = colorG
		self.colorB = colorB
		self.colorA = colorA
	else
		self.colorR = 1
		self.colorG = 1
		self.colorB = 1
		self.colorA = 1
	end

	self.quadSceneObj = self.quadSceneObj or GLSceneObject{
		program = {
			version = 'latest',
			precision = 'best',
			vertexCode = [[
layout(location=0) in vec2 vertex;
out vec2 tc;
uniform mat4 mvProjMat;
uniform vec4 rect;
uniform vec4 tcRect;	//xy = texcoord offset, zw = texcoord size
uniform vec2 rot;	//xy = cos(angle), sin(angle)
void main() {
	tc = tcRect.xy + tcRect.zw * vertex;

	vec2 rxy = vertex * rect.zw;
	rxy = vec2(
		rxy.x * rot.x - rxy.y * rot.y,
		rxy.y * rot.x + rxy.x * rot.y
	);
	rxy += rect.xy;
	gl_Position = mvProjMat * vec4(rxy, 0., 1.);
}
]],
			fragmentCode = [[
in vec2 tc;
out vec4 fragColor;
uniform vec4 color;
uniform sampler2D tex;
void main() {
	fragColor = color * texture(tex, tc);
}
]],
		},
		geometry = {
			mode = gl.GL_TRIANGLE_STRIP,
			vertexes = {
				data = {
					0, 0,
					0, 1,
					1, 0,
					1, 1,
				},
				dim = 2,
			},
		},
		uniforms = {
			tex = 0,
		},
		texs = {self.tex},
	}

	self.tex:bind()

	local sceneObj = self.quadSceneObj
	local shader = sceneObj.program
	local uniforms = shader.uniforms
	shader:use()
	sceneObj:enableAndSetAttrs()

	local view = assert.index(self, 'view')	-- need this for buffered draw
	gl.glUniformMatrix4fv(uniforms.mvProjMat.loc, 1, gl.GL_FALSE, view.mvProjMat.ptr)
end

function Font:drawQuad_buffered(drawX, drawY, tx, ty, startWidth, finishWidth, fontSizeX, fontSizeY)
	self:drawQuadInt_buffered(
		drawX, drawY,
		(finishWidth - startWidth) * fontSizeX,
		fontSizeY,
		(tx + startWidth) / 16,
		ty / 16,
		(finishWidth - startWidth) / 16,
		1 / 16,
		0,
		self.colorR, self.colorG, self.colorB, self.colorA
	)
end

function Font:drawQuadInt_buffered(
	x,y,
	w,h,
	tx,ty,
	tw,th,
	angle,
	r,g,b,a
)
	local sceneObj = self.quadSceneObj
	local shader = sceneObj.program
	local uniforms = shader.uniforms

	local costh, sinth
	if angle then
		local radians = math.rad(angle)
		costh = math.cos(radians)
		sinth = math.sin(radians)
	else
		costh, sinth = 1, 0
	end

	if r and g and b and a then
		gl.glUniform4f(uniforms.color.loc, r, g, b, a)
	else
		gl.glUniform4f(uniforms.color.loc, 1, 1, 1, 1)
	end

	gl.glUniform4f(uniforms.rect.loc, x, y, w, h)
	gl.glUniform4f(uniforms.tcRect.loc, tx, ty, tw, th)
	gl.glUniform2f(uniforms.rot.loc, costh, sinth)

	sceneObj.geometry:draw()
end

function Font:drawEnd_buffered()
	local sceneObj = self.quadSceneObj
	local shader = sceneObj.program
	sceneObj:disableAttrs()
	shader:useNone()
	self.tex:unbind()
end
--]=]

return Font

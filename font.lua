local ffi = require 'ffi'
local bit = require 'bit'
local gl = require 'gl'
local class = require 'ext.class'
local glreport = require 'gl.report'

local Font = class()

function Font:init(args)
	self.widths = {}
	self:resetWidths()

	if args and args.image then
		self.image = args.image
		self:calcWidths(args.image)
	end
	self.tex = args.tex
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
				self:drawQuad(cursorX + posX, cursorY + posY, tx, ty, startWidth, finishWidth)
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

function Font:drawBegin(...)
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

function Font:drawQuad(drawX, drawY, tx, ty, startWidth, finishWidth)
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

function Font:drawEnd(...)
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


return Font

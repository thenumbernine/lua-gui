local ffi = require 'ffi'
local bit = require 'bit'
local gl = require 'gl'
local class = require 'ext.class'
local glreport = require 'gl.report'

local Font = class()

function Font:init(args)
	self.widths = {}
	self:resetWidths()
	
	if args and args.tex then
		self:calcWidths(args.tex)
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

-- looks for font texture in self.tex
-- tex is optional and is stored in self.tex
function Font:calcWidths(tex)
	if tex ~= nil then
		self.tex = tex
	end
	if self.tex.id == 0 then
		self:resetWidths()
		return
	end
	
	local int = ffi.new('int[1]')
	gl.glBindTexture(gl.GL_TEXTURE_2D, self.tex.id)

	gl.glGetTexLevelParameteriv(gl.GL_TEXTURE_2D, 0, gl.GL_TEXTURE_WIDTH, int)
	local width = int[0]

	gl.glGetTexLevelParameteriv(gl.GL_TEXTURE_2D, 0, gl.GL_TEXTURE_HEIGHT, int)
	local height = int[0]

	gl.glGetTexLevelParameteriv(gl.GL_TEXTURE_2D, 0, gl.GL_TEXTURE_INTERNAL_FORMAT, int)
	local components = ({
		[gl.GL_RGB] = 3,
		[gl.GL_RGBA] = 4,
		[gl.GL_RGB8] = 3,
		[gl.GL_RGBA8] = 4,
		[gl.GL_COMPRESSED_RGB] = 3,
		[gl.GL_COMPRESSED_RGBA] = 4,
--[[
		[gl.GL_COMPRESSED_RGB_S3TC_DXT1] = 4,
		[gl.GL_COMPRESSED_RGBA_S3TC_DXT1] = 4,
		[gl.GL_COMPRESSED_RGBA_S3TC_DXT5] = 4,
		[gl.GL_COMPRESSED_RGBA_S3TC_DXT3] = 4,
--]]
	})[int[0]]
	glreport('here')
	if not components then
		error("couldn't deduce number of components from internal format 0x"..('%x'):format(int[0]))
	end

	local buffersize = width * height * components
	local buffer = ffi.new('unsigned char[?]', buffersize)
	gl.glGetTexImage(gl.GL_TEXTURE_2D, 0, gl.GL_RGBA, gl.GL_UNSIGNED_BYTE, buffer)

	gl.glBindTexture(gl.GL_TEXTURE_2D, 0)
		
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
						local pixel = buffer[(components-1) + components*((i * letterWidth + x) + width * (j * letterHeight + y))]
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

function Font:drawUnpacked(
	posX, posY,
	fontSizeX, fontSizeY,
	text,
	sizeX, sizeY,
	colorR, colorG, colorB, colorA,
	dontRender,
	singleLine,
	beginCall,
	quadCall,
	endCall
)
	assert(self.tex)
	
	--local text = text:gsub('\r\n', '\n'):gsub('\r', '\n')

	if not dontRender then
		if beginCall then
			beginCall()
		else
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
	end
	
	local cursorX, cursorY = 0, 0
	local maxx = 0
	
	local lastCharWasSpace = true
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
				if quadCall then
					quadCall(cursorX+posX,cursorY+posY,tx,ty,startWidth,finishWidth)
				else			
					for i=1,4 do
						local vtxX, vtxY
						if bit.band(i-1, 2) == 0 then
							vtxX = startWidth
						else
							vtxX = finishWidth
						end
						if bit.band(i-1, 1) == bit.rshift(bit.band(i-1,2),1) then
							vtxY = 0
						else
							vtxY = 1
						end
						gl.glTexCoord2f((tx + vtxX) / 16, (ty + vtxY) / 16)
						gl.glVertex2f(
							(vtxX - startWidth) * fontSizeX + cursorX + posX,
							vtxY * fontSizeY + cursorY + posY)
					end
				end
			end
			cursorX = cursorX + width * fontSizeX
		end
		
		a = a + 1
	end
	
	if not dontRender then
		if endCall then
			endCall()
		else
			gl.glEnd()
			gl.glDisable(gl.GL_TEXTURE_2D)
		end
	end
	
	return maxx, cursorY + fontSizeY
end


return Font

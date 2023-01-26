local gl = require 'gl'
local sdl = require 'ffi.sdl'
local math = require 'ext.math'
local class = require 'ext.class'
local vec2 = require 'vec.vec2'
local vec4 = require 'vec.vec4'
local Widget = require 'gui.widget'

--[[
textListeners = array of objects which, upon text change, calls the objects' "onTextChange" function with the menu as the sole arg

TODO
- give this a border by default
- add text content as a child within the widget
- get rid of text-offset and give the child an offset
- have the text offset follow the cursor
--]]
local TextFieldWidget = class(Widget)

TextFieldWidget.textHasChanged = false
TextFieldWidget.allowFocus = true
TextFieldWidget.cursorPos = 1

TextFieldWidget.cursorColor = vec4(1,1,1,1)
TextFieldWidget.multiLine = false
TextFieldWidget.textPadding = .5

function TextFieldWidget:init(args)
	TextFieldWidget.super.init(self, args)
	self.textListeners = {}
	if not self.text then self.text = '' end
	self.text = tostring(self.text)
end

function TextFieldWidget:onFocus()
	self.textHasChanged = false
	self.cursorPos = #self.text + 1
end

function TextFieldWidget:onBlur()
	if self.textHasChanged then
		if self.onTextChange then self:onTextChange() end

		for _,listener in ipairs(self.textListeners) do
			listener.onTextChange(self)
		end
	end
end

function TextFieldWidget:addTextListener(listener)
	table.insert(self.textListeners, listener)
end

function TextFieldWidget:displayText(ofs)	-- just like Widget except pos is offset
	TextFieldWidget.super.displayText(self, ofs)

	if self.gui.currentFocus == self and math.floor(sdl.SDL_GetTicks() / 500) % 2 == 0 then
		local cursorPosX, cursorPosY = self.gui.font:draw{
			pos = vec2(self.textPadding,0),
			size = vec2(self.sizeValue[1]-2*self.textPadding, self.sizeValue[2]),
			text = self.text:sub(1, self.cursorPos-1),
			fontSize = self.fontSizeValue,
			dontRender = true,
			multiLine = self.multiLine,
		}

		gl.glColor3f(0,0,0)
		gl.glBegin(gl.GL_LINES)
		gl.glVertex2f(cursorPosX + self.textPadding, cursorPosY)
		gl.glVertex2f(cursorPosX + self.textPadding, cursorPosY - self.fontSizeValue[2])
		gl.glEnd()
	end

end

-- some sdl keys aren't being shift'd
local toUpperCase = {
	['1'] = '!',
	['2'] = '@',
	['3'] = '#',
	['4'] = '$',
	['5'] = '%',
	['6'] = '^',
	['7'] = '&',
	['8'] = '*',
	['9'] = '(',
	['0'] = ')',
	['-'] = '_',
	['='] = '+',
	[';'] = ':',
	["'"] = '"',
	[','] = '<',
	['.'] = '>',
	['/'] = '?',
	['`'] = '~',
	['['] = '{',
	[']'] = '}',
	['\\'] = '|',
}

function TextFieldWidget:keyEditString(sdlevent)

	local unicode = sdlevent.key.keysym.unicode
	local sym = sdlevent.key.keysym.sym

	local textBeforeCursor = self.text:sub(1, self.cursorPos-1)
	local textAfterCursor = self.text:sub(self.cursorPos)

	if sym == sdl.SDLK_BACKSPACE then
		textBeforeCursor = textBeforeCursor:sub(1, #textBeforeCursor-1)
		self.text = textBeforeCursor .. textAfterCursor
		self.cursorPos = math.clamp(1, self.cursorPos - 1, #self.text+1)
	elseif sym == sdl.SDLK_RETURN
	or sym == sdl.SDLK_KP_ENTER
	or sym == sdl.SDLK_ESCAPE
	then
		return true
	elseif sym == sdl.SDLK_LEFT then
		self.cursorPos = math.clamp(1, self.cursorPos - 1, #self.text+1)
	elseif sym == sdl.SDLK_RIGHT then
		self.cursorPos = math.clamp(1, self.cursorPos + 1, #self.text+1)
	elseif sym == sdl.SDLK_HOME then
		self.cursorPos = 1
	elseif sym == sdl.SDLK_END then
		self.cursorPos = #self.text + 1
	-- TODO ctrl+left/right for word seeking
	else
		if unicode > 0
		--and unicode < 0x80
		then
			-- not working in SDL ...
			if bit.band(sdlevent.key.keysym.mod, sdl.KMOD_SHIFT) ~= 0 then
				local upperUnicodeChar = toUpperCase[string.char(unicode)]
				if upperUnicodeChar then
					unicode = upperUnicodeChar:byte()
				end
			end

			-- TODO shift
			self.text = textBeforeCursor .. string.char(unicode) .. textAfterCursor
			self.cursorPos = self.cursorPos + 1
		end
	end
	return false
end

function TextFieldWidget:doKeyPress(sdlevent)
	local done = self:keyEditString(sdlevent)
	if done then
		self:loseFocus()
	else
		self.textHasChanged = true
	end
	return true
end

return TextFieldWidget

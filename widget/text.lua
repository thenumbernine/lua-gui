local Widget = require 'gui.widget'
local TextWidget = Widget:subclass()

function TextWidget:init(args)
	TextWidget.super.init(self, args)
	self:setText(self.text)
end

function TextWidget:setText(text)
	self.text = tostring(text)
	local sx, sy = self.gui.font:draw{
		text = self.text,
		fontSize = self.fontSizeValue,
		dontRender = true,
	}
	self:size(sx + 1 + 2 * self.textPadding, sy)
end

return TextWidget

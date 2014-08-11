local Widget = require 'gui.widget'
local class = require 'ext.class'
local vec2 = require 'vec.vec2'

local ScrollContainerWidget = class(Widget)

ScrollContainerWidget.backgroundColorValue = {0,0,0,0}

function ScrollContainerWidget:size(sx, sy)
	local oldsize = vec2(unpack(self.sizeValue))
	local ret = {ScrollContainerWidget.super.size(self, sx, sy)}
	local newsize = vec2(unpack(self.sizeValue))
	local changed = newsize ~= oldsize
	if changed then
		if self.scrollArea then
			self.scrollArea:updateChildSize()
		end
	end
	return unpack(ret)
end

return ScrollContainerWidget

local Widget = require 'gui.widget'
local table = require 'ext.table'
local vec2 = require 'vec.vec2'

local ScrollContainerWidget = Widget:subclass()

ScrollContainerWidget.backgroundColorValue = {0,0,0,0}

function ScrollContainerWidget:size(sx, sy)
	local oldsize = vec2(table.unpack(self.sizeValue))
	local ret = {ScrollContainerWidget.super.size(self, sx, sy)}
	local newsize = vec2(table.unpack(self.sizeValue))
	local changed = newsize ~= oldsize
	if changed then
		if self.scrollArea then
			self.scrollArea:updateChildSize()
		end
	end
	return table.unpack(ret)
end

return ScrollContainerWidget

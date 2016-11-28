local Widget = require 'gui.widget'
local class = require 'ext.class'
local ScrollbarWidget = require 'gui.widget.scrollbar'

local ScrollAreaBarWidget = class(ScrollbarWidget)

function ScrollAreaBarWidget:setSliderPos(pos, forceReset)
	ScrollAreaBarWidget.super.setSliderPos(self, pos, forceReset)
	local panel = self.parent.scrollPanel
	if not panel then return end
	local px, py = panel:pos()
	if self.horz then
		panel:pos(-self.sliderPos, py)
	else
		panel:pos(px, -self.sliderPos)
	end
end

return ScrollAreaBarWidget

local Widget = require 'gui.widget'
local class = require 'ext.class'


local ScrollTabWidget = class(Widget)

function ScrollTabWidget:mouseEvent(event, x, y)
	local mouse = self.gui.mouse
	if mouse.leftPress then
		self.gui:setCapture(self)
		return 'stop'
	end
	
	local sx, sy = self.gui:sysSize()
	
	if mouse.leftDown then
		local mouseMove
		if self.owner.horz then 
			mouseMove = mouse.deltaPos.x * sx
		else
			mouseMove = mouse.deltaPos.y * sy
		end
		self.owner:setSliderPos(
			self.owner.sliderPos + mouseMove * (self.max - self.min) / (self.owner.len - 2 * self.owner.buttonSize - self.owner.tabSize)
		)
		return 'stop'
	end
	if mouse.leftRelease then
		self.gui:setCapture(nil)
		return 'stop'
	end
end

return ScrollTabWidget

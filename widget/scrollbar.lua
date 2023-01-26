local math = require 'ext.math'
local class = require 'ext.class'
local vec4 = require 'vec.vec4'
local Widget = require 'gui.widget'
local ScrollTabWidget = require 'gui.widget.scrolltab'

local ScrollbarWidget = class(Widget)

ScrollbarWidget.backgroundColorValue = vec4(.5, .5, .5, .5)

ScrollbarWidget.tabSize = 1
ScrollbarWidget.buttonSize = 1
ScrollbarWidget.speed = 15

function ScrollbarWidget:init(args)
	ScrollbarWidget.super.init(self, args)

	if args.horz then
		self.scrollLeft = self.gui:widget{text='<', parent={self}, size={1,1}}
		self.scrollRight = self.gui:widget{text='>', parent={self}, size={1,1}}
		self.scrollTab = self.gui:widget{class=ScrollTabWidget, pos={self.tabSize, 1}, parent={self}}
	else
		self.scrollUp = self.gui:widget{text='^', parent={self}, size={1,1}}
		self.scrollDown = self.gui:widget{text='v', parent={self}, size={1,1}}
		self.scrollTab = self.gui:widget{class=ScrollTabWidget, pos={1, self.tabSize}, parent={self}}
	end
	self.scrollTab.owner = self

	self.horz = args.horz
	self.sliderPos = args.sliderPos
	self.min = args.min
	self.max = args.max
	if self.max < self.min then
		self.min, self.max = self.max, self.min
	end

	self.scrollbarListeners = {}
	self:setLength(assert(args.len))
end

function ScrollbarWidget:setSliderPos(newpos, forceReset)
	if self.sliderPos == newpos and not forceReset then return end
	self.sliderPos = math.clamp(self.min, newpos, self.max)
	local maxtomin = math.max(self.max - self.min, .001)
	local tabPos = (self.len - 2 * self.buttonSize - self.tabSize) * (self.sliderPos - self.min) / maxtomin + self.buttonSize
	local px, py = self:pos()
	if not self.horz then
		self.scrollTab:pos(px, tabPos)
	else
		self.scrollTab:pos(tabPos, py)
	end
	self.scrollTab:backgroundColor(0,0,0,1)
	for _,listener in ipairs(self.scrollbarListeners) do
		listener.onSliderChange(self)
	end
end

function ScrollbarWidget:addScrollbarListener(listener)
	table.insert(self.scrollbarListeners, listener)
end

function ScrollbarWidget:setRange(min,max)
	if max < min then min, max = max, min end
	self.min, self.max = min, max
	self:setSliderPos(self.sliderPos, true)
end

function ScrollbarWidget:mouseEvent(event, x, y)
	if self.gui.mouse.leftDown then
		local speed = self.speed * self.gui.timer.delta

		if self.selectedChild == self.scrollUp
		or self.selectedChild == self.scrollLeft
		then
			self:setSliderPos(self.sliderPos - speed)
		end

		if self.selectedChild == self.scrollDown
		or self.selectedChild == self.scrollRight
		then
			self:setSliderPos(self.sliderPos + speed)
		end
		return 'stop'
	end
	if ScrollbarWidget.super.mouseEvent then
		return ScrollbarWidget.super.mouseEvent(self, event, x, y)
	end
end

function ScrollbarWidget:size(x,y)
	if x ~= nil or y ~= nil then error("cannot set size") end
	return ScrollbarWidget.super.size(self)
end

function ScrollbarWidget:setLength(len)
	self.len = math.max(len, 1)
	if not self.horz then
		self.scrollDown:pos(0, self.len - self.buttonSize)
		ScrollbarWidget.super.size(self, 1, self.len)
	else
		self.scrollRight:pos(self.len - self.buttonSize, 0)
		ScrollbarWidget.super.size(self, self.len, 1)
	end
	self:setSliderPos(self.sliderPos, true)
end

return ScrollbarWidget

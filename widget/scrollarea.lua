local Widget = require 'gui.widget'
local class = require 'ext.class'
local ScrollAreaBarWidget = require 'gui.widget.scrollareabar'
local ScrollContainerWidget = require 'gui.widget.scrollcontainer'
local vec2 = require 'vec.vec2'


local ScrollAreaWidget = class(Widget)

function ScrollAreaWidget:init(args)
	ScrollAreaWidget.super.init(self, args)

	self.scrollPanel = args.scrollPanel
	assert(not self.scrollPanel)
	if not self.scrollPanel then
		self.scrollPanel = self.gui:widget{
			class = ScrollContainerWidget,
			parent = {self},
			size = {self:size()},
		}
	end
	self.scrollPanel.scrollArea = self

	local fitsizeX, fitsizeY = math.max(0, self.sizeValue[1] - 2), math.max(0, self.sizeValue[2] - 2)
	self.scrollPanel:pos(0,0)

	local scrollsizeX, scrollsizeY = math.max(0, self.scrollPanel.sizeValue[1] - fitsizeX), math.max(0, self.scrollPanel.sizeValue[2] - fitsizeY)

	self.horz = self.gui:widget{class=ScrollAreaBarWidget, parent={self}, pos={0, self.sizeValue[2]-1}, len=self.sizeValue[1]-1, horz=true, min=0, max=scrollsizeX, sliderPos=0, owner=self}
	self.vert = self.gui:widget{class=ScrollAreaBarWidget, parent={self}, pos={self.sizeValue[1]-1, 0}, len=self.sizeValue[2]-1, horz=false, min=0, max=scrollsizeY, sliderPos=0, owner=self}
end

function ScrollAreaWidget:size(...)
	local oldsize = vec2(unpack(self.sizeValue))
	local ret = {ScrollAreaWidget.super.size(self, ...)}
	local newsize = vec2(unpack(self.sizeValue))
	if oldsize ~= newsize and self.horz and self.vert then self:updateChildSize() end
	return unpack(ret)
end

function ScrollAreaWidget:updateChildSize()
	local fitsize = vec2(self:size()) - vec2(1,1)
	local scrollsize = vec2(self.scrollPanel:size()) - fitsize
	scrollsize[1] = math.max(scrollsize[1], 0)
	scrollsize[2] = math.max(scrollsize[2], 0)
	self.horz:setRange(0, scrollsize[1])
	self.vert:setRange(0, scrollsize[2])
	self.scrollPanel:pos(-self.horz.sliderPos, -self.vert.sliderPos)
	local size = vec2(self:size())
	self.horz:pos(0, size[2]-1)
	self.horz:setLength(size[1] - 1)
	self.horz.visible = scrollsize[1] > 0
	self.vert:pos(size[1]-1, 0)
	self.vert:setLength(size[2] - 1)
	self.vert.visible = scrollsize[2] > 0
end

return ScrollAreaWidget

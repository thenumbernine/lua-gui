#!/usr/bin/env luajit
local gl = require 'gl'
local App = require 'glapp':subclass()
local GUI = require 'gui'

App.viewDist = 2
function App:initGL()
	self.gui = GUI{
		mouse = self.mouse,	-- orbit behavior makes a mouse
		drawImmediateMode = false,
	}

	self.text = require 'gui.widget.text'{
		text = 'testing',
		gui = self.gui,
		parent = {self.gui.root},	-- why did I require the arg to be wrapped in {} ...
		--backgroundColor = {0,0,1,1},	-- TODO
		--size = {30, 5},	-- size gets resized by .text so...
	}
	--self.text:size(30, 5)	-- hmm can't see backgroundColor ...

	self.vx = .001
	self.vy = .001
end

function App:update()
	gl.glClear(gl.GL_COLOR_BUFFER_BIT)
	self.gui:update()

	-- why did I wrap function getters like this ...
	local gw, gh = self.gui.root:size()
	local tx, ty = self.text:pos()
	local tw, th = self.text:size()
	tx = tx + self.vx
	ty = ty + self.vy
	if tx < 0 then
		tx = 0
		self.vx = math.abs(self.vx)
	end
	if tx + tw > gw then
		tx = gw - tw
		self.vx = -math.abs(self.vx)
	end
	if ty < 0 then
		ty = 0
		self.vy = math.abs(self.vy)
	end
	if ty + th > gh then
		ty = gh - th
		self.vy = -math.abs(self.vy)
	end
	self.text:pos(tx, ty)
end

return App():run()

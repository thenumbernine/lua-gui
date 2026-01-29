#!/usr/bin/env luajit
local ffi = require 'ffi'
local assert = require 'ext.assert'
local path = require 'ext.path'
local Image = require 'image'
local gl = require 'gl'
local GLTex2D = require 'gl.tex2d'
local GLSceneObject = require 'gl.sceneobject'
local ft = require 'gui.ffi.freetype'

local App = require 'glapp.orbit'()
App.viewDist = 2
function App:initGL()
	local charWidth = 16
	local charHeight = 16
	local charsWide = 16
	local charsHigh = 16
	local width = charWidth * charsWide
	local height = charHeight * charsHigh
	local image = Image(width, height, 4, 'uint8_t')


	-- freetype init
	local library = ffi.new'FT_Library[1]'
	assert.eq(0, ft.FT_Init_FreeType(library), 'FT_Init_Library')
			
	local fontfilename = "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf";
	local _ = path(fontfilename):exists() or error("failed to find "..fontfilename)

	local face = ffi.new'FT_Face[1]'
	assert.eq(0, ft.FT_New_Face(
		library[0],
		fontfilename,
		0,				-- FT_Long face_index ... ?
		face
	), 'FT_New_Face')
	assert.eq(0, ft.FT_Set_Pixel_Sizes(face[0], 0, charHeight), 'FT_Set_Pixel_Sizes')

	for j=0,charsHigh-1 do
		for i=0,charsWide-1 do
			local ch = bit.band(0xff, i + charsWide * j + 32)
			local chstr = string.char(ch)

			-- ex: render 'X'
			assert.eq(0, ft.FT_Load_Char(face[0], ch, ft.FT_LOAD_RENDER), 'FT_Load_Char')

			local slot = face[0].glyph	-- FT_GlyphSlot
			local bitmap = slot[0].bitmap	-- FT_Bitmap 

			local srcp = bitmap.buffer
			local srcw = bitmap.width
			local srch = bitmap.rows

			for y=0,srch-1 do
				local dstp = image.buffer + image.channels * (i * charWidth + (y + j * charHeight) * image.width)
				for x=0,srcw-1 do
					dstp[0] = srcp[0] dstp=dstp+1
					dstp[0] = srcp[0] dstp=dstp+1
					dstp[0] = srcp[0] dstp=dstp+1
					dstp[0] = srcp[0] dstp=dstp+1
					srcp=srcp+1
				end
			end
		end
	end

	ft.FT_Done_Face(face[0])
	ft.FT_Done_FreeType(library[0])

	-- now try to use freetype ...

	self.tex = GLTex2D{
		image = image,
		minFilter = gl.GL_NEAREST,
		magFilter = gl.GL_NEAREST,
	}:unbind()
	self.obj = GLSceneObject{
		program = {
			version = 'latest',
			precision = 'best',
			vertexCode = [[
layout(location=0) in vec2 vertex;
out vec2 texcoord;

uniform mat4 mvProjMat;

void main() {
	texcoord = vec2(vertex.x, 1. - vertex.y);
	gl_Position = mvProjMat * vec4(vertex * 2. - 1., 0., 1.);
}
]],
			fragmentCode = [[
in vec2 texcoord;
layout(location=0) out vec4 fragColor;

uniform sampler2D tex;

void main() {
	fragColor = texture(tex, texcoord);
}
]],
			uniforms = {
				tex = 0,
			},
		},
		vertexes = {
			data = {
				0,0, 1,0, 0,1, 1,1,
			},
		},
		geometry = {
			mode = gl.GL_TRIANGLE_STRIP,
			count = 4,
		},
		texs = {
			self.tex,
		},
	}
end

function App:update()
	App.super.update(self)
	gl.glClear(gl.GL_COLOR_BUFFER_BIT)
	self.obj.uniforms.mvProjMat = self.view.mvProjMat.ptr
	self.obj:draw()
end

return App():run()

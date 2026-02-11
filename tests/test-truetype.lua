#!/usr/bin/env luajit
local cmdline = require 'ext.cmdline'(...)
local ffi = require 'ffi'
local assert = require 'ext.assert'
local path = require 'ext.path'
local Image = require 'image'
local gl = require 'gl.setup'(cmdline.gl)
local GLTex2D = require 'gl.tex2d'
local GLSceneObject = require 'gl.sceneobject'
local ft = require 'gui.ffi.freetype'

local App = require 'glapp.orbit'()
App.viewDist = 2
function App:initGL()

	-- now try to use freetype ...
	local image = require 'gui.font':trueTypeToImage()

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
	vec2 charuv = mod(texcoord * 16., 1.);
	fragColor = texture(tex, texcoord);
	fragColor.xy += charuv;
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
	gl.glClearColor(0,0,1,1)
end

function App:update()
	App.super.update(self)
	gl.glClear(gl.GL_COLOR_BUFFER_BIT)
	self.obj.uniforms.mvProjMat = self.view.mvProjMat.ptr
	self.obj:draw()
end

return App():run()

package = "gui"
version = "dev-1"
source = {
	url = "git+https://github.com/thenumbernine/lua-gui.git"
}
description = {
	summary = "LuaJIT OpenGL SDL-based widget library.",
	detailed = "LuaJIT OpenGL SDL-based widget library.",
	homepage = "https://github.com/thenumbernine/lua-gui",
	license = "MIT"
}
dependencies = {
	"lua >= 5.1"
}
build = {
	type = "builtin",
	modules = {
		["gui.font"] = "font.lua",
		["gui"] = "gui.lua",
		["gui.mouse"] = "mouse.lua",
		["gui.timer"] = "timer.lua",
		["gui.widget"] = "widget.lua",
		["gui.widget.scrollarea"] = "widget/scrollarea.lua",
		["gui.widget.scrollareabar"] = "widget/scrollareabar.lua",
		["gui.widget.scrollbar"] = "widget/scrollbar.lua",
		["gui.widget.scrollcontainer"] = "widget/scrollcontainer.lua",
		["gui.widget.scrolltab"] = "widget/scrolltab.lua",
		["gui.widget.text"] = "widget/text.lua",
		["gui.widget.textfield"] = "widget/textfield.lua"
	}
}

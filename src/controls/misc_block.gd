extends PanelContainer

var blockName: String = "": get = getBlockName, set = fail

signal mainOpened(object)

func _ready():
	hideMain()

func getBlockName() -> String: #should be overwritten in the Inherited Scene
	return ""

func fail(_anything):
	assert(false)

func hideMain():
	%Main.hide()
	size_flags_stretch_ratio = 1

func openMain(_data: Dictionary = {}):
	size_flags_stretch_ratio = 100
	%Main.show()
	mainOpened.emit(self)

func _on_open_pressed():
	openMain()

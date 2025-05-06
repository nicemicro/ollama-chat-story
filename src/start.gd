extends MarginContainer

var ollamaUrl: String = "http://localhost:11434"
var modelList: Array = []
var selectedModel: int = -1

func _ready():
	%HTTPRequest.request_completed.connect(_on_request_completed)

func _on_connect_pressed():
	if %OllamaUrl.text != "":
		ollamaUrl = "http://" + %OllamaUrl.text
	%HTTPRequest.request(ollamaUrl + "/api/tags") 

func _on_request_completed(result, response_code, headers, body):
	if response_code == 200:
		%StatusLabel.text = "Connected"
	else:
		%StatusLabel.text = "Error, Ollama not running"
		%MainInterface.connectionSevered()
		%StartMenu.show()
		%Models.hide()
		selectedModel = -1
		return
	var json = JSON.parse_string(body.get_string_from_utf8())
	for key in json:
		match key:
			"models":
				show_models(json[key])

func show_models(model_list: Array):
	if len(model_list) == 0:
		%StatusLabel.text = "No models were preloaded for Ollama"
		return
	%Models.show()
	var popups: PopupMenu = %SelectModel.get_popup()
	popups.id_pressed.connect(_on_model_selected)
	popups.clear()
	selectedModel = -1
	modelList = []
	%UseModel.disabled = true
	%SelectedModel.text = "None"
	for model in model_list:
		popups.add_item(model["name"])
		modelList.append(model["model"])

func _on_model_selected(id: int):
	selectedModel = id
	%SelectedModel.text = modelList[selectedModel]
	%UseModel.disabled = false

func _on_use_model_pressed():
	%StartMenu.hide()
	%MainInterface.show()
	%MainInterface.model = modelList[selectedModel]

func _on_main_interface_go_back():
	%StartMenu.show()
	%MainInterface.hide()

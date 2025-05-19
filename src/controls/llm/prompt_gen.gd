extends VBoxContainer

const fileName: String = "res://controls/llm/default_prompts.json"

var _systemPrompts: Array
var _prompts: Dictionary
var _instructions: Dictionary
var _constructions: Dictionary

var systemPrompts: Array: get = getSystemPrompts, set = fail

func _ready():
	if not FileAccess.file_exists(fileName):
		return
	var file = FileAccess.open(fileName, FileAccess.READ)
	var text: String = file.get_as_text()
	text = text.replace("\t", "")
	text = text.replace("\n", " ")
	var jsonConverter = JSON.new()
	jsonConverter.parse(text)
	var jsonData = jsonConverter.get_data()
	_systemPrompts = jsonData["system_prompt"]
	_prompts = jsonData["prompts"]
	_instructions = jsonData["instructions"]
	_constructions = jsonData["constructions"]

func getSystemPrompts() -> Array:
	return _systemPrompts.duplicate()

func fail(_value):
	assert(false)

func generatePrompt(draft: String, dataPackage: Dictionary, instruction: String) -> String:
	var prompt: String = ""
	var character: String = ""
	if instruction.contains(":"):
		character = instruction.get_slice(":", 1)
		instruction = instruction.get_slice(":", 0)
	for key in _constructions[instruction]:
		if key.left(1) == "_":
			prompt += _prompts[key].pick_random() + "\n"
		if key in dataPackage:
			prompt += _promptPartConstruct(_prompts[key].pick_random(), dataPackage[key]) + "\n"
	var instructionPrompt: String
	if instruction + ":" + character in _instructions:
		instructionPrompt = _instructions[instruction + ":" + character].pick_random()
	elif instruction + ":%_" in _instructions:
		instructionPrompt = _instructions[instruction + ":%_"].pick_random()
		instructionPrompt = instructionPrompt.replace("%_", character)
	else:
		assert(false)
	prompt += instructionPrompt.replace("%d", draft)
	if prompt.right(1) == "\n":
		prompt = prompt.left(-1)
	return prompt

func _promptPartConstruct(promptTempl: String, dataPart) -> String:
	var promptPart: String = ""
	var repeating: String
	if not dataPart is Array and not dataPart is Dictionary:
		dataPart = [dataPart]
	var index: int = 0
	for data in dataPart:
		var replaceWith: String = data
		if dataPart is Dictionary:
			replaceWith = dataPart[data]
		promptTempl = promptTempl.replace("%" + str(index), replaceWith)
	if promptTempl.contains("%t"):
		promptPart = promptTempl.get_slice("%t", 0)
		repeating = promptTempl.get_slice("%t", 1)
	else:
		repeating = promptTempl
	for data in dataPart:
		if dataPart is Array:
			promptPart += repeating.replace("%v", data)
		if dataPart is Dictionary:
			var value: String = dataPart[data]
			promptPart += (
				repeating.replace("%k", data).replace("%v", value)
			)
	return promptPart

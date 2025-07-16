extends HSplitContainer

const chapterSceneUID = "uid://dvj16bw73cbsn"
const generateButtonUID = "uid://bnr5ulamhqxp4"

var model: String = ""
var miscTools: Dictionary = {}
var characters: Dictionary = {}

func _ready():
	for child in %MiscTools.get_children():
		child.mainOpened.connect(_onMiscToolOpened)
		miscTools[child.blockName] = child
	for node in get_tree().get_nodes_in_group("llmButton"):
		node.disabled = true
	%Chapters.set_tab_title(0, %Chapters.get_child(0).chapterName)
	connectChapterSignals(%Chapters.get_child(0))
	miscTools["CharacterEditor"].addChapter(%Chapters.get_child(0).chapterName)

func connectChapterSignals(newChapter):
	newChapter.addCharacter.connect(_on_addCharacter)
	newChapter.chapterTitleChange.connect(on_chapterTitleChange)
	newChapter.hideCharacter.connect(_on_hideCharacter)
	newChapter.unhideCharacter.connect(_on_unhideCharacter)
	newChapter.openCharacterStory.connect(_on_openCharacterStory)
	newChapter.deleteCharacter.connect(_on_deleteCharacter)
	newChapter.paragraphCharacter.connect(_on_paragraphCharacter)
	newChapter.paragrapAdded.connect(_on_paragraphAdded)
	newChapter.summarizeParagraphs.connect(_on_paragraphSummary)
	newChapter.summarizeSummaries.connect(_on_paragraphSummary)

func _input(event):
	if not is_node_ready():
		return
	if $%ChatInput.has_focus():
		if event is InputEventKey and event.is_pressed():
			if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
				sendChatMessage()

func _onMiscToolOpened(node: Control):
	for child in %MiscTools.get_children():
		if child == node:
			continue
		child.hideMain()

func _on_chat_input_text_changed():
	var newText: String = %ChatInput.text
	newText = newText.replace("\n", " ").rstrip(" ")
	if newText == "":
		%ChatInput.text = newText

func _on_paragraphAdded(paragrapNode):
	paragrapNode.ollamaContinue.connect(llmParagraphExpand)

func _on_chat_send_pressed():
	sendChatMessage()

func sendChatMessage():
	if %ChatWho.selected == -1:
		%NoCharacterSel.show()
		return
	var newText: String = %ChatInput.text
	newText = newText.replace("\n", " ").rstrip(" ")
	if newText.is_empty():
		return
	var activeChapter = %Chapters.get_current_tab_control()
	newText = newText.replace("\n", " ").rstrip(" ")
	var textColor: Color = Globals.narratorColor
	var characterId: int = %ChatWho.selected
	var characterName: String = "Narrator"
	if characterId != 0:
		characterName = %ChatWho.get_item_text(characterId)
		textColor = characters[characterName]["color"]
	newText = characterName + ": " + newText
	activeChapter.addParagraph(newText, textColor)
	%ChatInput.text = ""
	%LoadButton.disabled = true
	if %AutoReplyWho.get_selected_id() != 0:
		var selectedId: int = %AutoReplyWho.get_item_index(%AutoReplyWho.get_selected_id())
		llmParagraphGenerate(%AutoReplyWho.get_item_text(selectedId))

func _gatherDataFromUi(dataPackage: Dictionary, chapterNode):
	if len(%TitleEdit.text) > 0:
		dataPackage["title"] = %TitleEdit.text
	if len(%ScenarioEdit.text) > 0:
		dataPackage["scenario"] = %ScenarioEdit.text.replace("\n", " ")
	if len(chapterNode.getChapterTitle()) > 0:
		dataPackage["chapter_title"] = chapterNode.getChapterTitle()
	if len(chapterNode.getChapterBackground()) > 0:
		dataPackage["chapter_scenario"] = (
			chapterNode.getChapterBackground().replace("\n", " ")
		)
	if len(%ContextEdit.text) > 0:
		dataPackage["current_context"] = %ContextEdit.text.replace("\n", " ")

func _gatherCharacters(dataPackage: Dictionary, chapterNode):
	var chapterName = chapterNode.chapterName
	for characterButton in get_tree().get_nodes_in_group("characterButton"):
		if characterButton.visible:
			var suppCharName: String = characterButton.text
			if "characters" not in dataPackage:
				dataPackage["characters"] = {}
			dataPackage["characters"][suppCharName] = (
				characters[suppCharName]["chapters"][chapterName]
			)

func extractSummary(allParagrs: Array, summaries: Array, paragraphs: Array):
	for paragraphText in allParagrs:
		if paragraphText.begins_with("SUMMARY") and ":" in paragraphText:
			summaries.push_back(paragraphText.split(":", false, 2)[1])
		else:
			paragraphs.push_back(paragraphText)

func llmParagraphGenerate(characterName: String):
	if not %LLMControl.isLlmConnected():
		%LlmNotConnDial.show()
		return
	var chapterNode = %Chapters.get_current_tab_control()
	var dataPackage: Dictionary
	var draft: String = ""
	var prompt: String
	var instruction: String = "new_paragraph"
	_gatherDataFromUi(dataPackage, chapterNode)
	if %GenerateByText.button_pressed and len(%ChatInput.text) > 0:
		draft = %ChatInput.text.replace("\n", " ")
		instruction = "expand_paragraph"
	_gatherCharacters(dataPackage, chapterNode)
	dataPackage["paragraphs_summaries"] = chapterNode.getParagraphs()
	dataPackage["paragraphs"] = []
	dataPackage["summary"] = []
	extractSummary(
		dataPackage["paragraphs_summaries"], dataPackage["summary"], dataPackage["paragraphs"]
	)
	if not dataPackage["paragraphs"].is_empty():
		dataPackage["last_paragraph"] = dataPackage["paragraphs"].pop_back()
	if dataPackage["paragraphs"].is_empty():
		dataPackage.erase("paragraphs")
	if dataPackage["summary"].is_empty():
		dataPackage.erase("summary")
	instruction += ":" + characterName
	prompt = %LLMControl.generatePrompt(draft, dataPackage, instruction)
	var tunnel: LlmTunnel = %LLMControl.addToOllamaQueue(
		"generate", prompt
	)
	var color: Color = Globals.narratorColor
	if characterName in characters:
		color = characters[characterName]["color"]
	chapterNode.addOllamaPragr(tunnel, characterName, color)

func llmParagraphExpand(paragrObject, text: String, characterName: String):
	if not %LLMControl.isLlmConnected():
		%LlmNotConnDial.show()
		return
	var chapterNode = %Chapters.get_current_tab_control()
	var dataPackage: Dictionary
	var prompt: String
	var instruction: String = "continue_paragraph"
	_gatherDataFromUi(dataPackage, chapterNode)
	_gatherCharacters(dataPackage, chapterNode)
	if "characters" not in dataPackage:
		dataPackage["characters"] = {
			characterName: characters[characterName]["chapters"][chapterNode.chapterName]
		}
	if characterName not in dataPackage["characters"]:
		dataPackage["characters"][characterName] = (
			characters[characterName]["chapters"][chapterNode.chapterName]
		)
	if paragrObject.get_index() > 0:
		dataPackage["paragraphs"] = chapterNode.getParagraphs(paragrObject.get_index()-1)
	instruction += ":" + characterName
	prompt = %LLMControl.generatePrompt(text, dataPackage, instruction)
	var tunnel: LlmTunnel = %LLMControl.addToOllamaQueue(
		"generate", prompt
	)
	paragrObject.connectLlm(tunnel)

func llmSummaryGenerate(
	paragraphList: Array, afterIndex: int, command: String, useDraft: bool
):
	assert(not paragraphList.is_empty())
	if not %LLMControl.isLlmConnected():
		%LlmNotConnDial.show()
		return
	var chapterNode = %Chapters.get_current_tab_control()
	var dataPackage: Dictionary
	var prompt: String
	var draft: String = ""
	var responseTypes: Dictionary = {
		"paragraphs_summary": "SUMMARY^1",
		"summary_summary": "SUMMARY^2",
		"ask_question": "ANSWER"
	}
	if useDraft:
		draft = %ChatInput.text
		if draft.is_empty():
			return
	_gatherDataFromUi(dataPackage, chapterNode)
	dataPackage["paragraphs_summaries"] = paragraphList
	dataPackage["paragraphs"] = []
	dataPackage["summary"] = []
	extractSummary(
		dataPackage["paragraphs_summaries"], dataPackage["summary"], dataPackage["paragraphs"]
	)
	if not dataPackage["paragraphs"].is_empty():
		dataPackage["last_paragraph"] = dataPackage["paragraphs"].pop_back()
	if dataPackage["paragraphs"].is_empty():
		dataPackage.erase("paragraphs")
	if dataPackage["summary"].is_empty():
		dataPackage.erase("summary")
	prompt = %LLMControl.generatePrompt(draft, dataPackage, command)
	var tunnel: LlmTunnel = %LLMControl.addToOllamaQueue(
		"generate", prompt
	)
	var color: Color = Globals.narratorColor
	chapterNode.addOllamaPragr(tunnel, responseTypes[command], color, afterIndex)

func on_chapterTitleChange(newTitle, object):
	var idx: int = %Chapters.get_tab_idx_from_control(object)
	%Chapters.set_tab_tooltip(idx, newTitle)

func _on_openCharacterStory(character, chapter):
	assert(character in characters)
	var characterStory: String = ""
	if chapter in characters[character]["chapters"]:
		characterStory = characters[character]["chapters"][chapter]
	miscTools["CharacterEditor"].openMain(
		{
			"chapter": chapter,
			"character": character,
			"story": characterStory,
			"color": characters[character]["color"]
		}
	)

func _on_deleteCharacter(characterName: String, chapterName: String):
	#TODO: this will DEFINITELY fail once we have multiple chapters though
	if chapterName in characters[characterName]["chapters"]:
		characters[characterName]["chapters"].erase(chapterName)
	if characters[characterName]["chapters"].is_empty():
		characters.erase(characterName)
		miscTools["CharacterEditor"].removeCharacter(characterName)
	#TODO: needs to remove the character name stuff from the chapter too

func _on_addCharacter(character: String, chapter: String):
	_addCharacter(character, chapter)

func _addCharacter(character: String, chapter: String, description: String = ""):
	if character in characters:
		assert(chapter not in characters[character]["chapters"])
	else:
		var newColor: Color = Color(
			randf_range(0, 0.4), randf_range(0, 0.4), randf_range(0, 0.4)
		)
		characters[character] = {"color": newColor}
		for child in %Chapters.get_children():
			child.changeCharacterColor(character, newColor)
	characters[character]["chapters"] = {chapter: description}
	miscTools["CharacterEditor"].addCharacter(character, chapter)
	%LoadButton.disabled = true
	if %Chapters.get_current_tab_control().chapterName != chapter:
		return
	var packedScene = preload(generateButtonUID)
	var newGenerateButton = packedScene.instantiate()
	newGenerateButton.text = character
	newGenerateButton.add_to_group("llmButton")
	newGenerateButton.add_to_group("characterButton")
	newGenerateButton.buttonPressed.connect(llmParagraphGenerate)
	if %LLMControl.isLlmConnected():
		newGenerateButton.disabled = false
	else:
		newGenerateButton.disabled = true
	%CharacterButtons.add_child(newGenerateButton)
	%ChatWho.add_item(character)
	%AutoReplyWho.add_item(character)

func _on_hideCharacter(character: String):
	for characterButton in get_tree().get_nodes_in_group("characterButton"):
		if characterButton.text == character:
			characterButton.hide()
			break
	_hideCharfromButt(character, %ChatWho)
	_hideCharfromButt(character, %AutoReplyWho)

func _hideCharfromButt(character: String, button: OptionButton):
	var selectedIndex: int = button.get_item_index(button.get_selected_id())
	for index in range(button.item_count):
		if button.get_item_text(index) == character:
			button.remove_item(index)
			if index == selectedIndex:
				button.select(0)
			elif index < selectedIndex:
				button.select(selectedIndex-1)
			break

func _on_unhideCharacter(character: String):
	_unhideCharFromButt(character, %ChatWho, "Narrator")
	_unhideCharFromButt(character, %AutoReplyWho, "No reply")

func _unhideCharFromButt(character: String, button: OptionButton, default: String):
	var selectedIndex: int = button.get_item_index(button.get_selected_id())
	var selectedText: String = button.get_item_text(selectedIndex)
	var adjust: int = 1
	button.clear()
	button.add_item(default)
	for characterButton in get_tree().get_nodes_in_group("characterButton"):
		if characterButton.text == character:
			characterButton.show()
			adjust = 0 #if the unhidden character comes up first, it will be turned to +1 later
		if characterButton.text == selectedText:
			adjust = 1 #if the selected character comes up first, it will be zeroed later
		if characterButton.visible:
			button.add_item(characterButton.text)
	button.select(selectedIndex + adjust)

func _on_paragraphCharacter(characterName: String, chapter):
	var newChar: bool = false
	if (
		not characterName.to_lower() in Globals.nonCharParagrs and
		not characterName in characters
	):
		newChar = true
		_on_addCharacter(characterName, chapter)
	for child in %Chapters.get_children():
		if child.chapterName == chapter:
			var newColor: Color = Globals.narratorColor
			if characterName in characters:
				newColor = characters[characterName]["color"]
			child.changeCharacterColor(characterName, newColor)
			if newChar:
				child.addFilledInCharater(characterName, newColor)
			break

func _on_character_editor_character_change(text, newColor, character, chapter):
	assert(character in characters)
	characters[character]["color"] = newColor
	characters[character]["chapters"][chapter] = text
	for child in %Chapters.get_children():
		child.changeCharacterColor(character, newColor)

func _on_paragraphSummary(
	paragraphList: Array, afterIndex: int, command: String, draft: bool = false
):
	llmSummaryGenerate(paragraphList, afterIndex, command, draft)

func _on_llm_control_connection_severed():
	for node in get_tree().get_nodes_in_group("llmButton"):
		node.disabled = true

func _on_llm_control_llm_connected():
	for node in get_tree().get_nodes_in_group("llmButton"):
		node.disabled = false

func _on_save_button_pressed():
	%SaveDialog.show()

func _on_save_dialog_file_selected(path):
	saveScenario(path)

func _on_load_button_pressed():
	%LoadDialog.show()

func _on_load_dialog_file_selected(path):
	loadScenario(path)

func saveScenario(fileName: String):
	var scenarioData: Dictionary = {}
	scenarioData["Title"] = %TitleEdit.text
	scenarioData["Outline"] = %ScenarioEdit.text
	scenarioData["CharacterData"] = characters
	scenarioData["ChapterData"] = {}
	for chapter in %Chapters.get_children():
		var chapterName = chapter.chapterName
		scenarioData["ChapterData"][chapterName] = chapter.getAllData()
	scenarioData["Context"] = %ContextEdit.text
	var fileSave = FileAccess.open(fileName, FileAccess.WRITE)
	fileSave.store_line(JSON.stringify(scenarioData, "\t"))
	fileSave.close()

func loadScenario(fileName: String):
	if not FileAccess.file_exists(fileName):
		return
	var file = FileAccess.open(fileName, FileAccess.READ)
	var jsonConverter = JSON.new()
	jsonConverter.parse(file.get_as_text())
	var scenarioData = jsonConverter.get_data()
	var chapterCharacterMatrix: Dictionary = {}
	characters = {}
	for child in %Chapters.get_children():
		%Chapters.remove_child(child)
	miscTools["CharacterEditor"].clearSelectors()
	if "Title" in scenarioData:
		%TitleEdit.text = scenarioData["Title"]
	if "Outline" in scenarioData:
		%ScenarioEdit.text = scenarioData["Outline"]
	if "Context" in scenarioData:
		%ContextEdit.text = scenarioData["Context"]
	if "ChapterData" in scenarioData:
		for chapterName in scenarioData["ChapterData"]:
			var chapterData = scenarioData["ChapterData"][chapterName]
			var packedScene = preload(chapterSceneUID)
			var newChapter = packedScene.instantiate()
			var title: String = ""
			if "Title" in chapterData:
				title = chapterData["Title"]
			var background: String = ""
			if "Background" in chapterData:
				background = chapterData["Background"]
			if "Characters" in chapterData:
				for characterName in chapterData["Characters"]:
					if not characterName in chapterCharacterMatrix:
						chapterCharacterMatrix[characterName] = {}
					chapterCharacterMatrix[characterName][chapterName] = (
						chapterData["Characters"][characterName]
					)
			connectChapterSignals(newChapter)
			newChapter.setProperties(
				chapterName, title, background
			)
			%Chapters.add_child(newChapter)
			var idx: int = %Chapters.get_tab_idx_from_control(newChapter)
			%Chapters.set_tab_title(idx, chapterName)
			%Chapters.set_tab_tooltip(idx, title)
			miscTools["CharacterEditor"].addChapter(chapterName)
	if "CharacterData" in scenarioData:
		for characterName in scenarioData["CharacterData"]:
			var characterData = scenarioData["CharacterData"][characterName]
			var characterColor: Color
			if "color" in characterData:
				characterColor = loadColorFromText(characterData["color"])
			else:
				characterColor = Color(
					randf_range(0, 0.4), randf_range(0, 0.4), randf_range(0, 0.4)
				)
			characters[characterName] = {
				"color" = characterColor,
				"chapters" = {}
			}
			if "chapters" in characterData:
				for chapterName in characterData["chapters"]:
					_addCharacter(
						characterName,
						chapterName,
						characterData["chapters"][chapterName]
					)
			if characterName in chapterCharacterMatrix:
				for chapterName in chapterCharacterMatrix[characterName]:
					var chapterNode = null
					for child in %Chapters.get_children():
						if child.chapterName == chapterName:
							chapterNode = child
							break
					if chapterNode == null:
						continue
					chapterNode.addFilledInCharater(
						characterName, characterColor,
						not chapterCharacterMatrix[characterName][chapterName]
					)
					chapterNode.changeCharacterColor(characterName, characterColor)
	if "ChapterData" in scenarioData:
		for chapterName in scenarioData["ChapterData"]:
			var chapterNode = null
			for child in %Chapters.get_children():
				if child.chapterName == chapterName:
					chapterNode = child
					break
			if chapterNode != null and "Paragraphs" in scenarioData["ChapterData"][chapterName]:
				var paragraphs: Array = scenarioData["ChapterData"][chapterName]["Paragraphs"]
				for paragraph in paragraphs:
					var paragrNode = chapterNode.addParagraph(paragraph, Globals.narratorColor)
					var charName: String = paragrNode.paragrCharacter
					if charName.to_lower() in Globals.nonCharParagrs:
						continue
					if charName not in characters:
						continue
					paragrNode.changeColor(characters[charName]["color"])
	%LoadButton.disabled = true

func loadColorFromText(text: String) -> Color:
	text = text.rstrip(")").lstrip("(")
	var numberStrings = text.split(", ")
	if len(numberStrings) < 3:
		return Color(0, 0, 0)
	else:
		return Color(
			float(numberStrings[0]),
			float(numberStrings[1]),
			float(numberStrings[2]),
		)

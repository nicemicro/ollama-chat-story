extends PanelContainer

const paragraphSceneUID = "uid://dklx1tdfmq6cb"
const characterNameSceneUID = "uid://xss4d30ho6ir"

@export var chapterName: String = ""
var _tunnels: Array = []
var _selectedParagrs: Array = []
var _needToSummarize: int = -1
var _llmQuestionShown: bool = false

signal chapterTitleChange(chapterTitle, chapterObject)
signal openCharacterStory(characterName, chapterName)
signal addCharacter(characterName, chapterName)
signal deleteCharacter(characterName: String, chapterName: String)
signal hideCharacter(character: String)
signal unhideCharacter(character: String)
signal paragrapAdded(paragraphNode)
signal paragraphCharacter(characterName: String, chapterName: String)
signal summarizeParagraphs(paragraphList: Array, insertAfter: int)

func _ready():
	addEmptyCharacter()

func setProperties(newChapterName: String, newTitle: String, newBackground: String):
	chapterName = newChapterName
	%ChapterTitle.text = newTitle
	%ChapterBackground.text = newBackground

func getChapterTitle() -> String:
	return %ChapterTitle.text

func getChapterBackground() -> String:
	return %ChapterBackground.text

func getParagraphs(startIndex: int = -1, maxlength: int = 10000) -> Array:
	var paragrList: Array = []
	var parindex: int = startIndex
	if startIndex == -1:
		parindex = %StoryParagraphs.get_child_count() - 1
	var length: int = 0
	var summaryNeeded: int = _needToSummarize
	while length < maxlength and parindex >= 0:
		var paragraphNode = %StoryParagraphs.get_child(parindex)
		parindex -= 1
		if paragraphNode.paragrCharacter == "ANSWER":
			continue
		paragrList.push_front(paragraphNode.paragrText.replace("\n", " "))
		length += len(paragraphNode.paragrText)
		if length > maxlength * 0.6:
			summaryNeeded = max(parindex, summaryNeeded)
		if paragraphNode.paragrCharacter == "SUMMARY":
			break
	if length > maxlength * 0.85:
		_needToSummarize = max(_needToSummarize, summaryNeeded)
	return paragrList

func addOllamaPragr(tunnel: LlmTunnel, characterName: String, color: Color, where: int = -1):
	var packedScene = preload(paragraphSceneUID)
	var newParagraph = packedScene.instantiate()
	var idealSize: int = max(int(%StoryParagraphs.size.y * 0.8), 510)
	_connectParagrSignals(newParagraph)
	_tunnels.append(tunnel)
	tunnel.messageReceived.connect(_scrollBottomDeferred)
	tunnel.streamOver.connect(_removeTunnel.bind(tunnel))
	newParagraph.setUpLlm(tunnel, characterName, color, idealSize)
	%StoryParagraphs.add_child(newParagraph)
	if where == -1:
		_scrollBottomDeferred()
	else:
		%StoryParagraphs.move_child(newParagraph, where)

func _removeTunnel(activeTunnel: LlmTunnel):
	_tunnels.erase(activeTunnel)
	if _needToSummarize != -1:
		_requestAutoSummary()

func _requestAutoSummary():
	var parindex: int = %StoryParagraphs.get_child_count()
	var paragraphList: Array = []
	while parindex > 0:
		parindex -= 1
		var paragraphNode = %StoryParagraphs.get_child(parindex)
		if parindex <= _needToSummarize:
			paragraphList.push_front(paragraphNode.paragrText)
		if paragraphNode.paragrCharacter == "SUMMARY":
			break
	if len(paragraphList) < 4:
		return
	summarizeParagraphs.emit(paragraphList, _needToSummarize+1, "paragraphs_summary")
	_needToSummarize = -1

func addParagraph(text: String, color: Color, where: int = -1):
	var packedScene = preload(paragraphSceneUID)
	var newParagraph = packedScene.instantiate()
	var idealSize: int = max(int(%StoryParagraphs.size.x * 0.8), 510)
	newParagraph.setUp(text, color, idealSize)
	_connectParagrSignals(newParagraph)
	for characterPanel in %Characters.get_children():
		if not characterPanel.is_in_group("charactelCtrlPanel"):
			continue
		if characterPanel.characterName == newParagraph.paragrCharacter:
			characterPanel.hasParagraphs(true)
	%StoryParagraphs.add_child(newParagraph)
	if where == -1:
		_scrollBottomDeferred()
	else:
		%StoryParagraphs.move_child(newParagraph, where)
	return newParagraph

func addParagraphAfter(paragrAfterNode, text: String, after: bool):
	var color: Color = paragrAfterNode.bgColor
	var add: int = 0
	if after:
		add = 1
	addParagraph(text, color, paragrAfterNode.get_index()+add)

func _connectParagrSignals(paragraph):
	paragraph.characterChanged.connect(paragraphCharacterChange)
	paragraph.editStarted.connect(disableParagrEdits)
	paragraph.editDone.connect(enableParagrEdits)
	paragraph.selected.connect(paragrSelected)
	paragraph.addNewParagraph.connect(addParagraphAfter)
	paragrapAdded.emit(paragraph)

func scrollBottom():
	%ScrollStory.set_deferred(
		"scroll_vertical", %ScrollStory.get_v_scroll_bar().max_value
	)

func _scrollBottomDeferred(_a = null, _b = null, _c = null, _d = null):
	call_deferred("scrollBottom")

func addEmptyCharacter():
	var packedScene = preload(characterNameSceneUID)
	var newCharacter = packedScene.instantiate()
	newCharacter.checkName.connect(validateNewCharacterName)
	newCharacter.nameAdded.connect(newCharacterAdd)
	_connectCharacterSignals(newCharacter)
	%Characters.add_child(newCharacter)

func addFilledInCharater(characterName: String, newColor: Color, isHidden: bool = false):
	var packedScene = preload(characterNameSceneUID)
	var newCharacter = packedScene.instantiate()
	_connectCharacterSignals(newCharacter)
	newCharacter.characterName = characterName
	newCharacter.setColor(newColor)
	newCharacter.finalize()
	if isHidden:
		newCharacter.setHidden()
	%Characters.add_child(newCharacter)
	%Characters.move_child(newCharacter, %Characters.get_child_count()-2)

func _connectCharacterSignals(characterScene):
	characterScene.deleteRequest.connect(delCharacter)
	characterScene.storyEditRequest.connect(characterStory)
	characterScene.hideName.connect(hideCharacterBlock)
	characterScene.unhideName.connect(unhideCharacterBlock)
	characterScene.selectAllRequest.connect(selectCharacterParagraphs)

func changeCharacterColor(character: String, newColor: Color):
	for child in %Characters.get_children():
		if child == %ShowAllButton:
			continue
		if child.characterName == character:
			child.setColor(newColor)
	for child in %StoryParagraphs.get_children():
		if child.paragrCharacter == character:
			child.changeColor(newColor)

func validateNewCharacterName(characterName: String, nameBlock):
	if characterName.to_lower() in Globals.nonCharParagrs:
		return
	for child in %Characters.get_children():
		if child is CheckButton:
			continue
		if child.characterName == characterName:
			return
	nameBlock.setCharacterName(characterName)

func newCharacterAdd(characterName: String):
	addEmptyCharacter()
	addCharacter.emit(characterName, chapterName)

func delCharacter(characterName: String):
	for paragraph in %StoryParagraphs.get_children():
		if paragraph.paragrCharacter == characterName:
			%DeleteCharacterNo.show()
			return
	deleteCharacter.emit(characterName, chapterName)

func characterStory(characterName: String):
	openCharacterStory.emit(characterName, chapterName)

func selectCharacterParagraphs(characterName: String, charNameObj):
	var allSelected: bool = true
	var nothing: bool = true
	for paragrScene in %StoryParagraphs.get_children():
		if paragrScene.paragrCharacter != characterName:
			continue
		nothing = false
		if paragrScene not in _selectedParagrs:
			allSelected = false
			paragrScene.setSelected(true)
			#no need to manually add to the _selectedParagraphs, it will be done
			#through the signals from the paragraph scene
	if nothing:
		charNameObj.hasParagraphs(false)
	if not allSelected:
		return
	for paragrScene in %StoryParagraphs.get_children():
		if paragrScene.paragrCharacter != characterName:
			continue
		paragrScene.setSelected(false)

func hideCharacterBlock(object: Control):
	if not %ShowAllButton.button_pressed:
		object.hide()
	hideCharacter.emit(object.characterName)

func unhideCharacterBlock(object: Control):
	unhideCharacter.emit(object.characterName)

func paragraphCharacterChange(newName: String):
	paragraphCharacter.emit(newName, chapterName)

func disableParagrEdits(currentlyEdited: Control):
	for child in %StoryParagraphs.get_children():
		if child == currentlyEdited:
			continue
		child.setEditable(false)

func enableParagrEdits(_currentlyEdited: Control):
	for child in %StoryParagraphs.get_children():
		child.setEditable(true)

func _addSelectedParagraph(selectedParagr: Control):
	if _selectedParagrs.is_empty():
		_selectedParagrs.append(selectedParagr)
		return
	var newIndex: int = selectedParagr.get_index()
	if _selectedParagrs[0].get_index() > newIndex:
		_selectedParagrs.push_front(selectedParagr)
		return
	elif _selectedParagrs[-1].get_index() < newIndex:
		_selectedParagrs.push_back(selectedParagr)
		return
	for index in range(len(_selectedParagrs)):
		if _selectedParagrs[index].get_index() > newIndex:
			_selectedParagrs = (
				_selectedParagrs.slice(0, index) +
				[selectedParagr] +
				_selectedParagrs.slice(index)
			)
			break

func paragrSelected(selectedParagr: Control, selected: bool):
	if selected:
		assert (not selectedParagr in _selectedParagrs)
		_addSelectedParagraph(selectedParagr)
	else:
		assert (selectedParagr in _selectedParagrs)
		_selectedParagrs.erase(selectedParagr)
	%ParagraphOptions.visible = len(_selectedParagrs) > 0
	%SelectedNumber.text = " " + str(len(_selectedParagrs)) + " "
	if len(_selectedParagrs) < 2:
		%SelectBetween.disabled = true
	else:
		%SelectBetween.disabled = false

func _on_show_all_button_pressed():
	for child in %Characters.get_children():
		if child == %ShowAllButton:
			continue
		if not child.isPresent():
			child.visible = %ShowAllButton.button_pressed

func getAllData() -> Dictionary:
	var dataDict: Dictionary = {}
	dataDict["Title"] = %ChapterTitle.text
	dataDict["Background"] = %ChapterBackground.text
	dataDict["Characters"] = {}
	for child in %Characters.get_children():
		if child == %ShowAllButton or not child.isFinal():
			continue
		dataDict["Characters"][child.characterName] = child.isPresent()
	dataDict["Paragraphs"] = []
	for child in %StoryParagraphs.get_children():
		dataDict["Paragraphs"].append(child.paragrText)
	return dataDict

func _on_chapter_title_text_changed(new_text):
	chapterTitleChange.emit(new_text, self)

func _on_story_paragraphs_resized():
	var idealSize: int = max(int(%StoryParagraphs.size.x * 0.8), 510)
	for child in %StoryParagraphs.get_children():
		child.setIdealSize(idealSize)

func _on_select_between_pressed():
	var loopParagraphs: Array = _selectedParagrs.duplicate()
	var parListIndex: int = 0
	while parListIndex < len(loopParagraphs) - 1:
		var beginIndex: int = loopParagraphs[parListIndex].get_index()
		var endIndex: int = loopParagraphs[parListIndex+1].get_index()
		var index: int = beginIndex + 1
		while index < endIndex:
			%StoryParagraphs.get_child(index).setSelected(true)
			index += 1
		parListIndex += 1

func _on_deselect_all_pressed():
	var loopParagraphs: Array = _selectedParagrs.duplicate()
	for paragraph in loopParagraphs:
		paragraph.setSelected(false)

func _on_delete_paragraph_pressed():
	%DeleteConfirm.show()

func _on_delete_confirm_confirmed():
	for child in %StoryParagraphs.get_children():
		if child in _selectedParagrs:
			%StoryParagraphs.remove_child(child)
			_selectedParagrs.erase(child)
	assert(len(_selectedParagrs) == 0)
	%ParagraphOptions.visible = false

func _on_summarize_paragraphs_pressed():
	var paragraphList: Array = []
	for paragraph in _selectedParagrs:
		paragraphList.append(paragraph.paragrText)
	summarizeParagraphs.emit(
		paragraphList,
		_selectedParagrs[-1].get_index()+1,
		"paragraphs_summary"
	)

func _on_llm_question_pressed():
	if not _llmQuestionShown:
		%LllmQuestionInfo.show()
		return
	askQuestion()

func _on_lllm_question_info_confirmed():
	_llmQuestionShown = true
	askQuestion()

func askQuestion():
	var paragraphList: Array = []
	for paragraph in _selectedParagrs:
		paragraphList.append(paragraph.paragrText)
	summarizeParagraphs.emit(paragraphList, -1, "ask_question", true)

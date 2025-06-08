extends PanelContainer

const paragraphSceneUID = "uid://dklx1tdfmq6cb"
const characterNameSceneUID = "uid://xss4d30ho6ir"

@export var chapterName: String = ""
var _tunnels: Array = []
var _selectedParagrs: Array = []
var _needToSummarize: int = -1

signal chapterTitleChange(chapterTitle, chapterObject)
signal openCharacterStory(characterName, chapterName)
signal addCharacter(characterName, chapterName)
signal deleteCharacter(characterName, chapterName)
signal hideCharacter(character: String)
signal unhideCharacter(character: String)
signal paragrapAdded(paragraphNode)
signal paragraphCharacter(characterName: String, chapterName: String)
signal summarizeParagraphs(paragraphList: Array, insertAfter: int)

func _ready():
	addEmptyCharacter()

func setBulkProperties(
	newChapterName: String, newTitle: String, newBackground: String, allParagraphs: Array
):
	chapterName = newChapterName
	%ChapterTitle.text = newTitle
	%ChapterBackground.text = newBackground
	bulkAddParagraphs(allParagraphs)

func getChapterTitle() -> String:
	return %ChapterTitle.text

func getChapterBackground() -> String:
	return %ChapterBackground.text

func getParagraphs(startIndex: int = -1, maxlength: int = 12000) -> Array:
	var paragrList: Array = []
	var parindex: int = startIndex
	if startIndex == -1:
		parindex = %StoryParagraphs.get_child_count()
	var length: int = 0
	var summaryNeeded: int = _needToSummarize
	while length < maxlength and parindex > 0:
		parindex -= 1
		var paragraphNode = %StoryParagraphs.get_child(parindex)
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
	var lastSummaryIndex: int = 0
	var parindex: int = %StoryParagraphs.get_child_count()
	var paragraphList: Array = []
	while parindex > 0:
		parindex -= 1
		var paragraphNode = %StoryParagraphs.get_child(parindex)
		if parindex <= _needToSummarize:
			paragraphList.push_front(paragraphNode.paragrText)
		if paragraphNode.paragrCharacter == "SUMMARY":
			lastSummaryIndex = parindex
			break
	if len(paragraphList) < 4:
		return
	summarizeParagraphs.emit(paragraphList, _needToSummarize+1)
	_needToSummarize = -1

func addParagraph(text: String, color: Color, where: int = -1):
	var packedScene = preload(paragraphSceneUID)
	var newParagraph = packedScene.instantiate()
	var idealSize: int = max(int(%StoryParagraphs.size.x * 0.8), 510)
	newParagraph.setUp(text, color, idealSize)
	_connectParagrSignals(newParagraph)
	%StoryParagraphs.add_child(newParagraph)
	if where == -1:
		_scrollBottomDeferred()
	else:
		%StoryParagraphs.move_child(newParagraph, where)

func addParagraphAfter(paragrNode, text: String, after: bool):
	var color: Color = paragrNode.bgColor
	var add: int = 0
	if after:
		add = 1
	addParagraph(text, color, paragrNode.get_index()+add)

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
	newCharacter.deleteRequest.connect(delCharacter)
	newCharacter.storyEditRequest.connect(characterStory)
	newCharacter.hideName.connect(hideCharacterBlock)
	newCharacter.unhideName.connect(unhideCharacterBlock)
	%Characters.add_child(newCharacter)

func addFilledInCharater(characterName: String, newColor: Color, isHidden: bool = false):
	var packedScene = preload(characterNameSceneUID)
	var newCharacter = packedScene.instantiate()
	newCharacter.deleteRequest.connect(delCharacter)
	newCharacter.storyEditRequest.connect(characterStory)
	newCharacter.hideName.connect(hideCharacterBlock)
	newCharacter.unhideName.connect(unhideCharacterBlock)
	newCharacter.characterName = characterName
	newCharacter.setColor(newColor)
	newCharacter.finalize()
	if isHidden:
		newCharacter.setHidden()
	%Characters.add_child(newCharacter)
	%Characters.move_child(newCharacter, %Characters.get_child_count()-2)

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
	if characterName.to_lower() == "narrator" or characterName.to_lower() == "summary":
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
	deleteCharacter.emit(characterName, chapterName)

func characterStory(characterName: String):
	openCharacterStory.emit(characterName, chapterName)

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

func bulkAddParagraphs(paragraphList: Array):
	for paragraph in paragraphList:
		addParagraph(paragraph, Color(0.1, 0.1, 0.1))

func _on_chapter_title_text_changed(new_text):
	chapterTitleChange.emit(new_text, self)

func _on_story_paragraphs_resized():
	var idealSize: int = max(int(%StoryParagraphs.size.x * 0.8), 510)
	for child in %StoryParagraphs.get_children():
		child.setIdealSize(idealSize)

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
	summarizeParagraphs.emit(paragraphList, _selectedParagrs[-1].get_index()+1)

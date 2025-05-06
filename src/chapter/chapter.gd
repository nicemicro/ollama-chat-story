extends PanelContainer

const paragraphSceneUID = "uid://dklx1tdfmq6cb"
const characterNameSceneUID = "uid://xss4d30ho6ir"

@export var chapterName: String = ""

signal chapterTitleChange(chapterTitle, chapterObject)
signal openCharacterStory(characterName, chapterName)
signal addCharacter(characterName, chapterName)
signal deleteCharacter(characterName, chapterName)
signal hideCharacter(character: String)
signal unhideCharacter(character: String)
signal paragraphCharacter(characterName, chapterName)

func _ready():
	addEmptyCharacter()

func setBulkProperties(
	newChapterName: String, newTitle: String, newBackground: String, allParagraphs: Array
):
	chapterName = newChapterName
	%ChapterTitle.text = newTitle
	%ChapterBackground.text = newBackground
	bulkAddParagraphs(allParagraphs)

func addParagraph(text: String, color: Color, where: int = -1):
	var packedScene = preload(paragraphSceneUID)
	var newParagraph = packedScene.instantiate()
	newParagraph.setUp(text, color)
	newParagraph.characterChanged.connect(paragraphCharacterChange)
	%StoryParagraphs.add_child(newParagraph)
	if where == -1:
		%StoryParagraphs.move_child(newParagraph, where)
		call_deferred("scrollBottom")

func scrollBottom():
	%ScrollStory.set_deferred(
		"scroll_vertical", %ScrollStory.get_v_scroll_bar().max_value
		)

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

func addFilledInCharater(characterName: String, newColor: Color, hidden: bool = false):
	var packedScene = preload(characterNameSceneUID)
	var newCharacter = packedScene.instantiate()
	newCharacter.deleteRequest.connect(delCharacter)
	newCharacter.storyEditRequest.connect(characterStory)
	newCharacter.hideName.connect(hideCharacterBlock)
	newCharacter.unhideName.connect(unhideCharacterBlock)
	newCharacter.characterName = characterName
	newCharacter.setColor(newColor)
	newCharacter.finalize()
	if hidden:
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
	if characterName == "Narrator" or characterName == "narrator":
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

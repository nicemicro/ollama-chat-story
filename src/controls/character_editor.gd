extends "res://controls/misc_block.gd"

var changeHandled: bool = false
var changeSaved: bool = true
#these are needed so we know when the seleciton changes what did it change from
var _selectedChapter: String = ""
var _selectedCharacter: String = ""
var selectedChapter: String = "": set = setSelChapter, get = getSelChapter
var selectedCharacter: String = "": set = setSelCharacter, get = getSelCharacter

signal characterChange(text, color, character, chapter)
signal selectionChange(character, chapter)

func getBlockName() -> String: 
	return "CharacterEditor"

func clearSelectors():
	%ChapterSelect.clear()
	%CharacterSelect.clear()
	_selectedChapter = ""
	_selectedCharacter = ""

func setSelChapter(chapterName: String):
	for index in range(%ChapterSelect.item_count):
		if %ChapterSelect.get_item_text(index) == chapterName:
			%ChapterSelect.select(index)
			_selectedChapter = chapterName
			return

func getSelChapter():
	return _selectedChapter

func setSelCharacter(characterName: String):
	for index in range(%CharacterSelect.item_count):
		if %CharacterSelect.get_item_text(index) == characterName:
			%CharacterSelect.select(index)
			_selectedCharacter = characterName
			#TODO change the description etc.
			return

func getSelCharacter():
	return _selectedCharacter

func openMain(data: Dictionary = {}):
	super.openMain(data)
	if not changeSaved:
		changeHandled = true
		emitChanges()
	if not "chapter" in data and _selectedChapter != "":
		data["chapter"] = _selectedChapter
	if not "character" in data and _selectedCharacter != "":
		data["character"] = _selectedCharacter
	if not "chapter" in data or not "character" in data:
		%StoryEdit.editable = false
		%ColorPick.color = Color(0, 0, 0)
		%ColorPick.disabled = true
		return
	if not "story" in data or not "color" in data:
		selectionChange.emit(_selectedCharacter, _selectedChapter)
		return
	selectedChapter = data["chapter"]
	selectedCharacter = data["character"]
	%StoryEdit.text = data["story"]
	%ColorPick.color = data["color"]
	%StoryEdit.editable = true
	%ColorPick.disabled = false

func addChapter(chapterName: String):
	var chapterIndex: int = -1
	for index in range(%ChapterSelect.item_count):
		if %ChapterSelect.get_item_text(index) == chapterName:
			chapterIndex = index
			break
	assert (chapterIndex == -1)
	var selectionId: int = %ChapterSelect.get_selected_id()
	%ChapterSelect.add_item(chapterName)
	if selectionId == -1:
		selectedChapter = chapterName

func addCharacter(characterName: String, chapterName: String):
	var chapterIndex: int = -1
	for index in range(%ChapterSelect.item_count):
		if %ChapterSelect.get_item_text(index) == chapterName:
			chapterIndex = index
			break
	assert (chapterIndex != -1)
	var characterIndex: int = -1
	for index in range(%CharacterSelect.item_count):
		if %CharacterSelect.get_item_text(index) == characterName:
			characterIndex = index
			break
	assert (characterIndex == -1)
	#var selectionId: int = %CharacterSelect.get_selected_id()
	%CharacterSelect.add_item(characterName)
	#if selectionId == -1:
	if _selectedCharacter == "":
		selectedCharacter = characterName
		selectionChange.emit(_selectedCharacter, _selectedChapter)

func removeCharacter(characterName):
	var button: OptionButton = %CharacterSelect
	var selectedIndex: int = button.get_item_index(button.get_selected_id())
	assert(button.get_item_text(selectedIndex) == _selectedCharacter)
	var adjust: int = 1
	var names: Array = []
	for index in range(button.item_count):
		names.append(button.get_item_text(index))
	button.clear()
	for addbackCharacter in names:
		if addbackCharacter == characterName:
			adjust = 0 #if the unhidden character comes up first, it will be turned to +1 later
		else:
			button.add_item(addbackCharacter)
		if addbackCharacter == _selectedCharacter:
			adjust = 1 #if the selected character comes up first, it will be zeroed later
	button.select(selectedIndex + adjust)
	if _selectedCharacter == characterName:
		setSelCharacter(button.get_item_text(selectedIndex + adjust))

func _on_color_picker_button_color_changed(_color):
	changeSaved = false
	if changeHandled:
		return
	changeHandled = true
	%Timer.start(3)

func _on_text_edit_text_changed():
	changeSaved = false
	if changeHandled:
		return
	changeHandled = true
	%Timer.start(3)

func emitChanges():
	if not changeHandled:
		return
	changeHandled = false
	changeSaved = true
	var color: Color = %ColorPick.color
	characterChange.emit(%StoryEdit.text, color, _selectedCharacter, _selectedChapter)

func _on_character_select_item_selected(index):
	if selectedChapter != "":
		changeHandled = true
		emitChanges()
		#%StoryEdit.editable = true
		#%ColorPick.disabled = false
	_selectedCharacter = %CharacterSelect.get_item_text(index)
	selectionChange.emit(_selectedCharacter, _selectedChapter)

func _on_chapter_select_item_selected(index):
	if selectedChapter != "":
		changeHandled = true
		emitChanges()
	selectionChange.emit(_selectedCharacter, _selectedChapter)
	_selectedChapter = %ChapterSelect.get_item_text(index)

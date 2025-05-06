extends HBoxContainer

var _characterName: String = ""
var characterName: String = "": get = getCharacterName, set = setCharacterName

signal checkName(characterName: String, object)
signal nameAdded(characterName: String)
signal storyEditRequest(characterName: String)
signal deleteRequest(characterName: String)
signal hideName(object)
signal unhideName(object)

func isPresent() -> bool:
	return %PresentSwitch.button_pressed

func setHidden():
	%PresentSwitch.button_pressed = false

func setColor(newColor):
	%ColorRect.color = newColor

func getCharacterName() -> String:
	return _characterName

func isFinal() -> bool:
	return %NameLabel.visible

func setCharacterName(newName):
	assert(%NameInput.visible)
	assert(_characterName == "")
	_characterName = newName
	%NameInput.text = newName
	finalize()

func _on_save_button_pressed():
	_on_name_input_text_submitted(%NameInput.text)

func _on_name_input_text_submitted(new_text):
	checkName.emit(new_text, self)

func finalize():
	%NameLabel.text = characterName
	%ColorRect.show()
	%NameLabel.show()
	%NameInput.hide()
	%SaveButton.hide()
	%StoryEdButton.show()
	%DelButton.show()
	%PresentSwitch.show()
	nameAdded.emit(characterName)

func _on_story_ed_button_pressed():
	storyEditRequest.emit(characterName)

func _on_del_button_pressed():
	deleteRequest.emit(characterName)

func _on_present_switch_toggled(toggled_on):
	if not toggled_on:
		hideName.emit(self)
	else:
		unhideName.emit(self)

extends Button

signal buttonPressed(characterName: String)

func _on_pressed():
	var characterName: String = text
	if text == "Add narration":
		characterName = "Narrator"
	buttonPressed.emit(characterName)

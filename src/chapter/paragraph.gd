extends PanelContainer

var paragrText: String = ""
var paragrCharacter: String = ""
var formattedText: String = ""
var bgColor: Color: get = getColor, set = fail

signal characterChanged(charcterName)

func fail(_new):
	assert (false)

func setUp(newText: String, newColor: Color):
	assert (paragrText == "")
	assert (%ColorRect.color == Color.WHITE)
	paragrText = newText
	%ColorRect.color = newColor
	_setUp()

func changeColor(newColor: Color):
	%ColorRect.color = newColor

func getColor() -> Color:
	return %ColorRect.color

func _setUp():
	var oldCharacter: String = paragrCharacter
	if paragrText.contains(":"):
		var splitText = paragrText.split(":", true, 1)
		formattedText = "[b]" + splitText[0] + ":[/b]" + splitText[1]
		paragrCharacter = splitText[0]
	else:
		paragrCharacter = "Narrator"
		formattedText = "[b]Narrator:[/b] " + paragrText
		paragrText = "Narrator: " + paragrText
	if not oldCharacter.is_empty() and paragrCharacter != oldCharacter:
		characterChanged.emit(paragrCharacter)
	%TextView.text = formattedText
	%TextEdit.text = paragrText
	var length: int = paragrText.length()
	length = min(length, 60)
	%TextView.custom_minimum_size = Vector2(510/60*length+40, 0)

func _on_edit_button_pressed():
	%ColorRect.hide()
	%TextView.hide()
	%TextEdit.show()
	%EditButton.hide()
	%DoneButton.show()

func _on_done_button_pressed():
	%ColorRect.show()
	%TextView.show()
	%TextEdit.hide()
	%EditButton.show()
	%DoneButton.hide()
	paragrText = %TextEdit.text
	_setUp()

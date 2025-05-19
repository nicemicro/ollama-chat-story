extends PanelContainer

var paragrText: String = ""
var paragrCharacter: String = ""
var formattedText: String = ""
var bgColor: Color: get = getColor, set = fail
var _tunnel: LlmTunnel = null
var _idealSize: int = 510

signal characterChanged(charcterName)

func fail(_new):
	assert (false)

func setUp(newText: String, newColor: Color, newIdealSize: int):
	assert (paragrText == "")
	assert (%ColorRect.color == Color.WHITE)
	paragrText = newText
	_idealSize = newIdealSize
	%ColorRect.color = newColor
	_setUp()

func setUpLlm(tunnel: LlmTunnel, characterName: String, newColor: Color, newIdealSize: int):
	assert (paragrText == "")
	assert (%ColorRect.color == Color.WHITE)
	assert (_tunnel == null)
	paragrCharacter = characterName
	_tunnel = tunnel
	_tunnel.streamOver.connect(_allReceived)
	_tunnel.messageReceived.connect(_textReceived)
	_idealSize = newIdealSize
	%ColorRect.color = newColor
	%EditButton.disabled = true
	%TextView.hide()
	%ResponseWaitLab.show()
	%ProgressBar.show()

func changeColor(newColor: Color):
	%ColorRect.color = newColor

func getColor() -> Color:
	return %ColorRect.color

func setIdealSize(newIdealSize: int):
	_idealSize = newIdealSize
	_setSize()

func _setSize():
	%TextEdit.custom_minimum_size.x = _idealSize + 60
	var length: int = paragrText.length()
	%TextView.custom_minimum_size = Vector2(min(_idealSize, length*10), 0)

func _textReceived(textChunk: String, _role: String, _api: String, _model: String):
	%ResponseWaitLab.hide()
	%TextView.show()
	paragrText += textChunk
	if paragrText.contains(":"):
		var splitText = paragrText.split(":", true, 1)
		formattedText = "[b]" + splitText[0] + ":[/b]" + splitText[1]
	else:
		formattedText = paragrText
	%TextView.text = formattedText
	%TextEdit.text = paragrText

func _allReceived():
	_tunnel.disconnectApi()
	_tunnel = null
	%EditButton.disabled = false
	%ProgressBar.hide()
	if paragrText.contains("\n"):
		var lines = paragrText.split("\n")
		paragrText = lines[0]
		for line in lines:
			if line.begins_with(paragrCharacter + ": "):
				paragrText += " " + line.trim_prefix(paragrCharacter + ": ")
				continue
			break
	if not paragrText.begins_with(paragrCharacter):
		if paragrText.contains(paragrCharacter + ": "):
			paragrText = (
				paragrCharacter + ": " +
				paragrText.get_slice(paragrCharacter + ": ", 0) +
				paragrText.get_slice(paragrCharacter + ": ", 1)
			)
		else:
			paragrText = paragrCharacter + ": " + paragrText
	_setUp()

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
	if formattedText.contains(" *"):
		var newFormText: String = ""
		var startind: int = 0
		var finishind: int = -1
		var prevFinishind: int = 0
		while startind < len(formattedText):
			startind = formattedText.find(" *", finishind + 1)
			if startind == -1:
				newFormText += (formattedText.substr(prevFinishind))
				break
			finishind = formattedText.find("* ", startind + 2)
			if finishind == -1:
				if not formattedText.ends_with("*"):
					newFormText += (formattedText.substr(prevFinishind))
					break
				finishind = len(formattedText)-1
			newFormText += (
				formattedText.substr(prevFinishind, startind+1-prevFinishind) + "[i]" +
				formattedText.substr(startind+1, finishind-startind) + "[/i]"
			)
			prevFinishind = finishind + 1
			startind = finishind + 1
		formattedText = newFormText
	if not oldCharacter.is_empty() and paragrCharacter != oldCharacter:
		characterChanged.emit(paragrCharacter)
	%TextView.text = formattedText
	%TextEdit.text = paragrText
	_setSize()

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

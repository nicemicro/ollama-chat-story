extends PanelContainer

var _paragrText: String = ""
var _paragrCharacter: String = ""
var _formattedText: String = ""
var _LlmFullReply: String = ""
var paragrCharacter: String: get = getParagrCharacter, set = fail
var paragrText: String: get = getParagrText, set = fail
var bgColor: Color: get = getColor, set = changeColor
var _tunnel: LlmTunnel = null
var _idealSize: int = 510

signal characterChanged(charcterName: String)
signal editStarted(object: PanelContainer)
signal editDone(object: PanelContainer)
signal selected(object: PanelContainer, selecionOn: bool)
signal addNewParagraph(object: PanelContainer, text: String, after: bool)
signal ollamaContinue(object: PanelContainer, text: String, characterName: String)

func _ready():
	%ActionsMenu.get_popup().index_pressed.connect(_on_action_selected)

func fail(_new):
	assert (false)

func setUp(newText: String, newColor: Color, newIdealSize: int):
	assert (_paragrText == "")
	assert (%ColorRect.color == Color.WHITE)
	_paragrText = newText
	_idealSize = newIdealSize
	%ColorRect.color = newColor
	_setUp()

func setUpLlm(tunnel: LlmTunnel, characterName: String, newColor: Color, newIdealSize: int):
	assert (_paragrText == "")
	assert (%ColorRect.color == Color.WHITE)
	assert (_tunnel == null)
	_paragrCharacter = characterName
	if _paragrCharacter == "SUMMARY":
		size_flags_horizontal = Control.SIZE_SHRINK_END
	elif _paragrCharacter == "ANSWER":
		size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_tunnel = tunnel
	_tunnel.streamOver.connect(_allReceived)
	_tunnel.messageReceived.connect(_textReceived)
	_idealSize = newIdealSize
	%ColorRect.color = newColor
	%EditButton.disabled = true
	%TextView.hide()
	%ResponseWaitLab.show()
	%ProgressBar.show()

func connectLlm(tunnel: LlmTunnel):
	_tunnel = tunnel
	_tunnel.streamOver.connect(_allReceived)
	_tunnel.messageReceived.connect(_textReceived)
	%EditButton.disabled = true
	%ProgressBar.show()

func changeColor(newColor: Color):
	%ColorRect.color = newColor

func getColor() -> Color:
	return %ColorRect.color

func getParagrCharacter() -> String:
	return _paragrCharacter

func getParagrText() -> String:
	return _paragrText

func setIdealSize(newIdealSize: int):
	_idealSize = newIdealSize
	_setSize()

func setEditable(editable: bool):
	%EditButton.disabled = not editable

func setSelected(toSelect: bool):
	%Selection.button_pressed = toSelect

func _setSize():
	%TextEdit.custom_minimum_size.x = _idealSize + 60
	var length: int = _paragrText.length()
	%TextView.custom_minimum_size = Vector2(min(_idealSize, length*10), 0)

func _textReceived(textChunk: String, _role: String, _api: String, _model: String):
	%ResponseWaitLab.hide()
	%TextView.show()
	_paragrText += textChunk
	#This following condition is if a "reasoning model" such as qwen is used.
	#I have no idea if other "reasoning models" use a similar tagging for their
	#thinking part, but I'm running with this here, hardcoding that.
	if _paragrText.begins_with("<think>"):
		_formattedText = "[i]" + _paragrText
		if _formattedText.contains("</think>"):
			var splitText = _formattedText.split("</think>", true, 1)
			var reply = splitText[1].lstrip("\n \t")
			if reply.contains(":"):
				var splitText2 = reply.split(":", true, 1)
				reply = "[b]" + splitText2[0] + ":[/b]" + splitText2[1]
			_formattedText = splitText[0] + "[/i] \n" + reply
		%TextView.text = _formattedText
		%TextEdit.text = _paragrText
		return
	if _paragrText.contains(":"):
		var splitText = _paragrText.split(":", true, 1)
		_formattedText = "[b]" + splitText[0] + ":[/b]" + splitText[1]
	else:
		_formattedText = _paragrText
	%TextView.text = _formattedText
	%TextEdit.text = _paragrText

func _allReceived():
	_tunnel = null
	%EditButton.disabled = false
	%ProgressBar.hide()
	%ResponseWaitLab.hide()
	%TextView.show()
	_LlmFullReply = _paragrText
	#remove the reasoning part and leave only the response for qwen.
	if _paragrCharacter == "ANSWER":
		_setUp()
		return
	if _paragrText.contains("</think>"):
		_paragrText = _paragrText.get_slice("</think>", 1)
	_paragrText = paragrText.rstrip("\n \t").lstrip("\n \t")
	if _paragrText.contains("\n"):
		var lines = _paragrText.split("\n", 1)
		_paragrText = lines[0]
		for line in lines[1].split("\n"):
			if line.begins_with(_paragrCharacter + ": "):
				_paragrText += " " + line.trim_prefix(_paragrCharacter + ": ")
				continue
			break
	if not _paragrText.begins_with(_paragrCharacter):
		if _paragrText.contains(_paragrCharacter + ": "):
			_paragrText = (
				_paragrCharacter + ": " +
				_paragrText.get_slice(_paragrCharacter + ": ", 0) +
				_paragrText.get_slice(_paragrCharacter + ": ", 1)
			)
		else:
			_paragrText = _paragrCharacter + ": " + _paragrText
	_setUp()

func _setUp():
	var oldCharacter: String = _paragrCharacter
	if _paragrText.contains(":"):
		var splitText = _paragrText.split(":", true, 1)
		_formattedText = "[b]" + splitText[0] + ":[/b]" + splitText[1]
		_paragrCharacter = splitText[0]
	else:
		if _paragrCharacter != "ANSWER":
			_paragrCharacter = "Narrator"
		_formattedText = "[b]" + _paragrCharacter + ":[/b] " + _paragrText
		_paragrText = _paragrCharacter +": " + _paragrText
	if _formattedText.contains(" *"):
		var newFormText: String = ""
		var startind: int = 0
		var finishind: int = -1
		var prevFinishind: int = 0
		while startind < len(_formattedText):
			startind = _formattedText.find(" *", finishind + 1)
			if startind == -1:
				newFormText += (_formattedText.substr(prevFinishind))
				break
			finishind = _formattedText.find("* ", startind + 2)
			if finishind == -1:
				if not _formattedText.ends_with("*"):
					newFormText += (_formattedText.substr(prevFinishind))
					break
				finishind = len(_formattedText)-1
			newFormText += (
				_formattedText.substr(prevFinishind, startind+1-prevFinishind) + "[i]" +
				_formattedText.substr(startind+1, finishind-startind) + "[/i]"
			)
			prevFinishind = finishind + 1
			startind = finishind + 1
		_formattedText = newFormText
	if _paragrCharacter == "SUMMARY":
		size_flags_horizontal = Control.SIZE_SHRINK_END
	elif _paragrCharacter == "ANSWER":
		size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	else:
		size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	if not oldCharacter.is_empty() and _paragrCharacter != oldCharacter:
		characterChanged.emit(_paragrCharacter)
	%TextView.text = _formattedText
	%TextEdit.text = _paragrText
	_setSize()

func _splitParagraph():
	if not %TextEdit.text.contains("\n"):
		%CannotSplit.show()
		return
	var newPragrText: String = (
		%TextEdit.text.get_slice(":", 0) + ": " +
		%TextEdit.text.split("\n", false, 1)[1]
	)
	%TextEdit.text = %TextEdit.text.get_slice("\n", 0)
	finishEdit()
	addNewParagraph.emit(self, newPragrText, true)

func _ollamaContinue():
	finishEdit()
	_paragrText += " "
	_formattedText += " "
	%TextView.text = _formattedText
	ollamaContinue.emit(self, _paragrText, _paragrCharacter)

func _on_edit_button_pressed():
	%TextEdit.custom_minimum_size.y = %TextView.size.y
	%ColorRect.hide()
	%TextView.hide()
	%TextEdit.show()
	%EditButton.hide()
	%DoneButton.show()
	%Selection.hide()
	%ActionsMenu.show()
	editStarted.emit(self)

func _on_done_button_pressed():
	finishEdit()

func finishEdit():
	%ColorRect.show()
	%TextView.show()
	%TextEdit.hide()
	%EditButton.show()
	%DoneButton.hide()
	%Selection.show()
	%ActionsMenu.hide()
	_paragrText = %TextEdit.text.rstrip("\n \t").lstrip("\n \t")
	_setUp()
	editDone.emit(self)

func _on_selection_toggled(toggled_on):
	selected.emit(self, toggled_on)

func _on_action_selected(index: int):
	match index:
		0:
			_splitParagraph()
		1:
			_ollamaContinue()

func _on_text_edit_text_changed():
	if %TextEdit.text.ends_with("\n"):
		finishEdit()
		return
	if %TextEdit.text.ends_with("\t"):
		_ollamaContinue()
		return

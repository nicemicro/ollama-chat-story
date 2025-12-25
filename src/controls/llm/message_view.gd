extends PanelContainer

var _thinking: bool = false

func setColor(newColor: Color):
	%ColorRect.color = newColor

func receiveLlmMessage(
	textChunk: String, msgType: String, role: String, api: String, model: String
):
	addText(textChunk, role + "; /api/" + api + "; " + model, msgType)

func addText(text: String, comment: String = "", msgType: String = "response"):
	if msgType == "thinking" and not _thinking:
		text = "Thinking...\n" + text
		_thinking = true
	if _thinking and msgType != "thinking":
		text = "\n...done thinking.\n" + text
		_thinking = false
	%TextView.text += text
	if len(%TextView.text) > 0:
		%TextView.show()
		%WaitingLabel.hide()
	if comment !=  "":
		%ApiType.text = comment

func setRight():
	%TextView.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

func hideProgressBar():
	%ProgressBar.hide()

func getMsgComment():
	return %ApiType.text

func getMsg():
	return %TextView.text

extends PanelContainer

func setColor(newColor: Color):
	%ColorRect.color = newColor

func receiveLlmMessage(textChunk: String, role: String, api: String, model: String):
	addText(textChunk, role + "; /api/" + api + "; " + model)

func addText(text: String, comment: String = ""):
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

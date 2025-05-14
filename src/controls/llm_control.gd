extends "res://controls/misc_block.gd"

const messageUid = "uid://crhhngd1rdfo6"

var ollamaHost: String = "localhost"
var ollamaPort: int = 11434
var _receiveMsgDispl = null
var _sendMsgQueue: Array = []
var _msgId: int = 0

signal connectionSevered

func _ready():
	super._ready()
	%OllamaUrl.placeholder_text = ollamaHost + ":" + str(ollamaPort)
	hideSubBlocks()

func _process(_delta):
	if len(_sendMsgQueue) == 0 or _receiveMsgDispl != null or %ApiAccess.isBusy():
		return
	if %ApiAccess.isDisconnected():
		%ApiAccess.connectToHost()
		print_debug("Force reconnect")
		return
	var sendMessage = _sendMsgQueue[0]
	if sendMessage["type"] == "chat":
		sendChatToOllama(sendMessage["message"])

func getBlockName() -> String: 
	return "LLMControl"

func hideSubBlocks():
	for child in %SubWindows.get_children():
		if child == %SubWindows.get_child(0):
			continue
		child.hide()

func showSubBlocks():
	for child in %SubWindows.get_children():
		child.show()

func showModels(model_list: Array):
	if len(model_list) == 0:
		%StatusLabel.text = "No models were preloaded for Ollama"
		return
	%SelectModel.show()
	%SelectModel.clear()
	for model in model_list:
		%SelectModel.add_item(model["name"])

func addToOllamaQueue(msgType: String, message: String):
	_msgId += 1
	_sendMsgQueue.append({
		"id": _msgId,
		"type": msgType,
		"message": message
	})
	return _msgId

func sendChatToOllama(message: String):
	assert(_receiveMsgDispl == null)
	var msgboxScene = preload(messageUid)
	var sentMessageBox = msgboxScene.instantiate()
	sentMessageBox.addText(message, "user")
	sentMessageBox.setColor(Color(0.03, 0.03, 0.3))
	sentMessageBox.setRight()
	sentMessageBox.hideProgressBar()
	var messageSend: Array = []
	var previousMsgIndex: int = %LLMResponses.get_child_count()
	var HistoryLength: int = 0
	while previousMsgIndex > 0 and HistoryLength < 50000:
		previousMsgIndex -= 1
		var msgView = %LLMResponses.get_child(previousMsgIndex)
		var role = "assistant"
		if msgView.getMsgComment() == "user":
			role = "user"
		var content = msgView.getMsg()
		HistoryLength = len(content)
		messageSend.push_front({"role": role, "content": content})
	messageSend.append({"role": "user", "content": message})
	%LLMResponses.add_child(sentMessageBox)
	_receiveMsgDispl = msgboxScene.instantiate()
	%LLMResponses.add_child(_receiveMsgDispl)
	call_deferred("scrollBottom")
	%ApiAccess.sendPostRequest({
			"model": %SelectModel.get_item_text(%SelectModel.selected),
			"messages": messageSend
		}
	, "api/chat")

func messageFromOllama(messageDict: Dictionary, api: String):
	if _receiveMsgDispl == null:
		var msgboxScene = preload(messageUid)
		_receiveMsgDispl = msgboxScene.instantiate()
		%LLMResponses.add_child(_receiveMsgDispl)
	var receivedText: String
	if api == "chat":
		receivedText = messageDict["message"]["content"]
	elif api == "generate":
		receivedText = messageDict["response"]
	if "model" in messageDict:
		api += ", " + messageDict["model"]
	_receiveMsgDispl.addText(receivedText, "/api/" + api)
	if "done" in messageDict and messageDict["done"] == true:
		_sendMsgQueue.pop_front()
		_receiveMsgDispl.hideProgressBar()
		_receiveMsgDispl = null
	call_deferred("scrollBottom")

func scrollBottom():
	%LLMScroll.set_deferred(
		"scroll_vertical", %LLMScroll.get_v_scroll_bar().max_value
		)

func _on_connect_pressed():
	if %OllamaUrl.text != "":
		var ollamaUrl: String = ""
		ollamaUrl = %OllamaUrl.text
		if ollamaUrl.contains(":"):
			ollamaHost = ollamaUrl.split(":")[0]
			ollamaPort = int(ollamaUrl.split(":")[-1])
		else:
			ollamaHost = ollamaUrl
	%ApiAccess.host = ollamaHost
	%ApiAccess.port = ollamaPort
	%ApiAccess.connectToHost()

func _on_direct_msg_send_pressed():
	addToOllamaQueue("chat", %DirectMsgText.text)
	%DirectMsgText.text = ""

func _on_api_access_connection_success():
	%ApiAccess.sendRequest("api/tags")

func _on_api_access_chunk_received(chunk: String):
	var json
	var lines: Array = chunk.split("\n")
	if len(lines) == 0:
		lines = [chunk]
	for line in lines:
		json = JSON.parse_string(line)
		if json == null:
			continue
		for key in json:
			match key:
				"models":
					showModels(json[key])
					showSubBlocks()
				"message":
					messageFromOllama(json, "chat")
				"response":
					messageFromOllama(json, "generate")

func _on_api_access_unexpected_disconnect():
	if _receiveMsgDispl != null:
		_receiveMsgDispl.hideProgressBar()
		if len(_receiveMsgDispl.getMsg()) == 0:
			_receiveMsgDispl.addText("\n\n(( ERROR, OLLAMA DISCONNECTED ))")
			%LLMResponses.remove_child(_receiveMsgDispl)
		_receiveMsgDispl = null
	%StatusLabel.text = "Status: Error, disconnected"
	%SelectModel.clear()

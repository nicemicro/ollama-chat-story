extends "res://controls/misc_block.gd"

const messageUid = "uid://crhhngd1rdfo6"

var ollamaHost: String = "localhost"
var ollamaPort: int = 11434
var _modelListTunnel: LlmTunnel = null
var _sendMsgQueue: Array = []
var _msgId: int = 0
var _manualScrolled: bool = false

signal llmConnected
signal connectionSevered

func _ready():
	super._ready()
	%OllamaUrl.placeholder_text = ollamaHost + ":" + str(ollamaPort)
	hideSubBlocks()
	%LLMScroll.get_v_scroll_bar().scrolling.connect(_scrollbarUsed)

func _scrollbarUsed():
	#_manualScrolled = true
	_manualScrolled = (
		%LLMScroll.scroll_vertical < (
			%LLMScroll.get_v_scroll_bar().max_value - %LLMScroll.size.y - 50
		)
	)

func _process(_delta):
	if len(_sendMsgQueue) == 0 or %ApiAccess.isBusy():
		return
	if %ApiAccess.isDisconnected():
		%ApiAccess.connectToHost()
		print_debug("Force reconnect")
		return
	var sendMessage = _sendMsgQueue[0]
	if sendMessage["type"] == "chat":
		_sendChatToOllama(sendMessage["message"], sendMessage["tunnel"])
	elif sendMessage["type"] == "generate":
		_sendGenerateToOllama(
			sendMessage["message"], sendMessage["images"], sendMessage["tunnel"]
		)
	else:
		assert (false)
	sendMessage["tunnel"].connectApi(%ApiAccess)

func getBlockName() -> String: 
	return "LLMControl"

func isLlmConnected() -> bool:
	if not %ApiAccess.isAvailable():
		return false
	if %SelectModel.item_count == 0:
		return false
	return true

func hideSubBlocks():
	for child in %SubWindows.get_children():
		if child == %SubWindows.get_child(0):
			continue
		child.hide()

func showSubBlocks():
	for child in %SubWindows.get_children():
		child.show()

func showModels(data: Dictionary):
	var model_list: Array = data["models"]
	_modelListTunnel.responseReceived.disconnect(showModels)
	_modelListTunnel = null
	if len(model_list) == 0:
		%StatusLabel.text = "No models were preloaded for Ollama"
		return
	%SelectModel.show()
	%SelectModel.clear()
	for model in model_list:
		%SelectModel.add_item(model["name"])
	showSubBlocks()
	%StatusLabel.text = "Connected. Select a model:"
	llmConnected.emit()

func addToOllamaQueue(
	msgType: String, message: String, images: Array = [], llmTunnel: LlmTunnel = null 
):
	assert (msgType == "chat" or msgType == "generate")
	if llmTunnel == null:
		llmTunnel = LlmTunnel.new()
	_msgId += 1
	llmTunnel.setId(_msgId)
	var msgboxScene = preload(messageUid)
	var sentMessageBox = msgboxScene.instantiate()
	sentMessageBox.addText(message, "user")
	sentMessageBox.setColor(Color(0.03, 0.03, 0.3))
	sentMessageBox.setRight()
	sentMessageBox.hideProgressBar()
	%LLMResponses.add_child(sentMessageBox)
	var receiveMsgDispl = msgboxScene.instantiate()
	receiveMsgDispl.addText("", "assistant")
	llmTunnel.messageReceived.connect(receiveMsgDispl.receiveLlmMessage)
	llmTunnel.streamOver.connect(receiveMsgDispl.hideProgressBar)
	%LLMResponses.add_child(receiveMsgDispl)
	var encodedImgs: Array = []
	for img in images:
		#img.save_jpg("user://test.jpg", 0.98)
		#var file = FileAccess.open("user://test.txt", FileAccess.WRITE)
		#file.store_string(
			#Marshalls.raw_to_base64(img.save_jpg_to_buffer(0.98))
		#)
		encodedImgs.append(Marshalls.raw_to_base64(img.save_jpg_to_buffer(0.98)))
	_sendMsgQueue.append({
		"id": _msgId,
		"tunnel": llmTunnel,
		"type": msgType,
		"message": message,
		"responseDispl": receiveMsgDispl,
		"images": encodedImgs
	})
	return llmTunnel

func generatePrompt(draft: String, dataPackage: Dictionary, type: String) -> String:
	return %PromptGen.generatePrompt(draft, dataPackage, type)

func _sendChatToOllama(message: String, tunnel: LlmTunnel):
	assert(len(_sendMsgQueue) > 0)
	var messageSend: Array = []
	var previousMsgIndex: int = %LLMResponses.get_child_count()
	var HistoryLength: int = 0
	while previousMsgIndex > 0 and HistoryLength < 50000:
		previousMsgIndex -= 1
		var msgView = %LLMResponses.get_child(previousMsgIndex)
		var content = msgView.getMsg()
		if len(content) == 0:
			continue
		HistoryLength += len(content)
		var role: String = msgView.getMsgComment()
		if role.contains(";"):
			role = role.get_slice(";", 0)
		assert (role=="user" or role=="assistant" or role=="system" or role=="tool")
		messageSend.push_front({"role": role, "content": content})
	messageSend.append({"role": "user", "content": message})
	tunnel.messageReceived.connect(_messageFromOllama)
	tunnel.streamOver.connect(_ollamaStreamDone)
	_manualScrolled = false
	call_deferred("scrollBottom")
	%ApiAccess.sendPostRequest({
			"model": %SelectModel.get_item_text(%SelectModel.selected),
			"messages": messageSend
		}
	, "api/chat")

func _sendGenerateToOllama(message: String, images: Array, tunnel: LlmTunnel):
	assert(len(_sendMsgQueue) > 0)
	tunnel.messageReceived.connect(_messageFromOllama)
	tunnel.streamOver.connect(_ollamaStreamDone)
	_manualScrolled = false
	call_deferred("scrollBottom")
	var dictSend: Dictionary = {
		"model": %SelectModel.get_item_text(%SelectModel.selected),
		"prompt": message,
		"system": %PromptGen.systemPrompts.pick_random()
	}
	if len(images) > 0:
		dictSend["images"] = images
	%ApiAccess.sendPostRequest(dictSend, "api/generate")

func _messageFromOllama(_a, _b, _c, _d, _e):
	call_deferred("scrollBottom")

func _ollamaStreamDone():
	call_deferred("scrollBottom")
	_sendMsgQueue[0]["responseDispl"].hideProgressBar()
	_sendMsgQueue.pop_front()

func scrollBottom():
	if _manualScrolled:
		return
	%LLMScroll.set_deferred(
		"scroll_vertical", %LLMScroll.get_v_scroll_bar().max_value
	)

func _on_connect_pressed():
	if %OllamaUrl.text != "":
		var ollamaUrl: String = ""
		ollamaUrl = %OllamaUrl.text
		if ollamaUrl.contains(":"):
			ollamaHost = ollamaUrl.get_slice(":", 0)
			ollamaPort = int(ollamaUrl.get_slice(":", 1))
		else:
			ollamaHost = ollamaUrl
	%ApiAccess.host = ollamaHost
	%ApiAccess.port = ollamaPort
	if %ApiAccess.isDisconnected():
		%ApiAccess.connectToHost()

func _on_disconnect_butt_pressed():
	%ConnectButt.show()
	%DisconnectButt.hide()
	%ApiAccess.disconnectHost()

func _on_direct_msg_send_pressed():
	var _tunnel = addToOllamaQueue("chat", %DirectMsgText.text)
	%DirectMsgText.text = ""

func _on_api_access_connection_success():
	%ApiAccess.sendRequest("api/tags")
	_modelListTunnel = LlmTunnel.new(%ApiAccess)
	_modelListTunnel.responseReceived.connect(showModels)
	%ConnectButt.hide()
	%DisconnectButt.show()

func _on_api_access_unexpected_disconnect():
	if not _sendMsgQueue.is_empty() and _sendMsgQueue[0]["responseDispl"] != null:
		var receiveMsgDispl = _sendMsgQueue[0]["responseDispl"]
		receiveMsgDispl.addText("\n\n-----\n(( ERROR, OLLAMA DISCONNECTED ))")
	%StatusLabel.text = "Status: Error, disconnected"
	%SelectModel.clear()
	%DisconnectButt.hide()
	%ConnectButt.show()
	connectionSevered.emit()

func _on_title_bar_hide_pressed(object):
	for child in %SubWindows.get_children():
		if child.get_child(0) != object:
			continue
		for subchild in child.get_children():
			if subchild == object:
				continue
			subchild.hide()
		break

func _on_title_bar_open_pressed(object):
	for child in %SubWindows.get_children():
		if child.get_child(0) != object:
			continue
		for subchild in child.get_children():
			if subchild == object:
				continue
			subchild.show()
		break

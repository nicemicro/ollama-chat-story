extends Resource
class_name LlmTunnel

var _id: int = -1
var _autoDisconnect: bool = true

signal responseReceived(wholeMsg: Dictionary)
signal messageReceived(textChunk: String, role: String, api: String, model: String)
signal streamOver()

func _init(apiAccess = null, autodisconnect: bool = true):
	_autoDisconnect = autodisconnect
	if apiAccess == null:
		return
	connectApi(apiAccess)

func connectApi(apiAccess):
	apiAccess.chunkReceived.connect(receiveMessage)
	apiAccess.unexpectedDisconnect.connect(apiLost)

func disconnectApi():
	var signalList = get_incoming_connections()
	for connection in signalList:
		if connection["callable"] == receiveMessage:
			connection["signal"].disconnect(receiveMessage)
		if connection["callable"] == apiLost:
			connection["signal"].disconnect(apiLost)

func setId(newId: int):
	assert(_id == -1)
	_id = newId

func receiveMessage(chunk: String):
	var modelName: String = "[Unknown]"
	var message: String = ""
	var role: String = "assistant"
	var api: String = "chat"
	chunk = "[" + chunk + "]"
	var dataList = JSON.parse_string(chunk)
	for dataDict in dataList:
		if dataDict == null:
			continue
		responseReceived.emit(dataDict)
		if "model" in dataDict:
			modelName = dataDict["model"]
		if "message" in dataDict:
			message = dataDict["message"]["content"]
			role = dataDict["message"]["role"]
		if "response" in dataDict:
			api = "generate"
			message = dataDict["response"]
		messageReceived.emit(
			message,
			role,
			api,
			modelName
		)
		if "done" not in dataDict or dataDict["done"]:
			streamOver.emit()
			if _autoDisconnect:
				disconnectApi()

func apiLost():
	streamOver.emit()
	if _autoDisconnect:
		disconnectApi()

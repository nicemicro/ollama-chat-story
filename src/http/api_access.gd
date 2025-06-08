#(C) by Nice Micro 2025
#You can use this scene by itself, or together with other files from this
#repository, conditional to the AGPL license.
#You can find all conditions in the LICENSE file in the root repository.

extends Node

enum STATUS {
	disconnected,
	connecting,
	connected,
	requestSending,
	responseReceiving,
	responseCollecting,
}

var _http: HTTPClient
var _chunkList: Array = []
var headers: Dictionary = {}: set = _fail, get = getHeaders
@export var host: String = "localhost"
@export var port: int = 11434
var _connectionStatus: STATUS

signal connectionSuccess
signal unexpectedDisconnect
signal chunkReceived(chunk)
signal fullMessageReceived(message)

func _fail(_new):
	return

func getHeaders():
	return headers

func isConnected() -> bool:
	return _connectionStatus == STATUS.connected

func isDisconnected() -> bool:
	return _connectionStatus == STATUS.disconnected

func isBusy() -> bool:
	return (
		_connectionStatus != STATUS.connected and
		_connectionStatus != STATUS.disconnected
	)

func isAvailable() -> bool:
	return (
		_connectionStatus == STATUS.connected or
		_connectionStatus == STATUS.requestSending or
		_connectionStatus == STATUS.responseReceiving or
		_connectionStatus == STATUS.responseCollecting
	)

func _ready():
	_http = HTTPClient.new() # Create the Client.
	_connectionStatus = STATUS.disconnected

func _process(_delta):
	var good: bool = true
	match _connectionStatus:
		STATUS.disconnected:
			return
		STATUS.connecting:
			good = _waitConnection()
		STATUS.connected:
			#sendRequest("api/tags")
			#sendPostRequest({}, "api/generate")
			return
		STATUS.requestSending:
			good = _statusRequest()
		STATUS.responseReceiving:
			good = _checkInitialResponse()
		STATUS.responseCollecting:
			good = _collectResponses()
		_:
			assert(false)
	if not good:
		_connectionStatus = STATUS.disconnected
		_http.close()
		unexpectedDisconnect.emit()

func connectToHost() -> bool:
	var err = 0
	if _connectionStatus != STATUS.disconnected:
		print_debug("Can't connect, the status is ", _connectionStatus)
		return false #already in progress of receiving data
	err = _http.connect_to_host(host, port) # Connect to host/port.
	if err != OK:
		unexpectedDisconnect.emit()
		_connectionStatus = STATUS.disconnected
		return false
	_connectionStatus = STATUS.connecting
	_chunkList = []
	headers = {}
	return true #success

func disconnectHost():
	if not _chunkList.is_empty():
		var fullMessage: String = "\n".join(_chunkList)
		fullMessageReceived.emit(fullMessage)
		_chunkList = []
	_http.close()
	_connectionStatus = STATUS.disconnected

func _waitConnection() -> bool:
	_http.poll()
	if (
		_http.get_status() == HTTPClient.STATUS_CONNECTING or
		_http.get_status() == HTTPClient.STATUS_RESOLVING
	):
		print_debug("connecting and resolving...")
		return true
	if _http.get_status() == HTTPClient.STATUS_CONNECTED:
		print_debug("connected")
		_connectionStatus = STATUS.connected
		connectionSuccess.emit()
		return true
	return false

func _statusRequest() -> bool:
	_http.poll()
	if _http.get_status() == HTTPClient.STATUS_REQUESTING:
		#print_debug("requesting...")
		return true
	if (
		_http.get_status() == HTTPClient.STATUS_CONNECTED or
		_http.get_status() == HTTPClient.STATUS_BODY
	):
		_connectionStatus = STATUS.responseReceiving
		print_debug("request handled")
		return true
	return false

func _checkInitialResponse() -> bool:
	if not _http.has_response():
		return false
	headers = _http.get_response_headers_as_dictionary() # Get response headers.
	var response = _http.get_response_code() # Show response code.
	print_debug("response code: ", response)
	if response == 200:
		_connectionStatus = STATUS.responseCollecting
		return true
	print_debug("HTTP error code: ", response)
	return false

func _collectResponses() -> bool:
	if _http.get_status() != HTTPClient.STATUS_BODY:
		#All received
		_connectionStatus = STATUS.connected
		var fullMessage: String = "\n".join(_chunkList)
		#print_debug("--------------------", "\n", fullMessage)
		fullMessageReceived.emit(fullMessage)
		_chunkList = []
		return true
	_http.poll()
	var chunk = _http.read_response_body_chunk()
	if chunk.size() == 0:
		return true
	var chunkStr: String = chunk.get_string_from_utf8()
	_chunkList.append(chunkStr)
	#print_debug(chunkStr, "\n")
	chunkReceived.emit(chunkStr)
	return true

func sendRequest(path: String) -> bool:
	if _connectionStatus != STATUS.connected:
		print_debug("Can't request, the status is ", _connectionStatus)
		return false
	if path.left(1) != "/":
		path = "/" + path
	# Some headers
	var requestHeaders = [
		"User-Agent: Pirulo/1.0 (Godot)",
		"Accept: */*"
	]
	var err = _http.request(HTTPClient.METHOD_GET, path, requestHeaders)
	if (err == OK):
		_connectionStatus = STATUS.requestSending
		return true
	_connectionStatus = STATUS.disconnected
	return false

func sendPostRequest(messageDict: Dictionary, path: String) -> bool:
	if _connectionStatus != STATUS.connected:
		print_debug("Can't POST request, the status is ", _connectionStatus)
		return false
	if path.left(1) != "/":
		path = "/" + path
	#if messageDict.is_empty():
		#messageDict = {
			#"model": "dolphin-mistral:latest",
			#"prompt": "Report status. Say \"Status O.K.\" if you are ready to receive instructions"
		#}
	var json = JSON.stringify(messageDict)
	#var postHeaders = ["Content-Type: application/json", "Content-Length: " + str(json.length())]
	var postHeaders = ["Content-Type: application/json"]
	var err = _http.request(HTTPClient.METHOD_POST, path, postHeaders, json)
	if (err == OK):
		_connectionStatus = STATUS.requestSending
		return true
	_connectionStatus = STATUS.disconnected
	return false

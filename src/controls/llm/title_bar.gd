extends VBoxContainer

signal openPressed(object: VBoxContainer)
signal hidePressed(object: VBoxContainer)

func _on_open_pressed():
	openPressed.emit(self)
	%Open.hide()
	%Hide.show()

func _on_hide_pressed():
	hidePressed.emit(self)
	%Open.show()
	%Hide.hide()

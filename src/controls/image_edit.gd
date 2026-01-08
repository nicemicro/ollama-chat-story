extends "res://controls/misc_block.gd"

var _imageNumber: int = -1
var _origImg: Image
var _editedImg: Image

signal deleteImage(number)
signal changeImage(number, image)

func getBlockName() -> String: 
	return "ImageEditor"

func openMain(data: Dictionary = {}):
	super.openMain(data)
	if not "origImg" in data:
		return
	_origImg = data["origImg"]
	_editedImg = data["img"]
	_imageNumber = data["num"]
	%UseImg.texture = ImageTexture.create_from_image(_editedImg)
	%ScrollUseImg.custom_minimum_size = Vector2i(
		0,
		min(_editedImg.get_size().y, 700)
	)
	%OrigImg.texture = ImageTexture.create_from_image(_origImg)
	%ImgNumLabel.text = "Image no. " + str(_imageNumber)
	for control in get_tree().get_nodes_in_group("ImgManip"):
		control.disabled = false

func _on_delete_button_pressed():
	deleteImage.emit(_imageNumber)
	%ImgNumLabel.text = "No image selected"
	_imageNumber = -1
	%OrigImg.texture = ImageTexture.new()
	%UseImg.texture = ImageTexture.new()
	for control in get_tree().get_nodes_in_group("ImgManip"):
		control.disabled = true

func imageChanged():
	%UseImg.texture = ImageTexture.create_from_image(_editedImg)
	%ScrollUseImg.custom_minimum_size = Vector2i(
		0,
		min(_editedImg.get_size().y, 700)
	)
	changeImage.emit(_imageNumber, _editedImg)

func _on_copy_button_pressed():
	_editedImg.copy_from(_origImg)
	imageChanged()

func _on_r_left_pressed():
	_editedImg.rotate_90(COUNTERCLOCKWISE)
	imageChanged()

func _on_r_right_pressed():
	_editedImg.rotate_90(CLOCKWISE)
	imageChanged()

func _on_v_mirror_pressed():
	_editedImg.flip_y()
	imageChanged()

func _on_h_mirror_pressed():
	_editedImg.flip_x()
	imageChanged()

func _on_v_reduce_pressed():
	var origSize: Vector2i = _editedImg.get_size()
	_editedImg.resize(origSize.x, origSize.y*4/5, Image.INTERPOLATE_CUBIC)
	imageChanged()

func _on_h_reduce_pressed():
	var origSize: Vector2i = _editedImg.get_size()
	_editedImg.resize(origSize.x*4/5, origSize.y, Image.INTERPOLATE_CUBIC)
	imageChanged()

func _on_reduce_1_pressed():
	var origSize: Vector2i = _editedImg.get_size()
	_editedImg.resize(origSize.x*4/5, origSize.y*4/5, Image.INTERPOLATE_CUBIC)
	imageChanged()

func _on_reduce_2_pressed():
	var origSize: Vector2i = _editedImg.get_size()
	_editedImg.resize(origSize.x/2, origSize.y/2, Image.INTERPOLATE_CUBIC)
	imageChanged()

func _on_l_cut_pressed():
	var origSize: Vector2i = _editedImg.get_size()
	_editedImg.flip_x()
	_editedImg.crop(origSize.x-20, origSize.y)
	_editedImg.flip_x()
	imageChanged()

func _on_rcut_pressed():
	var origSize: Vector2i = _editedImg.get_size()
	_editedImg.crop(origSize.x-20, origSize.y)
	imageChanged()

func _on_btm_cut_pressed():
	var origSize: Vector2i = _editedImg.get_size()
	_editedImg.crop(origSize.x, origSize.y-20)
	imageChanged()

func _on_top_cut_pressed():
	var origSize: Vector2i = _editedImg.get_size()
	_editedImg.flip_y()
	_editedImg.crop(origSize.x, origSize.y-20)
	_editedImg.flip_y()
	imageChanged()

extends TextureButton
 
var _fullImage: Image = Image.new()
var _imgToUse: Image = Image.new()
var _imageNumber: int = -1

signal activated(object)

func setTexture(image: Image):
	_fullImage.copy_from(image)
	_imgToUse.copy_from(_fullImage)
	var origSize: Vector2i = _fullImage.get_size()
	if origSize.x > 700 or origSize.y > 700:
		if origSize.x > origSize.y:
			_imgToUse.resize(600, 600*origSize.y/origSize.x, Image.INTERPOLATE_CUBIC)
		else:
			_imgToUse.resize(600*origSize.x/origSize.y, 600, Image.INTERPOLATE_CUBIC)
	makeSmallImage()
	
func makeSmallImage():
	var smallImage: Image = Image.new()
	smallImage.copy_from(_imgToUse)
	smallImage.resize(40,40,Image.INTERPOLATE_CUBIC)
	texture_normal = ImageTexture.create_from_image(smallImage)
	var highlight: Image = Image.new()
	highlight.copy_from(smallImage)
	if highlight.is_compressed():
		highlight.decompress()
	highlight.adjust_bcs(1.5, 0.8, 0.8)
	texture_hover = ImageTexture.create_from_image(highlight)

func setNumber(newNum: int):
	_imageNumber = newNum
	tooltip_text = str(newNum)

func setImage(newImage: Image):
	assert(_imageNumber != -1 and not _fullImage == null)
	_imgToUse.copy_from(newImage)
	makeSmallImage()

func _on_pressed():
	activated.emit(self)

func getOrigImg():
	return _fullImage

func getImg():
	return _imgToUse

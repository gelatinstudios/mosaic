@echo off
dmd -m64 -i -g -inline -O mosaic.d stb_image.obj stb_image_write.obj
IF %ERRORLEVEL% == 0 (
	del mosaic.obj
	mosaic.exe crying_sad.png crying_sad_mosaic.png -count 100 -scale 5.0 -flip
)

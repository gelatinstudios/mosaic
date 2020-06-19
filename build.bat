@echo off
dmd -m64 -i -g -O -release -inline mosaic.d stb_image.obj stb_image_write.obj
IF %ERRORLEVEL% == 0 (
	mosaic.exe image0.jpg mosaic.png -count 40 -scale 2.0
)

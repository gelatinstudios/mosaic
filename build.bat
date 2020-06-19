@echo off
dmd -m64 -i -g -O -release -inline mosaic.d stb_image.obj stb_image_write.obj

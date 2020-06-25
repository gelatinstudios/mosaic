@echo off
cl mosaic_avx.cpp -O2 -Zi -c
dmd -m64 -i -g -O -release -inline mosaic.d stb_image.obj stb_image_write.obj mosaic_avx.obj
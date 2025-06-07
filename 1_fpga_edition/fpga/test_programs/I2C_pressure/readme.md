# I2C pressure read

This test program is an assembly I2C sensor read program for the BMP280.

Making this was a pain and is not reusable, so I leave it here if you want to try and remake the SoC. But it serves as an exmaple of what one has to do to read a single sensor.. And you actually have to do this 3 times to get the full value (spread around 3 registers !).

The *Sofware edition* will be all about solving this problem : writing code should be easier and reusable !

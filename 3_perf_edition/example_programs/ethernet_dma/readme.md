# Ethernet example.

This software exmaple NEEDS a woking MAC + DMA + HOLY CORE SoC stack.

A working implementation is available at : https://github.com/0BAB1/simple-ethernet

It is meant to work on the KC705 carrier board, but the MAC being custom, you may be able to change the XDC to work your way to another board.

What this programs does is arm the DMA to expect 1500 bytes MAX (hich is the max ethernet limit).

The [custom MAC](https://github.com/0BAB1/simple-ethernet) RX part will recieve data and **ONLY EMIT THE PAYLOAD** as AXI STREAM, which the DMA will store in BRAM.

The HOLY CORE will poll untill this is done. (You can set `#define DEBUG 1` to get debug info in UART terminal on how things are going.)

Then, the holy core will get the first 256bytes recieved in the frame (without any check whatsoever) adn run an FFT, after which it will copy the 128 frequencies analysis result in TX buffer and send a 128*4=256bytes frames as an asnwer, containing the FFT.
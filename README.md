# CGIA

## Description

The Configurable Graphics Interface Adapter (CGIA)
is a productivity-optimized video display interface core
capable of driving most VGA monitors.
It exposes various aspects of its architecture
to the programmer to let the programmer decide
his or her ideal video quality/CPU performance trade-off
for the intended application.

It offers four
["chunky" or "packed"](https://en.wikipedia.org/wiki/Packed_pixel)
graphics modes,
supporting 2, 4, 16, or 256 colors
on screen at once.
Three horizontal screen resolutions,
640, 320, or 160 pixels per scanline,
allows the programmer to trade CPU video memory access performance
for horizontal resolution.
Two vertical resolutions,
480 or 240 pixels per frame,
allows control over on-screen aspect ratio for the lower resolutions,
and can also contribute to improved video memory access performance.

The CGIA is designed for asynchronous RAMs accessed on an external bus.

## Features

* 16-bit Wishbone Bus interconnect.
* Horizontal resolutions supported: 640, 320, 160 pixels.
* Vertical resolutions supported: 480, 240 pixels.
* Color depths supported: 65536, 256, 16, 4, 2.
* Designed for 25MB/s bandwidth path to asynchronous video memory.
* 25.0MHz or 25.2MHz dot clock.
* Independent Wishbone clock.

## Wishbone Datasheet

Unless documented otherwise, the following datasheet applies to both slave and master interfaces.

* Designed for Wishbone Revision B4.
* Supported interface types: Master and Slave.

### Common Master and Slave Signals

* CLK_I
* RESET_I

### Video Memory Signals

* V_ACK_I
* V_ADR_O[23:1]
* V_DAT_I[15:0]
* V_CYC
* V_STB

### Register Access Signals

t.b.d.

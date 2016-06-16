`timescale 1ns / 1ps

//
// The feeder is the "address generator" of sorts for the shifter circuit.
// It's a simple circuit which  reads data from the line buffers and feeds it
// into the shifter.  This is not as simple a task as it seems on the surface.
//
// Consider a 640 pixel monochrome display.  Each scanline occupies 40
// halfwords of data, packed 16 pixels per word.  That means we want to reload
// the shifter every 16 dot clocks.  The dot clock driving the shifter and the
// dot clock driving the feeder are the same: 25MHz.
//
// If we decide to use a 2bpp video mode, we can pack only 320 pixels
// in the same 40 words.  Since we are displaying one half the number of
// pixels in the same span of time, we must reduce the shifter's dot
// clock by one half.  This means the feeder is also clocked at one half
// the hi-res rate (12.5MHz), since they are phase-locked; to compensate and
// maintain proper timing, we tell the feeder to reload every *eight*
// clocks instead of 16 (a single 16-bit word now holds only 8 pixels).
//
// This means that the shift1, shift2, shift4, and shift8 signals,
// which controls shift speed and reload rate, must be controlled
// independently of the dot clock frequency.  When we work along these
// two axes, we arrive at the following supported video modes:
//
//           	Shifter		Line	Horizontal resolution
// Dot Clock 	Mode		Length	and color depth.
//
// 25.000MHz	shift1		40	640 2-color
// 12.500MHz	shift2		40	320 4-color
//  6.250MHz	shift4		40	160 16-color
//  3.125MHz	shift8		40	 80 256-color
//
// 25.000MHz	shift2		80	640 4-color
// 12.500MHz	shift4		80	320 16-color
//  6.250MHz	shift8		80	160 256-color
//
// 25.000MHz	shift4		160	640 16-color
// 12.500MHz	shift8		160	320 256-color
//
// 25.000MHz	shift8		320	640 256-color
//
// If you set the dot clock and shifter mode, but get the line length
// wrong, that's OK; since the feeder is just reading from the line
// buffers, the worst that can happen is it'll read old line data from
// a previous video mode.  If this is of concern (perhaps as a possible
// security exploit), you can always set the fetcher to a 320 word
// line length, and point the frame buffer to a buffer with all zeros.
// Do this for at least two scanlines, and you'll zero out the line
// buffer, ensuring no spurious data that can be read by hacked shifter
// or dot-clock settings.
//
// The feeder works with the shifter in the following way:
//
// CRTC
// --------+
//   hctr_o|===================\
//         |                  ||
// --------+                  ||
//                            ||
// Line                       ||-(lowest 4 bits only)
// Buffers        Feeder      \/                      Shifter
// --------+     +---------------------------+     +--------------+
//  f_adr_i|<====|f_adr_o    hctr_i    load_o|---->|load_i        |
//         |     |                           |     |              |
//         |     |s1 s2 s4 s8   sle  clk_i   |     |       color_o|====>
//         |     +---------------------------+     |              |
//         |       |  |  |  |    |     |           |              |
//  f_dat_o|=======|==|==|==|====|=====|==========>|f_dat_i       |
//    clk_i|<------|--|--|--|----|-----*---------->|clk_i         |
//         |       |  |  |  |    |     |           |              |
// --------+       |  |  |  |    |     |           |s1 s2 s4 s8   |
//                 |  |  |  |    |     |           +--------------+
// scanline_en ----|--|--|--|----'     |             |  |  |  |
// dotclk ---------|--|--|--|----------'             |  |  |  |
// shift1 ---------*--|--|--|------------------------'  |  |  |
// shift2 ------------*--|--|---------------------------'  |  |
// shift4 ---------------*--|------------------------------'  |
// shift8 ------------------*---------------------------------'
//
// Notice how the feeder does not do anything with the retrieved data.
// It merely provides what it thinks should be the current fetch address
// for the line buffers.  It also commands when the serializer should accept
// a new halfword of data.
//
// As a side effect of how the shifter interacts with the feeder, the color
// bus will eventually settle to pen 0 when it has no further data to
// display.  Thus, logic which implements a distinct border should override
// the color bus coming from the shifter; the shifter will not provide border
// data on its own.
//

module feeder(
	input		dotclk_i,	// Dot clock
	input		scanline_en_i,	// 1 if refreshing a scanline.
	input	[3:0]	hctr_i,		// Horizontal pixel counter (low 4 bits)
	input		shift1_i,	// 1 if in 1bpp video mode
	input		shift2_i,	// 1 if in 2bpp video mode
	input		shift4_i,	// 1 if in 4bpp video mode
	input		shift8_i,	// 1 if in 8bpp video mode

	output	[8:0]	f_adr_o,	// Line buffer fetch address.
	output		load_o		// 1 to reload the shifter.
);
	reg load_o;
	reg [8:0] f_adr_o;

	wire [8:0] next_adr = (~scanline_en_i)? 0
			    : (load_o)? f_adr_o + 1
			    : f_adr_o;

	wire pix1 = hctr_i[0] & shift8_i;
	wire pix3 = hctr_i[1] & hctr_i[0] & shift4_i;
	wire pix7 = hctr_i[2] & hctr_i[1] & hctr_i[0] & shift2_i;
	wire pix15 = hctr_i[3] & hctr_i[2] & hctr_i[1] & hctr_i[0];

	wire next_load = (~scanline_en_i)? 1 : (pix15 | pix7 | pix3 | pix1);

	always @(posedge dotclk_i) begin
		load_o <= next_load;
		f_adr_o <= next_adr;
	end
endmodule


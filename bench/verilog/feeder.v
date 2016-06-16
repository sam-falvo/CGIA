`timescale 1ns / 1ps

//
// This test script exercises the CGIA's "feeder", a simple circuit which
// reads data from the line buffers and feeds it into the shifter.  This
// is not as simple a task as it seems on the surface.
//
// Consider a 640 pixel monochrome display.  Each scanline occupies 40
// halfwords of data, packed 16 pixels per word.  That means we want to
// reload the shifter every 16 dot clocks.  The dot clock driving the
// shifter and the dot clock driving the feeder are the same.
//
// If we decide to use a 2bpp video mode, we can pack only 320 pixels
// in the same 40 words.  Since we are displaying one half the number of
// pixels in the same span of time, we must reduce the shifter's dot
// clock by one half.  This means the feeder is also clocked at one half
// the hi-res rate, since they are phase-locked; to compensate and
// maintain proper timing, we tell the feeder to reload every *eight*
// clocks instead of 16.
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

module test_feeder();
	reg [15:0] story_o;	// Holds grep tag for failing test cases.
	reg clk_o;		// Dot clock

	reg scanline_en_o;	// 1 if refreshing a scanline; 0 otherwise.

	wire load_i;		// 1 if the shifter should reload.

	wire [8:0] f_adr_i;	// Line buffer fetch address.

	// Core Under Test
	feeder f(
		.dotclk_i(clk_o),
		.scanline_en_i(scanline_en_o),
		.load_o(load_i),
		.f_adr_o(f_adr_i)
	);

	// 25MHz clock (1/25MHz = 40ns)
	always begin
		#40 clk_o <= ~clk_o;
	end

	// Test script starts here.
	initial begin
		clk_o <= 0;

		// When we're not refreshing video, we need the synchronize
		// the shifter with the CRTC's concept of where the left-edge
		// of the video is.  That means we need to keep loading the
		// shifter with the contents of the first word from the line
		// buffer.
		story_o <= 16'h0000;
		scanline_en_o <= 0;
		wait(clk_o); wait(~clk_o);
		if(load_i !== 1) begin
			$display("@E %04X Expected load_i asserted", story_o);
			$stop;
		end
		if(f_adr_i !== 0) begin
			$display("@E %04X Expected line buffer address 0; got %d", story_o, f_adr_i);
			$stop;
		end

		#100 $display("@I OK");
		$stop;
	end
endmodule

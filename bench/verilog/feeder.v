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
	reg [3:0] hctr_o;	// Horizontal pixel counter.
	reg shift1_o;		// 1bpp video mode.
	reg shift2_o;		// 2bpp video mode.
	reg shift4_o;		// 4bpp video mode.
	reg shift8_o;		// 8bpp video mode.

	// Core Under Test
	feeder f(
		.dotclk_i(clk_o),
		.scanline_en_i(scanline_en_o),
		.load_o(load_i),
		.f_adr_o(f_adr_i),
		.hctr_i(hctr_o),
		.shift1_i(shift1_o),
		.shift2_i(shift2_o),
		.shift4_i(shift4_o),
		.shift8_i(shift8_o)
	);

	// 25MHz clock (1/25MHz = 40ns)
	always begin
		#40 clk_o <= ~clk_o;
	end

	// We need to maintain a monotonically incrementing pixel counter
	// for this interface.
	wire [3:0] next_hctr = (~scanline_en_o)? 0
			     : hctr_o + 1;
	always @(posedge clk_o) begin
		hctr_o <= next_hctr;
	end

	// Test script starts here.
	initial begin
		clk_o <= 0;

		// When we're not refreshing video, we need to synchronize
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

		// Many clock cycles occur from when scanline_en_o negates
		// to when it asserts again.  Somewhere between 40 and 80
		// is typical.
		story_o <= 16'h0010;
		wait(clk_o); wait(~clk_o);
		wait(clk_o); wait(~clk_o);
		wait(clk_o); wait(~clk_o);
		if(load_i !== 1) begin
			$display("@E %04X Expected load_i asserted", story_o);
			$stop;
		end
		if(f_adr_i !== 0) begin
			$display("@E %04X Expected line buffer address 0; got %d", story_o, f_adr_i);
			$stop;
		end

		// When it's time to start video refresh, we assert scanline_en_i.
		// We've been fetching the first word of the line buffer already,
		// so the shifter should already have that data.  We start displaying
		// pixel 0 with f_adr_o at the following address.
		story_o <= 16'h0100;
		scanline_en_o <= 1;
		wait(clk_o); wait(~clk_o);
		if(load_i !== 0) begin
			$display("@E %04X Expected load_i negated.", story_o);
			$stop;
		end
		if(f_adr_i !== 1) begin
			$display("@E %04X Expected line buffer address 1; got %d", story_o, f_adr_i);
			$stop;
		end

		// When displaying in 1bpp mode, we expect the next load request to
		// happen on the final pixel, just in the nick of time to present
		// the subsequent batch of pixels to the shifter.
		story_o <= 16'h0200;		// Sync: start a new batch of 16 pixels.
		shift1_o <= 1;
		shift2_o <= 0;
		shift4_o <= 0;
		shift8_o <= 0;
		scanline_en_o <= 0;
		wait(clk_o); wait(~clk_o);
		if(f_adr_i !== 0) begin
			$display("@E %04X Expected fetch address 0; got %d", story_o, f_adr_i);
			$stop;
		end
		if(load_i !== 1) begin
			$display("@E %04X Expected load_o asserted", story_o);
			$stop;
		end

		story_o <= 16'h0201;		// At this point, CIB=pixel 0.
		scanline_en_o <= 1;
		wait(clk_o); wait(~clk_o);
		if(f_adr_i !== 1) begin
			$display("@E %04X Expected fetch address 1; got %d", story_o, f_adr_i);
			$stop;
		end
		if(load_i !== 0) begin
			$display("@E %04X Expected load_o negated", story_o);
			$stop;
		end

		story_o <= 16'h0202;
		wait(clk_o); wait(~clk_o);
		if(f_adr_i !== 1) begin
			$display("@E %04X Expected fetch address 1; got %d", story_o, f_adr_i);
			$stop;
		end
		if(load_i !== 0) begin
			$display("@E %04X Expected load_o negated", story_o);
			$stop;
		end

		story_o <= 16'h0203;
		wait(clk_o); wait(~clk_o);
		if(f_adr_i !== 1) begin
			$display("@E %04X Expected fetch address 1; got %d", story_o, f_adr_i);
			$stop;
		end
		if(load_i !== 0) begin
			$display("@E %04X Expected load_o negated", story_o);
			$stop;
		end

		story_o <= 16'h0204;
		wait(clk_o); wait(~clk_o);
		if(f_adr_i !== 1) begin
			$display("@E %04X Expected fetch address 1; got %d", story_o, f_adr_i);
			$stop;
		end
		if(load_i !== 0) begin
			$display("@E %04X Expected load_o negated", story_o);
			$stop;
		end

		story_o <= 16'h0205;
		wait(clk_o); wait(~clk_o);
		if(f_adr_i !== 1) begin
			$display("@E %04X Expected fetch address 1; got %d", story_o, f_adr_i);
			$stop;
		end
		if(load_i !== 0) begin
			$display("@E %04X Expected load_o negated", story_o);
			$stop;
		end

		story_o <= 16'h0206;
		wait(clk_o); wait(~clk_o);
		if(f_adr_i !== 1) begin
			$display("@E %04X Expected fetch address 1; got %d", story_o, f_adr_i);
			$stop;
		end
		if(load_i !== 0) begin
			$display("@E %04X Expected load_o negated", story_o);
			$stop;
		end

		story_o <= 16'h0207;
		wait(clk_o); wait(~clk_o);
		if(f_adr_i !== 1) begin
			$display("@E %04X Expected fetch address 1; got %d", story_o, f_adr_i);
			$stop;
		end
		if(load_i !== 0) begin
			$display("@E %04X Expected load_o negated", story_o);
			$stop;
		end

		story_o <= 16'h0208;
		wait(clk_o); wait(~clk_o);
		if(f_adr_i !== 1) begin
			$display("@E %04X Expected fetch address 1; got %d", story_o, f_adr_i);
			$stop;
		end
		if(load_i !== 0) begin
			$display("@E %04X Expected load_o negated", story_o);
			$stop;
		end

		story_o <= 16'h0209;
		wait(clk_o); wait(~clk_o);
		if(f_adr_i !== 1) begin
			$display("@E %04X Expected fetch address 1; got %d", story_o, f_adr_i);
			$stop;
		end
		if(load_i !== 0) begin
			$display("@E %04X Expected load_o negated", story_o);
			$stop;
		end

		story_o <= 16'h020A;
		wait(clk_o); wait(~clk_o);
		if(f_adr_i !== 1) begin
			$display("@E %04X Expected fetch address 1; got %d", story_o, f_adr_i);
			$stop;
		end
		if(load_i !== 0) begin
			$display("@E %04X Expected load_o negated", story_o);
			$stop;
		end

		story_o <= 16'h020B;
		wait(clk_o); wait(~clk_o);
		if(f_adr_i !== 1) begin
			$display("@E %04X Expected fetch address 1; got %d", story_o, f_adr_i);
			$stop;
		end
		if(load_i !== 0) begin
			$display("@E %04X Expected load_o negated", story_o);
			$stop;
		end

		story_o <= 16'h020C;
		wait(clk_o); wait(~clk_o);
		if(f_adr_i !== 1) begin
			$display("@E %04X Expected fetch address 1; got %d", story_o, f_adr_i);
			$stop;
		end
		if(load_i !== 0) begin
			$display("@E %04X Expected load_o negated", story_o);
			$stop;
		end

		story_o <= 16'h020D;
		wait(clk_o); wait(~clk_o);
		if(f_adr_i !== 1) begin
			$display("@E %04X Expected fetch address 1; got %d", story_o, f_adr_i);
			$stop;
		end
		if(load_i !== 0) begin
			$display("@E %04X Expected load_o negated", story_o);
			$stop;
		end

		story_o <= 16'h020E;
		wait(clk_o); wait(~clk_o);
		if(f_adr_i !== 1) begin
			$display("@E %04X Expected fetch address 1; got %d", story_o, f_adr_i);
			$stop;
		end
		if(load_i !== 0) begin
			$display("@E %04X Expected load_o negated", story_o);
			$stop;
		end

		story_o <= 16'h020F;
		wait(clk_o); wait(~clk_o);
		if(f_adr_i !== 1) begin
			$display("@E %04X Expected fetch address 1; got %d", story_o, f_adr_i);
			$stop;
		end
		if(load_i !== 0) begin
			$display("@E %04X Expected load_o negated", story_o);
			$stop;
		end

		story_o <= 16'h0210;
		wait(clk_o); wait(~clk_o);
		if(f_adr_i !== 1) begin
			$display("@E %04X Expected fetch address 1; got %d", story_o, f_adr_i);
			$stop;
		end
		if(load_i !== 1) begin
			$display("@E %04X Expected load_o asserted", story_o);
			$stop;
		end

		story_o <= 16'h0211;
		wait(clk_o); wait(~clk_o);
		if(f_adr_i !== 2) begin
			$display("@E %04X Expected fetch address 2; got %d", story_o, f_adr_i);
			$stop;
		end
		if(load_i !== 0) begin
			$display("@E %04X Expected load_o negated", story_o);
			$stop;
		end

		// When displaying in 2bpp mode, ...
		story_o <= 16'h0300;		// Sync: start a new batch of 8 pixels.
		shift1_o <= 0;
		shift2_o <= 1;
		shift4_o <= 0;
		shift8_o <= 0;
		scanline_en_o <= 0;
		wait(clk_o); wait(~clk_o);
		if(f_adr_i !== 0) begin
			$display("@E %04X Expected fetch address 0; got %d", story_o, f_adr_i);
			$stop;
		end
		if(load_i !== 1) begin
			$display("@E %04X Expected load_o asserted", story_o);
			$stop;
		end

		story_o <= 16'h0301;		// At this point, CIB=pixel 0.
		scanline_en_o <= 1;
		wait(clk_o); wait(~clk_o);
		if(f_adr_i !== 1) begin
			$display("@E %04X Expected fetch address 1; got %d", story_o, f_adr_i);
			$stop;
		end
		if(load_i !== 0) begin
			$display("@E %04X Expected load_o negated", story_o);
			$stop;
		end

		story_o <= 16'h0302;
		wait(clk_o); wait(~clk_o);
		if(f_adr_i !== 1) begin
			$display("@E %04X Expected fetch address 1; got %d", story_o, f_adr_i);
			$stop;
		end
		if(load_i !== 0) begin
			$display("@E %04X Expected load_o negated", story_o);
			$stop;
		end

		story_o <= 16'h0303;
		wait(clk_o); wait(~clk_o);
		if(f_adr_i !== 1) begin
			$display("@E %04X Expected fetch address 1; got %d", story_o, f_adr_i);
			$stop;
		end
		if(load_i !== 0) begin
			$display("@E %04X Expected load_o negated", story_o);
			$stop;
		end

		story_o <= 16'h0304;
		wait(clk_o); wait(~clk_o);
		if(f_adr_i !== 1) begin
			$display("@E %04X Expected fetch address 1; got %d", story_o, f_adr_i);
			$stop;
		end
		if(load_i !== 0) begin
			$display("@E %04X Expected load_o negated", story_o);
			$stop;
		end

		story_o <= 16'h0305;
		wait(clk_o); wait(~clk_o);
		if(f_adr_i !== 1) begin
			$display("@E %04X Expected fetch address 1; got %d", story_o, f_adr_i);
			$stop;
		end
		if(load_i !== 0) begin
			$display("@E %04X Expected load_o negated", story_o);
			$stop;
		end

		story_o <= 16'h0306;
		wait(clk_o); wait(~clk_o);
		if(f_adr_i !== 1) begin
			$display("@E %04X Expected fetch address 1; got %d", story_o, f_adr_i);
			$stop;
		end
		if(load_i !== 0) begin
			$display("@E %04X Expected load_o negated", story_o);
			$stop;
		end

		story_o <= 16'h0307;
		wait(clk_o); wait(~clk_o);
		if(f_adr_i !== 1) begin
			$display("@E %04X Expected fetch address 1; got %d", story_o, f_adr_i);
			$stop;
		end
		if(load_i !== 0) begin
			$display("@E %04X Expected load_o negated", story_o);
			$stop;
		end

		story_o <= 16'h0308;		// CIB=pixel 7
		wait(clk_o); wait(~clk_o);
		if(f_adr_i !== 1) begin
			$display("@E %04X Expected fetch address 1; got %d", story_o, f_adr_i);
			$stop;
		end
		if(load_i !== 1) begin
			$display("@E %04X Expected load_o asserted", story_o);
			$stop;
		end

		story_o <= 16'h0309;		// CIB=pixel 0 for next batch
		wait(clk_o); wait(~clk_o);
		if(f_adr_i !== 2) begin
			$display("@E %04X Expected fetch address 2; got %d", story_o, f_adr_i);
			$stop;
		end
		if(load_i !== 0) begin
			$display("@E %04X Expected load_o negated", story_o);
			$stop;
		end

		story_o <= 16'h030A;
		wait(clk_o); wait(~clk_o);
		if(f_adr_i !== 2) begin
			$display("@E %04X Expected fetch address 2; got %d", story_o, f_adr_i);
			$stop;
		end
		if(load_i !== 0) begin
			$display("@E %04X Expected load_o negated", story_o);
			$stop;
		end

		story_o <= 16'h030B;
		wait(clk_o); wait(~clk_o);
		if(f_adr_i !== 2) begin
			$display("@E %04X Expected fetch address 2; got %d", story_o, f_adr_i);
			$stop;
		end
		if(load_i !== 0) begin
			$display("@E %04X Expected load_o negated", story_o);
			$stop;
		end

		story_o <= 16'h030C;
		wait(clk_o); wait(~clk_o);
		if(f_adr_i !== 2) begin
			$display("@E %04X Expected fetch address 2; got %d", story_o, f_adr_i);
			$stop;
		end
		if(load_i !== 0) begin
			$display("@E %04X Expected load_o negated", story_o);
			$stop;
		end

		story_o <= 16'h030D;
		wait(clk_o); wait(~clk_o);
		if(f_adr_i !== 2) begin
			$display("@E %04X Expected fetch address 2; got %d", story_o, f_adr_i);
			$stop;
		end
		if(load_i !== 0) begin
			$display("@E %04X Expected load_o negated", story_o);
			$stop;
		end

		story_o <= 16'h030E;
		wait(clk_o); wait(~clk_o);
		if(f_adr_i !== 2) begin
			$display("@E %04X Expected fetch address 2; got %d", story_o, f_adr_i);
			$stop;
		end
		if(load_i !== 0) begin
			$display("@E %04X Expected load_o negated", story_o);
			$stop;
		end

		story_o <= 16'h030F;
		wait(clk_o); wait(~clk_o);
		if(f_adr_i !== 2) begin
			$display("@E %04X Expected fetch address 2; got %d", story_o, f_adr_i);
			$stop;
		end
		if(load_i !== 0) begin
			$display("@E %04X Expected load_o negated", story_o);
			$stop;
		end

		story_o <= 16'h0310;
		wait(clk_o); wait(~clk_o);
		if(f_adr_i !== 2) begin
			$display("@E %04X Expected fetch address 2; got %d", story_o, f_adr_i);
			$stop;
		end
		if(load_i !== 1) begin
			$display("@E %04X Expected load_o asserted", story_o);
			$stop;
		end

		story_o <= 16'h0311;
		wait(clk_o); wait(~clk_o);
		if(f_adr_i !== 3) begin
			$display("@E %04X Expected fetch address 3; got %d", story_o, f_adr_i);
			$stop;
		end
		if(load_i !== 0) begin
			$display("@E %04X Expected load_o negated", story_o);
			$stop;
		end

		// When displaying in 4bpp mode, ...
		story_o <= 16'h0400;		// Sync: start a new batch of 8 pixels.
		shift1_o <= 0;
		shift2_o <= 0;
		shift4_o <= 1;
		shift8_o <= 0;
		scanline_en_o <= 0;
		wait(clk_o); wait(~clk_o);
		if(f_adr_i !== 0) begin
			$display("@E %04X Expected fetch address 0; got %d", story_o, f_adr_i);
			$stop;
		end
		if(load_i !== 1) begin
			$display("@E %04X Expected load_o asserted", story_o);
			$stop;
		end

		story_o <= 16'h0401;		// At this point, CIB=pixel 0.
		scanline_en_o <= 1;
		wait(clk_o); wait(~clk_o);
		if(f_adr_i !== 1) begin
			$display("@E %04X Expected fetch address 1; got %d", story_o, f_adr_i);
			$stop;
		end
		if(load_i !== 0) begin
			$display("@E %04X Expected load_o negated", story_o);
			$stop;
		end

		story_o <= 16'h0402;
		wait(clk_o); wait(~clk_o);
		if(f_adr_i !== 1) begin
			$display("@E %04X Expected fetch address 1; got %d", story_o, f_adr_i);
			$stop;
		end
		if(load_i !== 0) begin
			$display("@E %04X Expected load_o negated", story_o);
			$stop;
		end

		story_o <= 16'h0403;
		wait(clk_o); wait(~clk_o);
		if(f_adr_i !== 1) begin
			$display("@E %04X Expected fetch address 1; got %d", story_o, f_adr_i);
			$stop;
		end
		if(load_i !== 0) begin
			$display("@E %04X Expected load_o negated", story_o);
			$stop;
		end

		story_o <= 16'h0404;		// CIB=pixel 3
		wait(clk_o); wait(~clk_o);
		if(f_adr_i !== 1) begin
			$display("@E %04X Expected fetch address 1; got %d", story_o, f_adr_i);
			$stop;
		end
		if(load_i !== 1) begin
			$display("@E %04X Expected load_o asserted", story_o);
			$stop;
		end

		story_o <= 16'h0405;
		wait(clk_o); wait(~clk_o);
		if(f_adr_i !== 2) begin
			$display("@E %04X Expected fetch address 2; got %d", story_o, f_adr_i);
			$stop;
		end
		if(load_i !== 0) begin
			$display("@E %04X Expected load_o negated", story_o);
			$stop;
		end

		story_o <= 16'h0406;
		wait(clk_o); wait(~clk_o);
		if(f_adr_i !== 2) begin
			$display("@E %04X Expected fetch address 2; got %d", story_o, f_adr_i);
			$stop;
		end
		if(load_i !== 0) begin
			$display("@E %04X Expected load_o negated", story_o);
			$stop;
		end

		story_o <= 16'h0407;
		wait(clk_o); wait(~clk_o);
		if(f_adr_i !== 2) begin
			$display("@E %04X Expected fetch address 2; got %d", story_o, f_adr_i);
			$stop;
		end
		if(load_i !== 0) begin
			$display("@E %04X Expected load_o negated", story_o);
			$stop;
		end

		story_o <= 16'h0408;		// CIB=pixel 3
		wait(clk_o); wait(~clk_o);
		if(f_adr_i !== 2) begin
			$display("@E %04X Expected fetch address 2; got %d", story_o, f_adr_i);
			$stop;
		end
		if(load_i !== 1) begin
			$display("@E %04X Expected load_o asserted", story_o);
			$stop;
		end

		story_o <= 16'h0409;		// CIB=pixel 0 for next batch
		wait(clk_o); wait(~clk_o);
		if(f_adr_i !== 3) begin
			$display("@E %04X Expected fetch address 3; got %d", story_o, f_adr_i);
			$stop;
		end
		if(load_i !== 0) begin
			$display("@E %04X Expected load_o negated", story_o);
			$stop;
		end

		story_o <= 16'h040A;
		wait(clk_o); wait(~clk_o);
		if(f_adr_i !== 3) begin
			$display("@E %04X Expected fetch address 3; got %d", story_o, f_adr_i);
			$stop;
		end
		if(load_i !== 0) begin
			$display("@E %04X Expected load_o negated", story_o);
			$stop;
		end

		story_o <= 16'h040B;
		wait(clk_o); wait(~clk_o);
		if(f_adr_i !== 3) begin
			$display("@E %04X Expected fetch address 3; got %d", story_o, f_adr_i);
			$stop;
		end
		if(load_i !== 0) begin
			$display("@E %04X Expected load_o negated", story_o);
			$stop;
		end

		story_o <= 16'h040C;		// CIB=pixel 3
		wait(clk_o); wait(~clk_o);
		if(f_adr_i !== 3) begin
			$display("@E %04X Expected fetch address 3; got %d", story_o, f_adr_i);
			$stop;
		end
		if(load_i !== 1) begin
			$display("@E %04X Expected load_o asserted", story_o);
			$stop;
		end

		story_o <= 16'h040D;
		wait(clk_o); wait(~clk_o);
		if(f_adr_i !== 4) begin
			$display("@E %04X Expected fetch address 4; got %d", story_o, f_adr_i);
			$stop;
		end
		if(load_i !== 0) begin
			$display("@E %04X Expected load_o negated", story_o);
			$stop;
		end

		story_o <= 16'h040E;
		wait(clk_o); wait(~clk_o);
		if(f_adr_i !== 4) begin
			$display("@E %04X Expected fetch address 4; got %d", story_o, f_adr_i);
			$stop;
		end
		if(load_i !== 0) begin
			$display("@E %04X Expected load_o negated", story_o);
			$stop;
		end

		story_o <= 16'h040F;
		wait(clk_o); wait(~clk_o);
		if(f_adr_i !== 4) begin
			$display("@E %04X Expected fetch address 4; got %d", story_o, f_adr_i);
			$stop;
		end
		if(load_i !== 0) begin
			$display("@E %04X Expected load_o negated", story_o);
			$stop;
		end

		story_o <= 16'h0410;
		wait(clk_o); wait(~clk_o);
		if(f_adr_i !== 4) begin
			$display("@E %04X Expected fetch address 4; got %d", story_o, f_adr_i);
			$stop;
		end
		if(load_i !== 1) begin
			$display("@E %04X Expected load_o asserted", story_o);
			$stop;
		end

		story_o <= 16'h0411;
		wait(clk_o); wait(~clk_o);
		if(f_adr_i !== 5) begin
			$display("@E %04X Expected fetch address 5; got %d", story_o, f_adr_i);
			$stop;
		end
		if(load_i !== 0) begin
			$display("@E %04X Expected load_o negated", story_o);
			$stop;
		end

		// When displaying in 8bpp mode, ...
		story_o <= 16'h0500;		// Sync: start a new batch of 2 pixels.
		shift1_o <= 0;
		shift2_o <= 0;
		shift4_o <= 0;
		shift8_o <= 1;
		scanline_en_o <= 0;
		wait(clk_o); wait(~clk_o);
		if(f_adr_i !== 0) begin
			$display("@E %04X Expected fetch address 0; got %d", story_o, f_adr_i);
			$stop;
		end
		if(load_i !== 1) begin
			$display("@E %04X Expected load_o asserted", story_o);
			$stop;
		end

		story_o <= 16'h0501;		// At this point, CIB=pixel 0.
		scanline_en_o <= 1;
		wait(clk_o); wait(~clk_o);
		if(f_adr_i !== 1) begin
			$display("@E %04X Expected fetch address 1; got %d", story_o, f_adr_i);
			$stop;
		end
		if(load_i !== 0) begin
			$display("@E %04X Expected load_o negated", story_o);
			$stop;
		end

		story_o <= 16'h0502;
		wait(clk_o); wait(~clk_o);
		if(f_adr_i !== 1) begin
			$display("@E %04X Expected fetch address 1; got %d", story_o, f_adr_i);
			$stop;
		end
		if(load_i !== 1) begin
			$display("@E %04X Expected load_o asserted", story_o);
			$stop;
		end

		story_o <= 16'h0503;
		wait(clk_o); wait(~clk_o);
		if(f_adr_i !== 2) begin
			$display("@E %04X Expected fetch address 2; got %d", story_o, f_adr_i);
			$stop;
		end
		if(load_i !== 0) begin
			$display("@E %04X Expected load_o negated", story_o);
			$stop;
		end

		story_o <= 16'h0504;
		wait(clk_o); wait(~clk_o);
		if(f_adr_i !== 2) begin
			$display("@E %04X Expected fetch address 2; got %d", story_o, f_adr_i);
			$stop;
		end
		if(load_i !== 1) begin
			$display("@E %04X Expected load_o asserted", story_o);
			$stop;
		end

		story_o <= 16'h0505;
		wait(clk_o); wait(~clk_o);
		if(f_adr_i !== 3) begin
			$display("@E %04X Expected fetch address 3; got %d", story_o, f_adr_i);
			$stop;
		end
		if(load_i !== 0) begin
			$display("@E %04X Expected load_o negated", story_o);
			$stop;
		end

		story_o <= 16'h0506;
		wait(clk_o); wait(~clk_o);
		if(f_adr_i !== 3) begin
			$display("@E %04X Expected fetch address 3; got %d", story_o, f_adr_i);
			$stop;
		end
		if(load_i !== 1) begin
			$display("@E %04X Expected load_o asserted", story_o);
			$stop;
		end

		story_o <= 16'h0507;
		wait(clk_o); wait(~clk_o);
		if(f_adr_i !== 4) begin
			$display("@E %04X Expected fetch address 4; got %d", story_o, f_adr_i);
			$stop;
		end
		if(load_i !== 0) begin
			$display("@E %04X Expected load_o negated", story_o);
			$stop;
		end

		story_o <= 16'h0508;
		wait(clk_o); wait(~clk_o);
		if(f_adr_i !== 4) begin
			$display("@E %04X Expected fetch address 4; got %d", story_o, f_adr_i);
			$stop;
		end
		if(load_i !== 1) begin
			$display("@E %04X Expected load_o asserted", story_o);
			$stop;
		end

		story_o <= 16'h0509;
		wait(clk_o); wait(~clk_o);
		if(f_adr_i !== 5) begin
			$display("@E %04X Expected fetch address 5; got %d", story_o, f_adr_i);
			$stop;
		end
		if(load_i !== 0) begin
			$display("@E %04X Expected load_o negated", story_o);
			$stop;
		end

		story_o <= 16'h050A;
		wait(clk_o); wait(~clk_o);
		if(f_adr_i !== 5) begin
			$display("@E %04X Expected fetch address 5; got %d", story_o, f_adr_i);
			$stop;
		end
		if(load_i !== 1) begin
			$display("@E %04X Expected load_o asserted", story_o);
			$stop;
		end

		story_o <= 16'h050B;
		wait(clk_o); wait(~clk_o);
		if(f_adr_i !== 6) begin
			$display("@E %04X Expected fetch address 6; got %d", story_o, f_adr_i);
			$stop;
		end
		if(load_i !== 0) begin
			$display("@E %04X Expected load_o negated", story_o);
			$stop;
		end

		story_o <= 16'h050C;
		wait(clk_o); wait(~clk_o);
		if(f_adr_i !== 6) begin
			$display("@E %04X Expected fetch address 6; got %d", story_o, f_adr_i);
			$stop;
		end
		if(load_i !== 1) begin
			$display("@E %04X Expected load_o asserted", story_o);
			$stop;
		end

		story_o <= 16'h050D;
		wait(clk_o); wait(~clk_o);
		if(f_adr_i !== 7) begin
			$display("@E %04X Expected fetch address 7; got %d", story_o, f_adr_i);
			$stop;
		end
		if(load_i !== 0) begin
			$display("@E %04X Expected load_o negated", story_o);
			$stop;
		end

		story_o <= 16'h050E;
		wait(clk_o); wait(~clk_o);
		if(f_adr_i !== 7) begin
			$display("@E %04X Expected fetch address 7; got %d", story_o, f_adr_i);
			$stop;
		end
		if(load_i !== 1) begin
			$display("@E %04X Expected load_o asserted", story_o);
			$stop;
		end

		story_o <= 16'h050F;
		wait(clk_o); wait(~clk_o);
		if(f_adr_i !== 8) begin
			$display("@E %04X Expected fetch address 8; got %d", story_o, f_adr_i);
			$stop;
		end
		if(load_i !== 0) begin
			$display("@E %04X Expected load_o negated", story_o);
			$stop;
		end

		story_o <= 16'h0510;
		wait(clk_o); wait(~clk_o);
		if(f_adr_i !== 8) begin
			$display("@E %04X Expected fetch address 8; got %d", story_o, f_adr_i);
			$stop;
		end
		if(load_i !== 1) begin
			$display("@E %04X Expected load_o asserted", story_o);
			$stop;
		end

		story_o <= 16'h0511;
		wait(clk_o); wait(~clk_o);
		if(f_adr_i !== 9) begin
			$display("@E %04X Expected fetch address 9; got %d", story_o, f_adr_i);
			$stop;
		end
		if(load_i !== 0) begin
			$display("@E %04X Expected load_o negated", story_o);
			$stop;
		end

		#100 $display("@I OK");
		$stop;
	end
endmodule

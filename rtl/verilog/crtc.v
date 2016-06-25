`timescale 1ns / 1ps

// This module implements the CRT Controller.  Something of a misnomer these
// days, a CRTC is responsible for generating horizontal and vertical sync
// pulses, determining where in a horizontal line the frame buffer starts, when
// it ends, and so forth.
//
// This module does not implement any registers; all configurable values are
// taken as module inputs, and provided by a separate register set module.
//
// A horizontal scanline ranges from when the X counter lies between 0 and
// the htotal value, inclusive.  Similarly, a frame consists of all horizontal
// lines from when the Y counter lies between 0 and the vtotal value.
//
// The X counter monotonically increments at the same rate as the dot clock.
// The Y counter increments at the rate of the horizontal sync pulse.
// A scanline terminates when HSYNC negates; a new line begins immediately
// thereafter.
//
// This means that the HSYNC starting pixel is not hardwired to zero, like
// most other video controllers; instead, HSYNC starts somewhere in the far
// right-hand range of a given scanline.
//
//	HSYNC:
//	                  _
//      _________________/ \__
//                       ^ ^
//	VIDEO:           | |
//	   ___________   | |
//	__/___________\__|_|__
//	^ ^           ^  | |
//	| |           |  | |
//	| |           |  | +-- htotal_i
//	| |           |  +---- hsstart_i
//      | |           +------- hvend_i
//      | +------------------- hvstart_i
//      +--------------------- Hardwired to 0.
//
// Similar parameters exist for vertical timing as well.  However, vertical
// timing signals are sampled only when horizontal total is reached.  For this
// reason, vvstart_i is set to one less than the intended scanline where video
// display is to occur.  Respectively, vvend_i holds one less than the intended
// end of display in the frame.  That way, VDEN is synchronized with the actual
// left-edge of the display.
//
// When displaying video, two signals are generated to tell external circuitry
// what's going on: HDEN and VDEN.  HDEN is the horizontal display enable, and
// VDEN is the vertical display enable.  The logical AND of these two signals
// should be used with the "scanline_en_i" port of the feeder module.
//
// There is another timing signal, called VFEN, which is asserted when the
// fetcher is to start fetching of the next scanline.  Since the video fetch
// happens asynchronously to display refresh, we just trigger it at the start
// of the previous display line.  Typically, ODD_I on the fetcher is tied to
// the y_o[0] signal.

module crtc(
	input		dotclk_i,	// 25MHz dot clock
	input		reset_i,	// Wishbone RESET signal.
	input	[9:0]	htotal_i,	// Horizontal total.
	input	[9:0]	vtotal_i,	// Vertical total.
	input	[9:0]	hsstart_i,	// Horizontal sync start.
	input	[9:0]	vsstart_i,	// Vertical sync start.
	input	[9:0]	hvstart_i,	// Horizontal video start.
	input	[9:0]	hvend_i,	// Horizontal video end.
	input	[9:0]	vvstart_i,	// Vertical video start.
	input	[9:0]	vvend_i,	// Vertical video end.

	output		hsync_o,	// Horizontal sync (active high)
	output		vsync_o,	// Vertical sync (active high)
	output		hden_o,		// Horizontal display enable (active high)
	output		vfen_o,		// Video fetch enable (active high)
	output		vden_o,		// Vertical display enable (active high)
	output	[9:0]	x_o,		// Current horizontal pixel counter (0..799)
	output	[9:0]	y_o		// Current raster line counter (0..524)
);
	wire htotal_reached = x_o == htotal_i;
	wire vtotal_reached = y_o == vtotal_i;
	wire zero_y = reset_i | (htotal_reached & vtotal_reached);
	wire horiz_display_start = x_o == hvstart_i;
	wire horiz_display_end = x_o == hvend_i;
	wire vert_display_start = y_o == vvstart_i & htotal_reached;
	wire vert_display_end = y_o == vvend_i & htotal_reached;

	wire hsync_o = x_o >= hsstart_i;
	wire vsync_o = y_o >= vsstart_i;

	reg vfen_o;
	always @(posedge dotclk_i) begin
		case({reset_i, vert_display_start, vert_display_end})
		3'b000: vfen_o <= vfen_o;
		3'b001: vfen_o <= 0;
		3'b010: vfen_o <= 1;
		3'b011: vfen_o <= 0;
		3'b100: vfen_o <= 0;
		3'b101: vfen_o <= 0;
		3'b110: vfen_o <= 0;
		3'b111: vfen_o <= 0;
		endcase
	end

	reg vden_o;
	always @(posedge dotclk_i) begin
		vden_o = (htotal_reached) ? vfen_o : vden_o;
	end

	reg hden_o;
	always @(posedge dotclk_i) begin
		case({reset_i, horiz_display_start, horiz_display_end})
		3'b000: hden_o <= hden_o;
		3'b001: hden_o <= 0;
		3'b010: hden_o <= 1;
		3'b011: hden_o <= 0;
		3'b100: hden_o <= 0;
		3'b101: hden_o <= 0;
		3'b110: hden_o <= 0;
		3'b111: hden_o <= 0;
		endcase
	end

	reg [9:0] x_o;
	always @(posedge dotclk_i) begin
		x_o <= (reset_i | htotal_reached)? 0 : x_o + 1;
	end

	reg [9:0] y_o;
	always @(posedge dotclk_i) begin
		y_o <= (zero_y)? 0 : (htotal_reached) ? y_o + 1 : y_o;
	end
endmodule


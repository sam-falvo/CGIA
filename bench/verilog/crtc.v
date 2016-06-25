`timescale 1ns / 1ps

// This module exercises the CRTC.

module test_crtc();
	reg [15:0] story_o;
	reg reset_o;
	reg dotclk_o;
	reg [9:0] htotal_o;
	reg [9:0] vtotal_o;
	reg [9:0] hsstart_o;
	reg [9:0] vsstart_o;
	reg [9:0] hvstart_o;
	reg [9:0] hvend_o;
	reg [9:0] vvstart_o;
	reg [9:0] vvend_o;

	wire [9:0] x_i;
	wire [9:0] y_i;
	wire hsync_i;
	wire vsync_i;
	wire hden_i;
	wire vfen_i;
	wire vden_i;

	crtc c(
		.dotclk_i(dotclk_o),
		.reset_i(reset_o),
		.htotal_i(htotal_o),
		.vtotal_i(vtotal_o),
		.hsstart_i(hsstart_o),
		.vsstart_i(vsstart_o),
		.hsync_o(hsync_i),
		.vsync_o(vsync_i),
		.hvstart_i(hvstart_o),
		.hvend_i(hvend_o),
		.vvstart_i(vvstart_o),
		.vvend_i(vvend_o),
		.hden_o(hden_i),
		.vfen_o(vfen_i),
		.vden_o(vden_i),
		.x_o(x_i),
		.y_o(y_i)
	);

	// Dot clock is 25MHz (40ns)
	always begin
		#40 dotclk_o <= ~dotclk_o;
	end

	initial begin
		dotclk_o <= 0;
		reset_o <= 0;
		htotal_o <= 799;
		vtotal_o <= 524;
		hsstart_o <= 790;
		vsstart_o <= 520;
		hvstart_o <= 16;
		hvend_o <= 656;
		vvstart_o <= 16;
		vvend_o <= 496;

		wait(dotclk_o); wait(~dotclk_o);

		// On reset, pixel and line counters should be zero.
		story_o <= 16'h0000;
		reset_o <= 1;
		wait(dotclk_o); wait(~dotclk_o);
		if(x_i !== 0) begin
			$display("@E %04X After reset, expected 0 X counter; got %d", story_o, x_i);
			$stop;
		end
		if(y_i !== 0) begin
			$display("@E %04X After reset, expected 0 Y counter; got %d", story_o, y_i);
			$stop;
		end

		// After reset, we expect the horizontal pixel counter to increment after each clock.
		story_o <= 16'h0100;
		reset_o <= 0;
		wait(dotclk_o); wait(~dotclk_o);
		if(x_i !== 1) begin
			$display("@E %04X After reset, expected 1 X counter; got %d", story_o, x_i);
			$stop;
		end
		if(y_i !== 0) begin
			$display("@E %04X After reset, expected 0 Y counter; got %d", story_o, y_i);
			$stop;
		end
		wait(dotclk_o); wait(~dotclk_o);
		if(x_i !== 2) begin
			$display("@E %04X After reset, expected 2 X counter; got %d", story_o, x_i);
			$stop;
		end
		if(y_i !== 0) begin
			$display("@E %04X After reset, expected 0 Y counter; got %d", story_o, y_i);
			$stop;
		end


		// We expect the horizontal pixel counter to reset when the
		// horizontal total is reached.
		story_o <= 16'h0200;
		htotal_o <= 5;
		wait(dotclk_o); wait(~dotclk_o);
		wait(dotclk_o); wait(~dotclk_o);
		wait(dotclk_o); wait(~dotclk_o);
		wait(dotclk_o); wait(~dotclk_o);
		if(x_i !== 0) begin
			$display("@E %04X After htotal, expected 0 X counter; got %d", story_o, x_i);
			$stop;
		end
		if(y_i !== 1) begin
			$display("@E %04X After htotal, expected 1 Y counter; got %d", story_o, y_i);
			$stop;
		end
		wait(dotclk_o); wait(~dotclk_o);

		// We expect HSYNC to negate when horizontal counter resets to zero.
		if(hsync_i !== 0) begin
			$display("@E %04X After X reset, expected HSYNC negated.", story_o);
			$stop;
		end

		// We expect HSYNC to assert when the horizontal counter reaches sync start.
		story_o <= 16'h0300;
		htotal_o <= 5;
		hsstart_o <= 3;
		reset_o <= 1;
		wait(dotclk_o); wait(~dotclk_o);	// 0
		reset_o <= 0;
		wait(dotclk_o); wait(~dotclk_o);	// 1
		wait(dotclk_o); wait(~dotclk_o);	// 2
		if(hsync_i !== 0) begin
			$display("@E %04X Expected HSYNC negated.", story_o);
			$stop;
		end
		story_o <= 16'h0310;
		wait(dotclk_o); wait(~dotclk_o);	// 3
		if(hsync_i !== 1) begin
			$display("@E %04X Expected HSYNC asserted.", story_o);
			$stop;
		end
		wait(dotclk_o); wait(~dotclk_o);	// 4
		wait(dotclk_o); wait(~dotclk_o);	// 5
		story_o <= 16'h0320;
		if(hsync_i !== 1) begin
			$display("@E %04X Expected HSYNC asserted.", story_o);
			$stop;
		end
		story_o <= 16'h0330;
		wait(dotclk_o); wait(~dotclk_o);	// 0, Y=1 at this point.
		if(hsync_i !== 0) begin
			$display("@E %04X Expected HSYNC negated.", story_o);
			$stop;
		end

		// We expect VSYNC to assert when the vertical counter reaches sync start.
		story_o <= 16'h0400;
		vsstart_o <= 2;
		vtotal_o <= 3;
		wait(dotclk_o); wait(~dotclk_o);	// 1, Y=1
		if(vsync_i !== 0) begin
			$display("@E %04X Expected VSYNC negated.", story_o);
			$stop;
		end
		wait(dotclk_o); wait(~dotclk_o);	// 2, Y=1
		wait(dotclk_o); wait(~dotclk_o);	// 3, Y=1
		wait(dotclk_o); wait(~dotclk_o);	// 4, Y=1
		wait(dotclk_o); wait(~dotclk_o);	// 5, Y=1
		wait(dotclk_o); wait(~dotclk_o);	// 0, Y=2
		if(vsync_i !== 1) begin
			$display("@E %04X Expected VSYNC asserted.", story_o);
			$stop;
		end
		wait(dotclk_o); wait(~dotclk_o);	// 1, Y=2
		wait(dotclk_o); wait(~dotclk_o);	// 2, Y=2
		wait(dotclk_o); wait(~dotclk_o);	// 3, Y=2
		wait(dotclk_o); wait(~dotclk_o);	// 4, Y=2
		wait(dotclk_o); wait(~dotclk_o);	// 5, Y=2
		wait(dotclk_o); wait(~dotclk_o);	// 0, Y=3
		wait(dotclk_o); wait(~dotclk_o);	// 1, Y=3
		wait(dotclk_o); wait(~dotclk_o);	// 2, Y=3
		wait(dotclk_o); wait(~dotclk_o);	// 3, Y=3
		wait(dotclk_o); wait(~dotclk_o);	// 4, Y=3
		wait(dotclk_o); wait(~dotclk_o);	// 5, Y=3
		wait(dotclk_o); wait(~dotclk_o);	// 0, Y=0
		if(y_i !== 0) begin
			$display("@E %04X Expected y_o = 0; got %d", story_o, y_i);
			$stop;
		end

		// We expect VSYNC to negate when the vertical counter wraps around.
		story_o <= 16'h0500;
		if(vsync_i !== 0) begin
			$display("@E $04X Expected VSYNC negated.", story_o);
			$stop;
		end

		// We expect HDEN to assert when we're displaying the visible
		// portion of the scanline.
		story_o <= 16'h0600;
		hsstart_o <= 5;
		vsstart_o <= 3;
		htotal_o <= 5;
		vtotal_o <= 3;
		hvstart_o <= 1;
		hvend_o <= 4;
		vvstart_o <= 1;
		vvend_o <= 2;
		reset_o <= 1;
		wait(dotclk_o); wait(~dotclk_o);	// X=0, Y=0
		if(hden_i !== 0) begin
			$display("@E %04X Expected HDEN negated", story_o);
			$stop;
		end

		reset_o <= 0;
		wait(dotclk_o); wait(~dotclk_o);	// X=1, Y=0
		story_o <= 16'h0610;
		wait(dotclk_o); wait(~dotclk_o);	// X=2, Y=0
		if(hden_i !== 1) begin
			$display("@E %04X Expected HDEN asserted", story_o);
			$stop;
		end
		wait(dotclk_o); wait(~dotclk_o);	// X=3, Y=0
		wait(dotclk_o); wait(~dotclk_o);	// X=4, Y=0
		story_o <= 16'h0620;
		wait(dotclk_o); wait(~dotclk_o);	// X=5, Y=0
		if(hden_i !== 0) begin
			$display("@E %04X Expected HDEN negated", story_o);
			$stop;
		end
		wait(dotclk_o); wait(~dotclk_o);	// X=0, Y=1
		
		// We expect VFEN to assert just before displaying the visible
		// portion of the frame.  REMEMBER: Because vertical signals
		// are sampled at the very end of each scanline (literally,
		// one dot-clock before the start of a new scanline), we need
		// to subtract one from the vertical fields so that the actual
		// start and end of VFEN happens at the desired times.
		//
		// Since we enable VFEN one scanline before the VDEN line,
		// this implies that the actual pixels will be displayed TWO
		// lines down from where the vertical start says it should.
		story_o <= 16'h0700;
		hsstart_o <= 5;
		vsstart_o <= 3;
		htotal_o <= 5;
		vtotal_o <= 5;
		hvstart_o <= 1;
		hvend_o <= 4;
		vvstart_o <= 0;		// We "start" on the end of line 0, so it'll assert on line 1.
		vvend_o <= 2;		// We "end" on the end of line 2, so we'll be done by the time line 3 starts.
		reset_o <= 1;
		wait(dotclk_o); wait(~dotclk_o);	// X=0, Y=0
		reset_o <= 0;
		wait(dotclk_o); wait(~dotclk_o);	// X=1, Y=0
		wait(dotclk_o); wait(~dotclk_o);	// X=2, Y=0
		wait(dotclk_o); wait(~dotclk_o);	// X=3, Y=0
		wait(dotclk_o); wait(~dotclk_o);	// X=4, Y=0
		story_o <= 16'h0710;
		wait(dotclk_o); wait(~dotclk_o);	// X=5, Y=0
		if(vfen_i !== 0) begin
			$display("@E %04X Expected VFEN negated", story_o);
			$stop;
		end
		if(vden_i !== 0) begin
			$display("@E %04X Expected VDEN negated", story_o);
			$stop;
		end
		story_o <= 16'h0720;
		wait(dotclk_o); wait(~dotclk_o);	// X=0, Y=1
		if(vfen_i !== 1) begin
			$display("@E %04X Expected VFEN asserted", story_o);
			$stop;
		end
		if(vden_i !== 0) begin
			$display("@E %04X Expected VDEN negated", story_o);
			$stop;
		end
		wait(dotclk_o); wait(~dotclk_o);	// X=1, Y=1
		wait(dotclk_o); wait(~dotclk_o);	// X=2, Y=1
		wait(dotclk_o); wait(~dotclk_o);	// X=3, Y=1
		wait(dotclk_o); wait(~dotclk_o);	// X=4, Y=1
		wait(dotclk_o); wait(~dotclk_o);	// X=5, Y=1
		if(vden_i !== 0) begin
			$display("@E %04X Expected VDEN negated", story_o);
			$stop;
		end
		story_o <= 16'h0728;
		wait(dotclk_o); wait(~dotclk_o);	// X=0, Y=2
		if(vden_i !== 1) begin
			$display("@E %04X Expected VDEN asserted", story_o);
			$stop;
		end
		wait(dotclk_o); wait(~dotclk_o);	// X=1, Y=2
		wait(dotclk_o); wait(~dotclk_o);	// X=2, Y=2
		wait(dotclk_o); wait(~dotclk_o);	// X=3, Y=2
		wait(dotclk_o); wait(~dotclk_o);	// X=4, Y=2
		story_o <= 16'h0730;
		wait(dotclk_o); wait(~dotclk_o);	// X=5, Y=2
		if(vfen_i !== 1) begin
			$display("@E %04X Expected VFEN asserted", story_o);
			$stop;
		end
		if(vden_i !== 1) begin
			$display("@E %04X Expected VDEN asserted", story_o);
			$stop;
		end
		story_o <= 16'h0740;
		wait(dotclk_o); wait(~dotclk_o);	// X=0, Y=3
		if(vfen_i !== 0) begin
			$display("@E %04X Expected VFEN negated", story_o);
			$stop;
		end
		if(vden_i !== 1) begin
			$display("@E %04X Expected VDEN asserted", story_o);
			$stop;
		end
		wait(dotclk_o); wait(~dotclk_o);	// X=1, Y=3
		wait(dotclk_o); wait(~dotclk_o);	// X=2, Y=3
		wait(dotclk_o); wait(~dotclk_o);	// X=3, Y=3
		wait(dotclk_o); wait(~dotclk_o);	// X=4, Y=3
		story_o <= 16'h0750;
		wait(dotclk_o); wait(~dotclk_o);	// X=5, Y=3
		if(vfen_i !== 0) begin
			$display("@E %04X Expected VFEN asserted", story_o);
			$stop;
		end
		if(vden_i !== 1) begin
			$display("@E %04X Expected VDEN asserted", story_o);
			$stop;
		end
		story_o <= 16'h0760;
		wait(dotclk_o); wait(~dotclk_o);	// X=0, Y=0
		if(vfen_i !== 0) begin
			$display("@E %04X Expected VFEN asserted", story_o);
			$stop;
		end
		if(vden_i !== 0) begin
			$display("@E %04X Expected VDEN negated", story_o);
			$stop;
		end
		
		$display("@I Done.");
		$stop;
	end
endmodule


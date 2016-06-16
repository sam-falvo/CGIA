.PHONY: test test_fetcher test_line_buffers test_shifter test_feeder

test: test_fetcher test_line_buffers test_shifter test_feeder

test_fetcher:
	iverilog bench/verilog/fetcher.v rtl/verilog/fetcher.v
	vvp -n a.out

test_line_buffers:
	iverilog bench/verilog/line_buffers.v rtl/verilog/line_buffers.v
	vvp -n a.out

test_shifter: test_shift_register
	iverilog bench/verilog/shifter.v rtl/verilog/shifter.v rtl/verilog/shift_register.v
	vvp -n a.out

test_shift_register:
	iverilog bench/verilog/shift_register.v rtl/verilog/shift_register.v
	vvp -n a.out

test_feeder:
	iverilog bench/verilog/feeder.v rtl/verilog/feeder.v
	vvp -n a.out

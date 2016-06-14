.PHONY: test test_fetcher test_line_buffers

test: test_fetcher test_line_buffers

test_fetcher:
	iverilog bench/verilog/test_fetcher.v rtl/verilog/fetcher.v
	vvp -n a.out

test_line_buffers:
	iverilog bench/verilog/test_line_buffers.v rtl/verilog/line_buffers.v
	vvp -n a.out


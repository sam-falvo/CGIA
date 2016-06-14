.PHONY: test

test: test_fetcher

.PHONY: test_fetcher

test_fetcher:
	iverilog bench/verilog/test_fetcher.v rtl/verilog/fetcher.v
	vvp -n a.out


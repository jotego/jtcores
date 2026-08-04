TEST_DIRS = sdram cabinet

test:
	@for test_dir in $(TEST_DIRS); do $(MAKE) -C $$test_dir test || exit $$?; done

clean:
	@for test_dir in $(TEST_DIRS); do $(MAKE) -C $$test_dir clean; done

.PHONY: test clean

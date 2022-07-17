CC ?= gcc
CFLAGS = -O2 -Wall
LDFLAGS = -lpthread
SHELL := /bin/bash

# For building riscv-tests
CROSS_COMPILE ?= riscv64-unknown-elf-

CUR_DIR := $(shell pwd)
TESTS_DIR := $(CUR_DIR)/tests
RISCV_TESTS_DIR := $(TESTS_DIR)/riscv-tests
RISCV_TESTS_ISA_DIR := $(RISCV_TESTS_DIR)/isa
RISCV_TESTS_BIN_DIR := $(TESTS_DIR)/riscv-tests-data

BIN := semu

OBJS := semu.o

# Whether to enable riscv-tests
ENABLE_RISCV_TESTS ?= 0
ifeq ("$(ENABLE_RISCV_TESTS)", "1")
CFLAGS += -DENABLE_RISCV_TESTS
OBJS += tests/isa-test.o
endif

%.o: %.c
	$(CC) -o $@ $(CFLAGS) -c $<

all: $(BIN)

$(BIN): $(OBJS)
	$(CC) -o $@ $^ $(LDFLAGS)

kernel.bin:
	scripts/download.sh

check: all kernel.bin
	./semu kernel.bin fs.img

$(RISCV_TESTS_DIR)/configure:
	git submodule update --init --recursive

# Fetch and build riscv-tests project
# Transform the original elf format to binary format
build-riscv-tests: $(RISCV_TESTS_DIR)/configure
	cd $(RISCV_TESTS_DIR); ./configure
	$(MAKE) -C $(RISCV_TESTS_DIR) isa
	mkdir -p $(RISCV_TESTS_BIN_DIR)
	for file in $(RISCV_TESTS_ISA_DIR)/rv64*; do \
		if [ -d $$file ] || [[ $$file == *.dump ]]; then \
			continue; \
		fi; \
		original=$$(basename $$file); \
		filename=$$(echo $$original | sed -e "s/-/_/g"); \
		$(CROSS_COMPILE)objcopy -O binary $$file $(RISCV_TESTS_BIN_DIR)/$$filename; \
		echo "Transform ELF into binary:" $$file "--> $(RISCV_TESTS_BIN_DIR)/$$filename"; \
	done

riscv-tests: $(BIN) build-riscv-tests
	./semu --test

clean:
	rm -f $(BIN) $(OBJS)
distclean: clean
	rm -f kernel.bin fs.img
	rm -rf $(RISCV_TESTS_BIN_DIR)

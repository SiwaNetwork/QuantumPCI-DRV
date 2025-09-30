# Makefile for Phase 3 Extensions
# Network Integration, PTP v2.1, NTP Stratum 1, Security

obj-m += ptp_ocp_phase3.o

# Phase 3 modules
ptp_ocp_phase3-objs := \
    network/network_integration.o \
    protocols/ptp_v2_1.o \
    protocols/ntp_stratum1.o \
    security/ptp_security.o

# Core driver dependencies
PTP_OCP_CORE_DIR := ../core

# Include core driver headers
ccflags-y += -I$(PTP_OCP_CORE_DIR)

# Kernel build system
KDIR := /lib/modules/$(shell uname -r)/build
PWD := $(shell pwd)

# Build targets
all: modules

modules:
	$(MAKE) -C $(KDIR) M=$(PWD) modules

clean:
	$(MAKE) -C $(KDIR) M=$(PWD) clean
	rm -f *.o *.ko *.mod.c *.mod *.symvers *.order

install: modules
	sudo insmod ptp_ocp_phase3.ko

uninstall:
	sudo rmmod ptp_ocp_phase3

# Development targets
check:
	@echo "Checking Phase 3 extensions..."
	@if [ ! -f network/network_integration.c ]; then \
		echo "ERROR: network_integration.c not found"; \
		exit 1; \
	fi
	@if [ ! -f protocols/ptp_v2_1.c ]; then \
		echo "ERROR: ptp_v2_1.c not found"; \
		exit 1; \
	fi
	@if [ ! -f protocols/ntp_stratum1.c ]; then \
		echo "ERROR: ntp_stratum1.c not found"; \
		exit 1; \
	fi
	@if [ ! -f security/ptp_security.c ]; then \
		echo "ERROR: ptp_security.c not found"; \
		exit 1; \
	fi
	@echo "All Phase 3 files present"

test:
	@echo "Running Phase 3 tests..."
	@if [ -f tests/run_phase3_tests.sh ]; then \
		chmod +x tests/run_phase3_tests.sh; \
		./tests/run_phase3_tests.sh; \
	else \
		echo "No tests found for Phase 3"; \
	fi

help:
	@echo "Phase 3 Extensions Makefile"
	@echo "Available targets:"
	@echo "  all       - Build all modules"
	@echo "  modules   - Build kernel modules"
	@echo "  clean     - Clean build files"
	@echo "  install   - Install modules"
	@echo "  uninstall - Remove modules"
	@echo "  check     - Check for required files"
	@echo "  test      - Run tests"
	@echo "  help      - Show this help"

.PHONY: all modules clean install uninstall check test help


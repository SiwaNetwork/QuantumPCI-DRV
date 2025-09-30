# Enhanced PTP OCP Driver Makefile
# Version 2.0.0

obj-m += ptp_ocp_enhanced.o

# Source files
ptp_ocp_enhanced-objs := \
	core/ptp_ocp_enhanced_simple.o \
	core/performance.o \
	core/monitoring.o

# Compiler flags
ccflags-y += -DPTP_OCP_DRIVER_VERSION=\"2.0.0\"
ccflags-y += -DPTP_OCP_DEBUG

# Include directories
ccflags-y += -I$(src)/core
ccflags-y += -I$(src)/include

# Kernel version compatibility
ifneq ($(KERNELRELEASE),)
# Called from kbuild
else
# Called from command line
KDIR := /lib/modules/$(shell uname -r)/build
PWD := $(shell pwd)
endif

# Build targets
all:
	$(MAKE) -C $(KDIR) M=$(PWD) modules

clean:
	$(MAKE) -C $(KDIR) M=$(PWD) clean
	rm -f *.o *.ko *.mod.c *.mod *.symvers *.order

install:
	$(MAKE) -C $(KDIR) M=$(PWD) modules_install
	depmod -a

uninstall:
	rm -f /lib/modules/$(shell uname -r)/extra/ptp_ocp_enhanced.ko
	depmod -a

# Development targets
debug:
	$(MAKE) -C $(KDIR) M=$(PWD) modules EXTRA_CFLAGS="-g -DDEBUG"

test:
	@echo "Running enhanced driver tests..."
	@./tests/run_tests.sh

# Documentation
docs:
	@echo "Generating documentation..."
	@doxygen docs/Doxyfile

# Code quality
check:
	@echo "Running code quality checks..."
	@checkpatch.pl --no-tree --strict core/*.c
	@sparse core/*.c

.PHONY: all clean install uninstall debug test docs check

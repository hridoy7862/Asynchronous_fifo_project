# Configuration

TOP       = tb_async_fifo

RTL_DIR   = ../rtl
TB_DIR    = ../tb

RTL_SRCS  = $(wildcard $(RTL_DIR)/*.sv)
TB_SRCS   = $(wildcard $(TB_DIR)/*.sv)

SRCS      = $(RTL_SRCS) $(TB_SRCS)

XVLOG     = xvlog
XELAB     = xelab
XSIM      = xsim

SNAPSHOT  = $(TOP)_snap

# Default Target

all: compile elaborate simulate

# Compile

compile:
	$(XVLOG) --sv $(SRCS)

# Elaborate

elaborate:
	$(XELAB) $(TOP) -snapshot $(SNAPSHOT)

# Simulate (Batch Mode)

simulate:
	$(XSIM) $(SNAPSHOT) -runall

# GUI Mode

gui:
	$(XSIM) $(SNAPSHOT) --gui

# Clean

clean:
	rm -rf xsim.dir *.jou *.log *.pb *.wdb

# Rebuild

rebuild: clean all

.PHONY: all compile elaborate simulate gui clean rebuild

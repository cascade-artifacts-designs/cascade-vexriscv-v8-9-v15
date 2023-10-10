# Copyright 2022 Flavien Solt, ETH Zurich.
# Licensed under the General Public License, Version 3.0, see LICENSE for details.
# SPDX-License-Identifier: GPL-3.0-only

ifeq "" "$(CASCADE_ENV_SOURCED)"
$(error Please re-source env.sh first, in the meta repo)
endif

PYTHON ?= python3
RESOURCEWRAPPER_TAG ?= vexriscv

TOP_MODULE = vexriscv_mem_top
TOP_SOC = vexriscv_tiny_soc
TOP_EXECUTABLE_NAME = V$(TOP_SOC)

# For drfuzz
TOP_RESET = rst_ni
EXCLUDE_SIGNALS ?= clk_i,rst_ni

TARGET_NAMES = vanilla rfuzz drfuzz

include $(CASCADE_DESIGN_PROCESSING_ROOT)/common/design.mk

# This target makes the design until the Yosys instrumentation. From there on, the Makefile can run in parallel for the various instrumentation targets.
before_instrumentation: generated/sv2v_out.v

generated/VexRiscv.v: | generated
	cd .. && sbt "runMain vexriscv.demo.VexRiscvAhbLite3cascade" && cp VexRiscv.v cascade/$@ && cd cascade

generated/sv2v_out.v: generated/out/vanilla.sv
	sv2v -E=UnbasedUnsized $^ -w $@

generated/out/vanilla.sv: src/memreq_aligner.sv src/prim_fifo_sync.sv src/bmb_full_to_mem.sv src/ahb3lite_pkg.sv generated/VexRiscv.v src/vexriscv_mem_top.sv src/ahb3lite_apb_bridge.sv src/apb_to_mem.sv | generated/out
	morty $^ -o $@
	touch $@.log

# rfuzz coverage metric
generated/out/rfuzz.sv: $(CASCADE_YS)/rfuzz.ys.tcl generated/sv2v_out.v | generated/out logs
	DECOMPOSE_MEMORY=1 VERILOG_INPUT=$(word 2,$^) INSTRUMENTATION=$* VERILOG_OUTPUT=$@ TOP_MODULE=$(TOP_MODULE) yosys -c $< -l $@.log
# difuzzrtl coverage metric
generated/out/difuzzrtl.sv: $(CASCADE_YS)/difuzzrtl.ys.tcl generated/sv2v_out.v | generated/out logs
	DECOMPOSE_MEMORY=1 VERILOG_INPUT=$(word 2,$^) INSTRUMENTATION=$* VERILOG_OUTPUT=$@ TOP_MODULE=$(TOP_MODULE) yosys -c $< -l $@.log
# Active RFUZZ
generated/out/drfuzz.sv: $(CASCADE_YS)/drfuzz.ys.tcl generated/sv2v_out.v | generated/out logs
	DECOMPOSE_MEMORY=1 VERILOG_INPUT=$(word 2,$^) INSTRUMENTATION=drfuzz VERILOG_OUTPUT=$@ TOP_MODULE=$(TOP_MODULE) EXCLUDE_SIGNALS=$(EXCLUDE_SIGNALS) TOP_RESET=$(TOP_RESET) VERBOSE=$(VERBOSE) yosys -c $< -l $@.log

#
# Verilator simulation
#

# Phony targets

PREPARE_TARGETS_NOTRACE=$(patsubst %,prepare_%_notrace, $(TARGET_NAMES))
PREPARE_TARGETS_TRACE=$(patsubst %,prepare_%_trace, $(TARGET_NAMES))
PREPARE_TARGETS_TRACE_FST=$(patsubst %,prepare_%_trace_fst, $(TARGET_NAMES))
PREPARE_TARGETS = $(PREPARE_TARGETS_NOTRACE) $(PREPARE_TARGETS_TRACE) $(PREPARE_TARGETS_TRACE)

.PHONY: $(PREPARE_TARGETS)
$(PREPARE_TARGETS): prepare_%: build/run_%_0.1/default-verilator/$(TOP_EXECUTABLE_NAME)

# Core files
CORE_FILES_NOTRACE=$(patsubst %,run_%_notrace.core, $(TARGET_NAMES))
$(CORE_FILES_NOTRACE): run_%.core: run_%.core.template
	$(PYTHON) $(CASCADE_PYTHON_COMMON)/gen_corefiles.py $< $@

# Actual targets

BUILD_TARGETS_NOTRACE=$(patsubst %,build/run_%_notrace_0.1/default-verilator/$(TOP_EXECUTABLE_NAME), $(TARGET_NAMES))
BUILD_TARGETS_TRACE=$(patsubst %,build/run_%_trace_0.1/default-verilator/$(TOP_EXECUTABLE_NAME), $(TARGET_NAMES))
BUILD_TARGETS_TRACE_FST=$(patsubst %,build/run_%_trace_fst_0.1/default-verilator/$(TOP_EXECUTABLE_NAME), $(TARGET_NAMES))
BUILD_TARGETS = $(BUILD_TARGETS_NOTRACE) $(BUILD_TARGETS_TRACE) $(BUILD_TARGETS_TRACE_FST)

$(BUILD_TARGETS_NOTRACE): build/run_%_notrace_0.1/default-verilator/$(TOP_EXECUTABLE_NAME): generated/out/%.sv generated/out/%.sv.log run_%_notrace.core
	rm -f fusesoc.conf
	fusesoc library add run_$*_notrace .
	fusesoc run --build run_$*_notrace
	cp $<.log $@.log
$(BUILD_TARGETS_TRACE): build/run_%_trace_0.1/default-verilator/$(TOP_EXECUTABLE_NAME): generated/out/%.sv generated/out/%.sv.log run_%_trace.core
	rm -f fusesoc.conf
	fusesoc library add run_$*_trace .
	fusesoc run --build run_$*_trace
	cp $<.log $@.log
$(BUILD_TARGETS_TRACE_FST): build/run_%_trace_fst_0.1/default-verilator/$(TOP_EXECUTABLE_NAME): generated/out/%.sv generated/out/%.sv.log run_%_trace_fst.core
	rm -f fusesoc.conf
	fusesoc library add run_$*_trace_fst .
	fusesoc run --build run_$*_trace_fst
	cp $<.log $@.log

#
# Recompile, if only the Verilator C++ testbench has changed
#

RECOMPILE_TARGETS_NOTRACE=$(patsubst %,recompile_%_notrace, $(TARGET_NAMES))
RECOMPILE_TARGETS_TRACE=$(patsubst %,recompile_%_trace, $(TARGET_NAMES))
RECOMPILE_TARGETS_TRACE_FST=$(patsubst %,recompile_%_trace_fst, $(TARGET_NAMES))
RECOMPILE_TARGETS = $(RECOMPILE_TARGETS_NOTRACE) $(RECOMPILE_TARGETS_TRACE) $(RECOMPILE_TARGETS_TRACE_FST)

.PHONY: $(RECOMPILE_TARGETS)
$(RECOMPILE_TARGETS): recompile_%: build/run_%_0.1
	rm -f $</default-verilator/toplevel.o
	rm -f $</default-verilator/$(TOP_EXECUTABLE_NAME)
	rm -rf $</src/run_$*_0.1/dv
	rm -rf ./build/dv
	cp -r dv $</src/run_$*_0.1
	cp -r $(CASCADE_DESIGN_PROCESSING_ROOT)/common/dv ./build
	make -C $</default-verilator


#
# Rerun, while making sure that nothing will be recompiled because of this call.
#

RERUN_TARGETS_NOTRACE=$(patsubst %,rerun_%_notrace, $(TARGET_NAMES))
RERUN_TARGETS_TRACE=$(patsubst %,rerun_%_trace, $(TARGET_NAMES))
RERUN_TARGETS_TRACE_FST=$(patsubst %,rerun_%_trace_fst, $(TARGET_NAMES))
RERUN_TARGETS = $(RERUN_TARGETS_NOTRACE) $(RERUN_TARGETS_TRACE) $(RERUN_TARGETS_TRACE_FST)

.PHONY: $(RERUN_TARGETS)
$(RERUN_TARGETS_TRACE) $(RERUN_TARGETS_TRACE_FST): | traces
$(RERUN_TARGETS): rerun_%: build/run_%_0.1/
	$</default-verilator/$(TOP_EXECUTABLE_NAME)

#
# Run, potentially after compiling.
#

RUN_TARGETS_NOTRACE=$(patsubst %,run_%_notrace, $(TARGET_NAMES))
RUN_TARGETS_TRACE=$(patsubst %,run_%_trace, $(TARGET_NAMES))
RUN_TARGETS_TRACE_FST=$(patsubst %,run_%_trace_fst, $(TARGET_NAMES))
RUN_TARGETS = $(RUN_TARGETS_NOTRACE) $(RUN_TARGETS_TRACE) $(RUN_TARGETS_TRACE_FST)

$(RUN_TARGETS_TRACE) $(RUN_TARGETS_TRACE_FST): | traces
$(RUN_TARGETS): run_%: ./build/run_%_0.1/default-verilator/$(TOP_EXECUTABLE_NAME)
	cd build/run_$*_0.1/default-verilator && ./$(TOP_EXECUTABLE_NAME)

#
# Modelsim
#

CASCADE_DIR := ${shell dirname ${shell pwd}}/cascade
MODELSIM_PATH_TO_BUILD_TCL = $(CASCADE_DESIGN_PROCESSING_ROOT)/common/modelsim/modelsim_build.tcl

include $(CASCADE_DESIGN_PROCESSING_ROOT)/common/modelsim.mk

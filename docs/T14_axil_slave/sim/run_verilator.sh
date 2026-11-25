#!/bin/bash
# Usage: ./run_verilator.sh <step> [-DNAME=value ...]   Verilator 5.x (step 5 adds the SVA checker)
set -e
cd "$(dirname "$0")"
STEP=$1; shift
R=../rtl; T=../tb
case "$STEP" in
  4) TOP=tb_step4_axil;        TB=$T/tb_step4_axil.v;;
  5) TOP=tb_step5_axil_random; TB="$T/axil_sva.sv $T/tb_step5_axil_random.v";;
  *) echo "usage: $0 4|5 [defines]"; exit 1;;
esac
DEFS=""
for a in "$@"; do DEFS="$DEFS ${a/-D/+define+}"; done
verilator --binary --timing --assert --trace -Wno-fatal -Wno-lint -Wno-style \
  --timescale 1ns/1ps -I$T +define+SVA $DEFS --top-module $TOP -Mdir obj_$TOP \
  $R/sync_2ff.v $R/wstrb_merge.v $R/free_counter.v $R/periph_regs.v $R/axil_slave.v $TB \
  > build_$TOP.log 2>&1 || { cat build_$TOP.log; exit 1; }
./obj_$TOP/V$TOP

#!/bin/bash
# Usage: ./run_verilator.sh <step> [-DWS=2 ...]   Verilator 5.x (adds the SVA checker in step 5)
set -e
cd "$(dirname "$0")"
STEP=$1; shift
R=../rtl; T=../tb
case "$STEP" in
  4) TOP=tb_step4_apb_gpio;        TB=$T/tb_step4_apb_gpio.v;;
  5) TOP=tb_step5_apb_gpio_random; TB="$T/apb_sva.sv $T/tb_step5_apb_gpio_random.v";;
  *) echo "usage: $0 4|5 [defines]"; exit 1;;
esac
DEFS=""
for a in "$@"; do DEFS="$DEFS ${a/-D/+define+}"; done
verilator --binary --timing --assert --trace -Wno-fatal -Wno-lint -Wno-style \
  --timescale 1ns/1ps -I$T +define+SVA $DEFS --top-module $TOP -Mdir obj_$TOP \
  $R/sync_2ff.v $R/edge_detect.v $R/byte_reg.v $R/gpio_irq.v $R/apb_gpio.v $TB > build_$TOP.log 2>&1 \
  || { cat build_$TOP.log; exit 1; }
./obj_$TOP/V$TOP

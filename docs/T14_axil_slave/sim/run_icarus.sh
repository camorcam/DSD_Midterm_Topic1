#!/bin/bash
# Usage: ./run_icarus.sh <step> [-DNAME=value ...]    step = 1 2 3 4 5 6
set -e
cd "$(dirname "$0")"
STEP=$1; shift
R=../rtl; T=../tb
CORE="$R/sync_2ff.v $R/wstrb_merge.v $R/free_counter.v $R/periph_regs.v"
case "$STEP" in
  1) SRC="$R/hs_reg.v $T/tb_step1_hs_reg.v";;
  2) SRC="$CORE $T/tb_step2_regs.v";;
  3) SRC="$CORE $R/axil_slave.v $T/tb_step3_write.v";;
  4) SRC="$CORE $R/axil_slave.v $T/tb_step4_axil.v";;
  5) SRC="$CORE $R/axil_slave.v $T/tb_step5_axil_random.v";;
  6) SRC="$CORE $R/axil_slave.v $R/axil_master.v $R/axil_demo_seq.v $R/axil_system.v $T/tb_step6_system.v";;
  *) echo "usage: $0 1|2|3|4|5|6 [defines]"; exit 1;;
esac
rm -f step$STEP.vvp
iverilog -g2012 -Wall -Wno-timescale -I$T -o step$STEP.vvp $SRC "$@"
vvp -n step$STEP.vvp

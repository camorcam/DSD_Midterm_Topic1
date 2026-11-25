#!/bin/bash
# Usage: ./run_icarus.sh <step>     step = 1 2 3 4 5 6   (run from the sim/ folder)
set -e
cd "$(dirname "$0")"
STEP=$1
R=../rtl; T=../tb
case "$STEP" in
  1) SRC="$R/sync_2ff.v $R/edge_detect.v $R/rst_sync.v $R/debounce.v $T/tb_step1_basic.v";;
  2) SRC="$R/byte_reg.v $T/tb_step2_byte_reg.v";;
  3) SRC="$R/edge_detect.v $R/gpio_irq.v $T/tb_step3_gpio_irq.v";;
  4) SRC="$R/sync_2ff.v $R/edge_detect.v $R/byte_reg.v $R/gpio_irq.v $R/apb_gpio.v $T/tb_step4_apb_gpio.v";;
  5) SRC="$R/sync_2ff.v $R/edge_detect.v $R/byte_reg.v $R/gpio_irq.v $R/apb_gpio.v $T/tb_step5_apb_gpio_random.v";;
  6) SRC="$R/sync_2ff.v $R/edge_detect.v $R/byte_reg.v $R/gpio_irq.v $R/apb_gpio.v $R/apb_master.v \
          $R/gpio_demo_seq.v $R/pulse_stretch.v $R/gpio_system.v $T/tb_step6_system.v";;
  *) echo "usage: $0 1|2|3|4|5|6"; exit 1;;
esac
shift
rm -f step$STEP.vvp
iverilog -g2012 -Wall -Wno-timescale -I$T -o step$STEP.vvp $SRC "$@"
vvp -n step$STEP.vvp

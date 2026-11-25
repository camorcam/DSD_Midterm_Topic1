#!/bin/bash
# Questa / ModelSim (incl. Questa-Intel FPGA Starter Edition shipped with Quartus)
# Usage: ./run_questa.sh <step> [+define+WS=2 ...]      add -gui to open the wave window
cd "$(dirname "$0")"
STEP=$1; shift
# re-use the file lists of run_icarus.sh
SRC=$(bash -c "source <(sed -n '/^case/,/^esac/p' run_icarus.sh | sed 's/^case \"\$STEP\"/STEP=$STEP; R=..\/rtl; T=..\/tb; CORE=\"\$R\/sync_2ff.v \$R\/wstrb_merge.v \$R\/free_counter.v \$R\/periph_regs.v\"; case \"\$STEP\"/'); echo \$SRC")
TOP=$(basename $(echo $SRC | awk '{print $NF}') .v)
SVA=""; [ "$STEP" = "5" ] && SVA="$(ls ../tb/*_sva.sv) +define+SVA"
vlib work > /dev/null
vlog -sv +incdir+../tb $SVA $SRC "$@" || exit 1
vsim -c -voptargs=+acc work.$TOP -do "run -all; quit -f"

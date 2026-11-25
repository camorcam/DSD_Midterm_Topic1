#!/bin/bash
# Run tutorial steps 1–6 and retain coverage logs for the required test matrix.
set -e
cd "$(dirname "$0")"
mkdir -p ../logs

run_icarus() {
    local step=$1 log=$2
    shift 2
    if ! bash ./run_icarus.sh "$step" "$@" > "../logs/$log.log" 2>&1; then
        cat "../logs/$log.log"
        return 1
    fi
    grep -F "*** STEP $step PASS ***" "../logs/$log.log"
}

for step in 1 2 3 4; do
    run_icarus "$step" "step$step"
done
run_icarus 4 step4_ws2 -DWS=2
cp step4.vcd step4_ws2.vcd
run_icarus 4 step4

for ws in 0 1 2; do
    for seed in 1 7 12 42 2026; do
        run_icarus 5 "step5_ws${ws}_seed${seed}" "-DWS=$ws" "-DSEED=$seed"
    done
done
run_icarus 5 step5
run_icarus 6 step6

if command -v verilator > /dev/null; then
    sva_log=../logs/step5_verilator_sva.log
    bug_log=../logs/step5_verilator_bfm_bug.log
    cp step5.vcd step5_icarus.vcd
    if ! bash ./run_verilator.sh 5 -DWS=2 > "$sva_log" 2>&1; then
        cat "$sva_log"
        exit 1
    fi
    grep -F '*** STEP 5 PASS ***' "$sva_log"
    if bash ./run_verilator.sh 5 -DWS=2 -DBFM_BUG > "$bug_log" 2>&1; then
        cat "$bug_log"
        exit 1
    fi
    grep -F -m1 'APB R3: signals changed during a wait state' "$bug_log"
    cp step5_icarus.vcd step5.vcd
fi

#!/bin/bash
# Runs every step of T1 and stores the logs in ../logs   (Icarus; Verilator if installed)
cd "$(dirname "$0")"; mkdir -p ../logs
for s in 1 2 3 4 5 6; do ./run_icarus.sh $s > ../logs/step$s.log 2>&1; grep -h "\*\*\*" ../logs/step$s.log; done
./run_icarus.sh 4 -DWS=2 > ../logs/step4_ws2.log 2>&1; cp step4.vcd step4_ws2.vcd; grep -h "\*\*\*" ../logs/step4_ws2.log
./run_icarus.sh 4 > /dev/null 2>&1                        # leave the WS=0 waveform in step4.vcd
if command -v verilator > /dev/null; then
  ./run_verilator.sh 5 -DWS=2 > ../logs/step5_verilator_sva.log 2>&1; grep -h "\*\*\*" ../logs/step5_verilator_sva.log
  ./run_verilator.sh 5 -DWS=2 -DBFM_BUG > ../logs/step5_verilator_bfm_bug.log 2>&1
  grep -h -m1 "Assertion failed" ../logs/step5_verilator_bfm_bug.log
fi
./run_icarus.sh 5 > /dev/null 2>&1                        # Icarus waveform for step 5 (Verilator also writes step5.vcd)

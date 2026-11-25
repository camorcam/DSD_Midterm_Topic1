#!/bin/bash
# Runs every step of T14 and stores the logs in ../logs   (Icarus; Verilator if installed)
cd "$(dirname "$0")"; mkdir -p ../logs
for s in 1 2 3 4 5 6; do ./run_icarus.sh $s > ../logs/step$s.log 2>&1; grep -h "\*\*\*" ../logs/step$s.log; done
if command -v verilator > /dev/null; then
  ./run_verilator.sh 5 > ../logs/step5_verilator_sva.log 2>&1; grep -h "\*\*\*" ../logs/step5_verilator_sva.log
fi
./run_icarus.sh 5 > /dev/null 2>&1                        # Icarus waveform for step 5 (Verilator also writes step5.vcd)

# DSD Midterm Project Tutorials – Pilot topics T1 and T14 (student edition)

Digital System Design · Vo Minh Thanh, M.Eng · School of Electrical Engineering

| Folder | Topic |
|---|---|
| `T1_apb_gpio/` | T1 – APB GPIO peripheral with edge interrupts |
| `T14_axil_slave/` | T14 – AXI4-Lite slave peripheral (GPIO, 7-segment, counter) |

Each topic: `rtl/` design, `tb/` testbenches (one per step), `sim/` scripts, `board/` DE10-Lite and DE2-115 files.

```bash
cd T1_apb_gpio/sim
./run_icarus.sh 1          # step 1 ... 6   (Icarus Verilog 12, iverilog -g2012)
./run_verilator.sh 5       # random test + SVA checker (Verilator 5)
./run_questa.sh 5          # Questa / ModelSim-Intel
./run_all.sh               # all steps, logs in ../logs
cd ../board/de10_lite && quartus_sh -t create_project.tcl
```
Complete the TODO blocks in `rtl/` step by step. Every step must print `*** STEP n PASS ***` before you continue.

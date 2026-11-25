# Topic 1 — APB4 GPIO Controller

Topic 1 implements an AMBA APB4 GPIO peripheral with synchronized inputs, per-pin direction control and configurable edge interrupts. The tutorial simulation includes a command-driven APB master and a GPIO demo sequencer. The DE10-Standard demo is documented in the Phase 5B sections below.

## Run the tutorial simulations

The tutorial RTL and self-checking testbenches are in
[`midterm_project/`](midterm_project/). The student templates are in [`docs/`](docs/). Run steps 1–6 from the repository root
in Bash (Git Bash or WSL on Windows) with Icarus Verilog 12 on PATH.

```bash
bash midterm_project/sim/run_all.sh
```

The regression checks Step 4 with zero and two wait states and Step 5 with five
seeds at each of zero, one, and two wait states. It writes coverage tables to
`midterm_project/logs/` and VCD waveforms to `midterm_project/sim/`. With
Verilator on PATH it also runs the SVA checker and the intentional BFM protocol
violation. To run a single tutorial step:

```bash
bash midterm_project/sim/run_icarus.sh 4 -DWS=2
```

The tutorial peripheral defaults to 16 GPIO pins and accepts 0–15 wait states.
Its interrupt registers are `INT_RISE` at `0x10`, `INT_FALL` at `0x14` and
`INT_STATUS` at `0x18`. Its read-only `ID` register at `0x1C` defaults to
`0x47504901`. The architecture, register map and board instructions below
describe the existing DE10-Standard implementation for Phase 5B.


## Phase 5B architecture

- [`apb_gpio_top`](midterm_project/rtl/apb_gpio_top.v) integrates the APB address decoder, GPIO register bank, two-stage input synchronizer, and interrupt logic.
- The APB slave completes transfers with zero wait states and uses `PSTRB` for byte writes. It asserts `PSLVERR` on unmapped addresses and writes to `DATA_IN`.
- [`de10_standard_top`](midterm_project/rtl/de10_standard_top.v) maps the demo to the board clock, keys, switches, and LEDs. The demo wrapper synchronizes reset release and debounces the interrupt button.

## Phase 5B register map

Offsets are byte addresses relative to the peripheral base address. Each register is 32 bits wide.

| Offset | Register | Access | Function |
| --- | --- | --- | --- |
| `0x00` | `DATA_OUT` | RW | Output value for each GPIO pin |
| `0x04` | `DATA_IN` | RO | Synchronized GPIO input values |
| `0x08` | `DIRECTION` | RW | 0 selects input, 1 selects output |
| `0x0C` | `INT_ENABLE` | RW | Enables each pending bit's contribution to `irq` |
| `0x10` | `INT_STATUS` | W1C | Read pending bits and write ones to clear selected bits |
| `0x14` | `INT_RISE_ENABLE` | RW | Enables rising-edge detection per input pin |
| `0x18` | `INT_FALL_ENABLE` | RW | Enables falling-edge detection per input pin |

The interrupt logic records configured edges on pins set to input. Pending bits remain set until cleared or reset. `INT_ENABLE` gates the combined IRQ without affecting pending bit capture. The IRQ is the OR-reduction of `INT_STATUS & INT_ENABLE`.

## Run the DE10-Standard regression

Install Python 3 and Icarus Verilog, with `iverilog` and `vvp` available on your PATH. From the repository root, run the full regression:

```powershell
python midterm_project/scripts/run_all_tests.py
```

Run just the DE10-Standard testbench and save a waveform:

```powershell
python midterm_project/scripts/run_all_tests.py --test tb_de10_standard_top --vcd
```

The regression covers APB transfers, register access, interrupt behavior, randomized transactions with a scoreboard and protocol checker, and the FPGA demo. Logs and optional VCD waveforms are written to `midterm_project/build/regression/`.

## DE10-Standard demo

Open [`de10_standard_apb_gpio.qpf`](de10_standard_apb_gpio.qpf) in Quartus Prime with Cyclone V device support. The project targets device `5CSXFC6D6F31C6N` and uses `CLOCK_50` at 50 MHz. Check that jumper `JP3` selects 3.3 V for the switch bank before using the supplied I/O constraints. Compile the project, check the timing report, and program the generated `.sof` over JTAG.

| Resource | Demo behavior |
| --- | --- |
| `KEY[0]` | Active-low reset |
| `KEY[1]` | Active-low button mapped to GPIO input bit 8 after inversion |
| `SW[7:0]` | Switch values read through `DATA_IN` |
| `SW[9:8]` | Mapped to GPIO input bits 10 and 9 |
| `LEDR[7:0]` | Displays the GPIO output pattern |
| `LEDR[8]` | Combined interrupt request |
| `LEDR[9]` | Lights when the demo completes successfully |

Set the switches and reset the design to start the demo. The APB master writes `0x55` and then `0xAA` to the LEDs, reads the switch inputs, and waits for the debounced button press. It then reads the pending interrupt and clears it through `INT_STATUS`. The board-level sequence is covered by simulation. Quartus timing sign-off and physical board validation are pending in the Phase 5B documentation.

## Project files

| Path | Contents |
| --- | --- |
| [`midterm_project/rtl/`](midterm_project/rtl/) | Verilog core and demo wrappers |
| [`midterm_project/tb/`](midterm_project/tb/) | SystemVerilog testbenches, APB bus functional model, and scoreboard |
| [`midterm_project/sim/`](midterm_project/sim/) | Tutorial step runners and regression |
| [`midterm_project/scripts/`](midterm_project/scripts/) | Python simulation runners for the DE10-Standard implementation |
| [`midterm_project/quartus/`](midterm_project/quartus/) | Quartus pin assignments and timing constraints |
| [`midterm_project/docs/`](midterm_project/docs/) | Proposal, design plan, verification results, and board documentation |

See the [design proposal](midterm_project/docs/T1_APB_GPIO_D1_Proposal.md) for the interface specification, [Phase 4](midterm_project/docs/T1_APB_GPIO_Phase4.md) for verification coverage, and [Phase 5B](midterm_project/docs/T1_APB_GPIO_Phase5B.md) for the board setup and validation status.

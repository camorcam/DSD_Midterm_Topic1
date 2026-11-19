# APB GPIO: Phase 5B DE10-Standard Preparation

## Scope and status

The Phase 5B work that does not require Quartus or physical hardware is complete.
The project now has a DE10-Standard top-level wrapper, pin assignments, a 50 MHz
timing constraint, and a self-checking board-level simulation.

Phase 5 is not complete because synthesis, fitting, timing sign-off, programming-file
generation, and hardware validation require Quartus and the DE10-Standard board.

## Board mapping

| Board resource | Design function |
|---|---|
| `CLOCK_50` | 50 MHz APB and GPIO clock |
| `KEY[0]` | Active-low asynchronous reset |
| `KEY[1]` | Active-low interrupt test button, inverted to GPIO input bit 8 |
| `KEY[3:2]` | Reserved |
| `SW[7:0]` | GPIO input bits `[7:0]`, captured by the demo read |
| `SW[9:8]` | GPIO input bits `[10:9]` |
| `LEDR[7:0]` | GPIO output bits `[7:0]` |
| `LEDR[8]` | GPIO interrupt request |
| `LEDR[9]` | Successful demo completion (`demo_done` without `demo_error`) |

The wrapper is `rtl/de10_standard_top.v`. It preserves the 32-bit GPIO core and only
maps the resources available for the demonstration. The default button debounce
interval is 500,000 cycles, or 10 ms at 50 MHz.

The switch bank voltage follows board jumper `JP3`. Set `JP3` to 3.3 V before using
the supplied `3.3-V LVTTL` switch constraints.

## Quartus preparation

- `quartus/de10_standard_apb_gpio.qsf` selects device `5CSXFC6D6F31C6N`, lists all
  RTL sources, and assigns `CLOCK_50`, `KEY`, `SW`, and `LEDR` pins from the board
  manual.
- `quartus/de10_standard_apb_gpio.sdc` defines the 20 ns clock and excludes the
  asynchronous board inputs from synchronous external arrival timing.

The files intentionally do not lock the project to a Quartus release. They must be
loaded and validated with a locally installed Quartus version that supports Cyclone V.

## Offline verification

`tb/tb_de10_standard_top.sv` verifies active-low reset and button polarity, switch
mapping, the `0xAA` LED pattern, interrupt capture and clear, and successful completion.
Run it with:

```bash
python3 scripts/run_all_tests.py --test tb_de10_standard_top --vcd
```

## Remaining Phase 5 work

- Confirm the physical board revision and inspect `JP3` before programming.
- Select and install a Quartus Prime release with Cyclone V device support.
- Open the QSF project and resolve any tool-version or board-revision warnings.
- Run Analysis & Synthesis and inspect warnings/resource utilization.
- Run Fitter and verify every location and I/O-standard assignment.
- Run TimeQuest and achieve timing closure for `CLOCK_50` with no unconstrained
  relevant paths.
- Generate the `.sof` programming file.
- Connect the board through JTAG/USB-Blaster and program the FPGA.
- Validate reset, switch capture, `0x55`/`0xAA` output behavior, button interrupt,
  W1C interrupt clear, IRQ LED, and completion LED on hardware.
- Save synthesis, fitter, utilization, timing, programming, and hardware evidence for
  the Phase 5 deliverable.

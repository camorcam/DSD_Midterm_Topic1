# APB GPIO: Phase 5A Simulation-Ready FPGA Demo

## Scope and status

Phase 5A is complete. The project now includes a board-independent FPGA demonstration wrapper and a fixed APB master sequence that are fully verified in simulation without Quartus.

Phase 5 overall remains open. The target board and device are now confirmed as the
Terasic DE10-Standard and `5CSXFC6D6F31C6N`. Board-specific RTL, Quartus constraints,
synthesis, fitting, timing reports, programming files, and hardware validation belong
to Phase 5B.

## Implemented modules

- `rtl/reset_sync.v`: asynchronous reset assertion with two-cycle synchronous release.
- `rtl/button_debounce.v`: two-stage button synchronization and stable-level debounce filtering.
- `rtl/apb_master_demo.v`: fixed APB master FSM for output, input, interrupt, status-read, and W1C-clear demonstration.
- `rtl/fpga_top.v`: board-independent wrapper connecting reset conditioning, button debounce, the APB demo master, and the APB GPIO core.

The wrapper keeps physical pin assignments outside RTL. `gpio_out` and `gpio_oe` remain
separate so a Phase 5B DE10-Standard wrapper can select the physical board mapping.

## Demo sequence

After reset release, `apb_master_demo` performs:

1. Write `DIRECTION = 0x000000FF` so GPIO bits `[7:0]` are outputs.
2. Write `DATA_OUT = 0x00000055`.
3. Write `DATA_OUT = 0x000000AA`.
4. Read and capture `DATA_IN`.
5. Write `INT_RISE_ENABLE = 0x00000100` for button bit 8.
6. Write `INT_ENABLE = 0x00000100`.
7. Wait for `irq` after a debounced rising button edge.
8. Read and capture `INT_STATUS`.
9. Write `0x00000100` to `INT_STATUS` to clear the pending bit.
10. Assert `demo_done` and retain the captured values for observation.

Any APB error response latches `demo_error` without stopping the sequence.

## Verification

Phase 5A adds one self-checking test per new block:

| Test | Coverage | Result |
|---|---|---|
| `tb_reset_sync` | asynchronous assertion and two-cycle release | PASS, 4 checks |
| `tb_button_debounce` | high/low glitch rejection and stable transitions | PASS, 5 checks |
| `tb_apb_master_demo` | transaction order, payloads, captures, W1C, APB protocol | PASS, 31 checks |
| `tb_fpga_top` | full simulated LED/input/button/IRQ/clear sequence | PASS, 17 checks |

The integration test confirms that a short button pulse is rejected, a stable button press generates an interrupt, the master captures `INT_STATUS = 0x00000100`, and the W1C transaction clears `irq`.

The complete project regression, including the Phase 5B board wrapper test, also
passes: `PASS: regression (13/13 tests, 3 random seeds)`.

Run the Phase 5A subset:

```bash
python3 scripts/run_all_tests.py \
  --test tb_reset_sync \
  --test tb_button_debounce \
  --test tb_apb_master_demo \
  --test tb_fpga_top \
  --vcd
```

## Phase 5B blockers

The manual confirms a 50 MHz `CLOCK_50` input, active-low debounced keys, active-high
red LEDs, the board pin assignments, and the `5CSXFC6D6F31C6N` device. The following
work and information are still required:

- Board revision and Quartus Prime version compatible with the local environment.
- The completed offline Phase 5B preparation is documented in `T1_APB_GPIO_Phase5B.md`.
- JTAG programming connection and procedure.
- Quartus synthesis, fitting, timing analysis, `.sof` generation, and board programming.

The final debounce value must be recalculated from the real board clock and desired debounce interval. For example, a 10 ms interval at 50 MHz requires 500,000 stable cycles.

# APB GPIO: Phase 3 Directed Verification

## Scope and status

The full Phase 3 directed-verification milestone is complete. All required core functions pass block-level or integrated directed tests.

Implemented verification infrastructure:

- `tb/apb_bfm.sv`: reusable APB master tasks for reads, writes, idle cycles, SETUP control, and unselected bus activity.
- `tb/tb_apb_registers.sv`: self-checking directed tests, an independent register reference model, and a protocol monitor.
- `tb/tb_apb_gpio_top.sv`: end-to-end APB, GPIO synchronization, interrupt, W1C, and IRQ tests.
- `tb/tb_gpio_interrupt_directed.sv`: exhaustive per-pin rising, falling, both-edge, direction suppression, and event-over-clear tests.
- Individual self-checking unit tests for every RTL block.
- `scripts/run_all_tests.py`: complete RTL language check, per-test compilation, simulation, timeout handling, log capture, test selection, and optional VCD generation.

The regression passed with Icarus Verilog on 2026-11-17:

```text
PASS: tb_apb_slave_ctrl (59 checks)
PASS: tb_gpio_registers (635 checks)
PASS: tb_gpio_input_sync (7 checks)
PASS: tb_gpio_interrupt (31 checks)
PASS: tb_gpio_interrupt_directed (962 checks)
PASS: tb_apb_registers (6142 checks)
PASS: tb_apb_gpio_top (73 checks)
PASS: regression (7/7 tests)
```

## Covered behavior

- Asynchronous reset and reset during an active ACCESS indication.
- Reads and writes for all currently implemented register paths.
- All 16 byte-strobe combinations on each writable register.
- Read-only `DATA_IN` handling and byte-qualified `INT_STATUS` clear requests.
- Misaligned, unmapped, and upper-address alias rejection.
- Zero-wait response, SETUP, ACCESS, IDLE, held SETUP, and unselected activity.
- Consecutive transfers without an intervening IDLE transaction.
- All eight `PPROT` values.
- Address, direction, write data, strobes, and protection stability from SETUP to ACCESS.
- Register state preservation after rejected or inactive writes.
- Two-flip-flop synchronization latency and asynchronous reset.
- Rising-edge, falling-edge, and both-edge interrupt detection.
- Exhaustive edge-mode and collision checks across all 32 GPIO pins.
- Output-pin interrupt suppression.
- Status capture while IRQ is masked and immediate IRQ response to `INT_ENABLE`.
- W1C retention/clear behavior and new-event priority over simultaneous clear.
- End-to-end `DATA_IN`, `INT_STATUS`, `gpio_out`, `gpio_oe`, and `irq` behavior through `apb_gpio_top`.

## Phase boundary

Phase 3 uses deterministic, self-checking directed tests. Random traffic, a generalized full-core scoreboard, SystemVerilog assertions, and functional coverage remain Phase 4 work.

## Running the regression

From the repository root:

```bash
python3 scripts/run_all_tests.py --vcd
```

The command writes per-test logs and waveforms to `build/regression/` and returns a nonzero exit code for a compile error, timeout, failed check, or missing PASS summary.

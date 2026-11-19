# APB GPIO: Phase 2 Implementation

## Scope and status

Implemented:

- `rtl/apb_slave_ctrl.v`: zero-wait-state APB4 decoder, read multiplexer, access validation, and internal write request.
- `rtl/gpio_registers.v`: five RW registers, asynchronous active-low reset, byte writes, and the W1C clear request for the interrupt block.
- `rtl/gpio_input_sync.v`: 32-bit two-flip-flop input synchronizer.
- `rtl/gpio_interrupt.v`: rising/falling edge detection, W1C pending status, event-over-clear priority, and combined IRQ.
- `rtl/apb_gpio_top.v`: complete core integration and GPIO output/output-enable connections.
- One self-checking unit test per RTL block, plus APB/register and full-core directed tests.
- `scripts/run_all_tests.py`: complete RTL compilation and six-test regression with failure exit codes, logs, and optional waveforms.

The complete regression passed with Icarus Verilog on 2026-11-17: `PASS: regression (6/6 tests)`. Logs and optional waveforms are generated under `build/regression/`.

The Phase 2 exit criterion is met: all core RTL blocks compile as Verilog-2001, every block has a passing unit test, and the integrated core passes its basic simulation test.

## Implementation contract

All RTL modules use Verilog-2001. The frozen configuration uses 32-bit APB data and 32 GPIO pins. `APB_ADDR_WIDTH` defaults to 8 and must be at least 5. `apb_gpio_top` passes the shared address and GPIO width parameters to its submodules.

`apb_slave_ctrl` is combinational and does not need `PCLK` or an FSM. A compliant APB master supplies SETUP and ACCESS. `PREADY` is always 1; writes are accepted only during `PRESETn && PSEL && PENABLE && PWRITE && !PSLVERR`. An accepted request is consumed at the rising edge of `PCLK` by the register bank and the interrupt block. It is not a registered pulse delayed by one cycle.

`PRDATA` is zero outside mapped read ACCESS phases. `PSLVERR` is zero outside ACCESS and during reset. Exact full-address decoding rejects misaligned and unmapped addresses. A write to `DATA_IN` reports an error even with zero strobes. A zero-strobe write to a writable register is a valid no-operation. `PPROT` is accepted and intentionally has no effect on permissions.

| Offset | Register | Source / behavior |
|---|---|---|
| `0x00` | DATA_OUT | Register bank stores; RW; reset 0 |
| `0x04` | DATA_IN | Input synchronizer supplies data; RO |
| `0x08` | DIRECTION | Register bank stores; RW; reset 0 |
| `0x0C` | INT_ENABLE | Register bank stores; RW; reset 0 |
| `0x10` | INT_STATUS | Interrupt block supplies pending status; writes generate a clear mask |
| `0x14` | INT_RISE_ENABLE | Register bank stores; RW; reset 0 |
| `0x18` | INT_FALL_ENABLE | Register bank stores; RW; reset 0 |

## Module integration

Connect the four `write_*` outputs of `apb_slave_ctrl` directly to the corresponding inputs of `gpio_registers`. Connect the five stored register outputs back to the APB decoder's identically named read inputs.

| Signal | Width | Connection |
|---|---:|---|
| `data_out` | 32 | Register bank to decoder and top-level `gpio_out` |
| `direction` | 32 | Register bank to decoder, the interrupt block, and `gpio_oe` |
| `int_enable` | 32 | Register bank to decoder and the interrupt block IRQ mask input |
| `int_rise_enable` | 32 | Register bank to decoder and the interrupt block rising-edge configuration |
| `int_fall_enable` | 32 | Register bank to decoder and the interrupt block falling-edge configuration |
| `int_clear_mask` | 32 | Register bank to the interrupt block `clear_mask` input |
| `data_in` | 32 | Synchronized GPIO input to decoder |
| `int_status` | 32 | Interrupt pending register to decoder |
| `PCLK`, `PRESETn` | 1 each | Shared clock and asynchronous active-low reset |

`int_clear_mask` is combinational and nonzero only during a valid status-write ACCESS while reset is released. Each bit is `write_data[i] && write_strb[i/8]`. The interrupt block must sample it at the completion edge, without adding another cycle of delay, and update status as:

```verilog
int_status <= (int_status & ~clear_mask) | eligible_event;
```

This gives a new event priority over a simultaneous clear. Register bank configuration writes use nonblocking assignments, so clocked edge qualification in the interrupt block naturally uses the configuration stored before that edge. The register bank does not store, clear, or reset `INT_STATUS`; the interrupt block handles those operations.

`gpio_input_sync` resets both synchronization stages to zero. `gpio_interrupt` compares consecutive synchronized samples, suppresses events on output pins, captures status independently of `INT_ENABLE`, and generates `irq` from `int_status & int_enable`.

## Running the tests

With Icarus Verilog installed and `iverilog` and `vvp` on PATH, run the complete regression from the repository root:

```bash
python3 scripts/run_all_tests.py --vcd
```

Run one test by name when debugging a block:

```bash
python3 scripts/run_all_tests.py --test tb_gpio_interrupt --vcd
```

Generated output is ignored by Git. Each test has its own log, compiled image, and optional VCD in `build/regression/`. A mismatch calls `$fatal`; compile failures, missing PASS summaries, and timeouts return a nonzero exit code.

Phase 2 unit tests:

- `tb/tb_apb_slave_ctrl.sv`
- `tb/tb_gpio_registers.sv`
- `tb/tb_gpio_input_sync.sv`
- `tb/tb_gpio_interrupt.sv`
- `tb/tb_apb_gpio_top.sv`

`tb/tb_apb_registers.sv` remains as a focused multi-block regression for the APB decoder and register bank. Full directed verification status is documented in `docs/T1_APB_GPIO_Phase3.md`.

## Source attribution

These RTL modules, testbench, runner, and implementation notes were generated with OpenAI Codex assistance for this project. No vendor bus IP is used.

# APB GPIO: Phase 4 Advanced Verification

## Scope and status

Phase 4 is complete. The verification environment now combines deterministic unit and directed tests with constrained random traffic, a cycle-accurate full-core reference model, procedural protocol assertions, automatic coverage closure, and multi-seed regression.

Implemented infrastructure:

- `tb/gpio_scoreboard.sv`: independent cycle-accurate model for registers, byte writes, the two-stage synchronizer, edge detection, W1C status, event-over-clear priority, GPIO outputs, and IRQ.
- `tb/apb_protocol_checker.sv`: Icarus-compatible checks for SETUP-to-ACCESS ordering and APB control stability.
- `tb/tb_apb_gpio_random.sv`: randomized APB and GPIO stimulus, asynchronous reset injection, response checking, coverage counters, and deterministic coverage closure.
- `scripts/run_all_tests.py`: unit, directed, and random regression with selectable tests, transaction count, repeated seeds, logs, and optional VCD output.

Icarus Verilog does not provide the complete concurrent-assertion and covergroup feature set used by commercial simulators. This project therefore uses procedural assertions and explicit functional-coverage counters while preserving automatic failure behavior.

## Random regression

The default random regression runs 500 randomized operations for each seed:

| Seed | APB/random checks | Scoreboard checks | Protocol checks | Result |
|---:|---:|---:|---:|---|
| `1` | 427 | 16,065 | 2,562 | PASS |
| `305419896` (`0x12345678`) | 427 | 16,286 | 2,562 | PASS |
| `324508639` (`0x13579BDF`) | 427 | 16,312 | 2,562 | PASS |

Each seed covers randomized APB reads, writes, mapped and invalid addresses, byte strobes, protection attributes, GPIO transitions, interrupt configuration, status clears, and periodic asynchronous resets.

## Functional coverage

The random test records coverage explicitly and fails if closure is incomplete.

| Coverage group | Required result | Achieved |
|---|---|---|
| Seven mapped registers read | `0x7F` | `0x7F` |
| Seven mapped registers written/attempted | `0x7F` | `0x7F` |
| All 16 `PSTRB` values | `0xFFFF` | `0xFFFF` |
| All eight `PPROT` values | `0xFF` | `0xFF` |
| Rising transition on all GPIO pins | `0xFFFFFFFF` | `0xFFFFFFFF` |
| Falling transition on all GPIO pins | `0xFFFFFFFF` | `0xFFFFFFFF` |
| Rising/falling/both-edge modes | `0b111` | `0b111` |
| Valid and error responses | Both | Both |

Coverage closure is deterministic after the random section, so a seed cannot pass merely because it missed an important bin.

## Checks performed continuously

The scoreboard compares expected and actual state after every active clock edge:

- All stored configuration registers.
- Synchronized `DATA_IN`.
- Pending `INT_STATUS`.
- `gpio_out` and `gpio_oe`.
- Combined `irq`.
- APB `PRDATA`, `PREADY`, and `PSLVERR` responses.

The protocol checker verifies that every ACCESS follows SETUP and that `PADDR`, `PWRITE`, `PWDATA`, `PSTRB`, and `PPROT` remain stable across the transfer.

## Running the regression

Run all unit, directed, and random tests with the default three seeds:

```bash
python3 scripts/run_all_tests.py --vcd
```

Run only the random test with custom seeds and transaction count:

```bash
python3 scripts/run_all_tests.py \
  --test tb_apb_gpio_random \
  --seed 42 --seed 2026 \
  --transactions 1000 \
  --vcd
```

Logs, compiled simulations, and waveforms are written under `build/regression/`. The runner exits nonzero for an RTL compile error, testbench compile error, timeout, assertion failure, scoreboard mismatch, missing coverage bin, or missing PASS summary.

## Phase boundary

The DE10-Standard wrapper, timing constraints, and pin assignments are now prepared
offline in Phase 5B. Quartus synthesis, timing sign-off, board programming, hardware
validation, and SignalTap capture remain Phase 5 and Phase 6 work.

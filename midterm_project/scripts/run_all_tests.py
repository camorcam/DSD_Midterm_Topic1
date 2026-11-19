"""Compile APB GPIO RTL and run unit, directed, and random regressions."""

import argparse
from pathlib import Path
import shutil
import subprocess
import sys


ROOT = Path(__file__).resolve().parents[1]
RTL = ROOT / "rtl"
TB = ROOT / "tb"

ALL_RTL = [
    RTL / "apb_slave_ctrl.v",
    RTL / "gpio_registers.v",
    RTL / "gpio_input_sync.v",
    RTL / "gpio_interrupt.v",
    RTL / "apb_gpio_top.v",
    RTL / "reset_sync.v",
    RTL / "button_debounce.v",
    RTL / "apb_master_demo.v",
    RTL / "fpga_top.v",
    RTL / "de10_standard_top.v",
]

TESTS = {
    "tb_apb_slave_ctrl": [RTL / "apb_slave_ctrl.v", TB / "tb_apb_slave_ctrl.sv"],
    "tb_gpio_registers": [RTL / "gpio_registers.v", TB / "tb_gpio_registers.sv"],
    "tb_gpio_input_sync": [RTL / "gpio_input_sync.v", TB / "tb_gpio_input_sync.sv"],
    "tb_gpio_interrupt": [RTL / "gpio_interrupt.v", TB / "tb_gpio_interrupt.sv"],
    "tb_gpio_interrupt_directed": [
        RTL / "gpio_interrupt.v",
        TB / "tb_gpio_interrupt_directed.sv",
    ],
    "tb_apb_registers": [
        RTL / "apb_slave_ctrl.v",
        RTL / "gpio_registers.v",
        TB / "apb_bfm.sv",
        TB / "tb_apb_registers.sv",
    ],
    "tb_apb_gpio_top": [*ALL_RTL, TB / "apb_bfm.sv", TB / "tb_apb_gpio_top.sv"],
    "tb_apb_gpio_random": [
        *ALL_RTL,
        TB / "apb_bfm.sv",
        TB / "gpio_scoreboard.sv",
        TB / "apb_protocol_checker.sv",
        TB / "tb_apb_gpio_random.sv",
    ],
    "tb_reset_sync": [RTL / "reset_sync.v", TB / "tb_reset_sync.sv"],
    "tb_button_debounce": [
        RTL / "button_debounce.v",
        TB / "tb_button_debounce.sv",
    ],
    "tb_apb_master_demo": [
        RTL / "apb_master_demo.v",
        TB / "apb_protocol_checker.sv",
        TB / "tb_apb_master_demo.sv",
    ],
    "tb_fpga_top": [*ALL_RTL, TB / "tb_fpga_top.sv"],
    "tb_de10_standard_top": [*ALL_RTL, TB / "tb_de10_standard_top.sv"],
}


def resolve_tool(requested, fallback=None):
    resolved = shutil.which(requested)
    if resolved is None and fallback is not None:
        resolved = str(fallback) if fallback.is_file() else None
    return str(Path(resolved).resolve()) if resolved else None


def run_command(command, cwd, log):
    log.write(f"Command: {command!r}\n")
    try:
        result = subprocess.run(
            command, cwd=cwd, text=True, capture_output=True,
            timeout=60, check=False,
        )
    except (OSError, subprocess.TimeoutExpired) as error:
        log.write(f"FAIL: {error}\n")
        print(f"FAIL: {error}", file=sys.stderr)
        return None
    output = result.stdout + result.stderr
    log.write(output)
    print(output, end="")
    if result.returncode:
        print(f"FAIL: exit code {result.returncode}", file=sys.stderr)
        return None
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--iverilog", default="iverilog", help="Icarus compiler path")
    parser.add_argument("--vvp", default=None, help="Icarus runtime path")
    parser.add_argument("--vcd", action="store_true", help="Save one VCD per test")
    parser.add_argument("--test", choices=TESTS, action="append",
                        help="Run only the selected test; may be repeated")
    parser.add_argument("--seed", type=int, action="append",
                        help="Random-test seed; may be repeated")
    parser.add_argument("--transactions", type=int, default=500,
                        help="Random operations per seed (default: 500)")
    args = parser.parse_args()

    compiler = resolve_tool(args.iverilog)
    if compiler is None:
        parser.exit(2, "Icarus Verilog not found. Supply --iverilog or update PATH.\n")
    sibling = Path(compiler).with_name("vvp.exe" if sys.platform == "win32" else "vvp")
    runtime = resolve_tool(args.vvp or "vvp", sibling if args.vvp is None else None)
    if runtime is None:
        parser.exit(2, "Icarus runtime not found. Supply --vvp.\n")

    build = ROOT / "build" / "regression"
    build.mkdir(parents=True, exist_ok=True)
    selected = args.test or list(TESTS)

    compile_log_path = build / "rtl_compile.log"
    with compile_log_path.open("w", encoding="utf-8") as compile_log:
        result = run_command(
            [compiler, "-g2001", "-Wall", "-tnull", *map(str, ALL_RTL)],
            build,
            compile_log,
        )
        if result is None:
            print(f"FAIL: complete RTL compile; see {compile_log_path}", file=sys.stderr)
            return 1

    passed = 0
    random_runs = 0
    random_seeds = args.seed or [1, 305419896, 324508639]
    for test_name in selected:
        simulation = build / f"{test_name}.vvp"
        log_path = build / f"{test_name}.log"
        with log_path.open("w", encoding="utf-8") as log:
            compile_result = run_command(
                [compiler, "-g2012", "-Wall", "-s", test_name,
                 "-o", str(simulation), *map(str, TESTS[test_name])],
                build,
                log,
            )
            if compile_result is None:
                print(f"FAIL: {test_name} compile; see {log_path}", file=sys.stderr)
                return 1
            seeds = random_seeds if test_name == "tb_apb_gpio_random" else [None]
            for seed in seeds:
                plusargs = ["+vcd"] if args.vcd else []
                if seed is not None:
                    plusargs.extend([f"+SEED={seed}",
                                     f"+TRANSACTIONS={args.transactions}"])
                run_result = run_command(
                    [runtime, str(simulation), *plusargs],
                    build,
                    log,
                )
                if run_result is None:
                    print(f"FAIL: {test_name} simulation; see {log_path}",
                          file=sys.stderr)
                    return 1
                if f"PASS: {test_name} (" not in run_result.stdout:
                    log.write("FAIL: testbench did not report its PASS summary\n")
                    print(f"FAIL: {test_name} did not report PASS; see {log_path}",
                          file=sys.stderr)
                    return 1
                if seed is not None:
                    random_runs += 1
        passed += 1

    suffix = f", {random_runs} random seeds" if random_runs else ""
    print(f"PASS: regression ({passed}/{len(selected)} tests{suffix})")
    print(f"Logs: {build}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

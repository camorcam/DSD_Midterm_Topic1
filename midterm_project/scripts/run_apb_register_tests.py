"""Compile Verilog-2001 RTL and run the APB register self-checking SystemVerilog testbench."""

import argparse
from pathlib import Path
import shutil
import subprocess
import sys


ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--iverilog", default="iverilog", help="Icarus compiler path")
    parser.add_argument("--vvp", default=None, help="Icarus runtime path")
    parser.add_argument("--vcd", action="store_true", help="Save a waveform in build/apb_registers")
    args = parser.parse_args()
    compiler = shutil.which(args.iverilog)
    if compiler is None:
        parser.exit(2, "Icarus Verilog not found. Put iverilog and vvp on PATH or use --iverilog and --vvp.\n")
    runtime = shutil.which(args.vvp) if args.vvp else shutil.which("vvp")
    if runtime is None and args.vvp is None:
        sibling = Path(compiler).with_name("vvp.exe" if sys.platform == "win32" else "vvp")
        if sibling.is_file():
            runtime = str(sibling)
    if runtime is None:
        parser.exit(2, "Icarus runtime not found. Supply --vvp.\n")
    compiler = str(Path(compiler).resolve())
    runtime = str(Path(runtime).resolve())

    build = ROOT / "build" / "apb_registers"
    build.mkdir(parents=True, exist_ok=True)
    rtl = [str(ROOT / "rtl" / name) for name in ("apb_slave_ctrl.v", "gpio_registers.v")]
    testbench = [str(ROOT / "tb" / name) for name in
                 ("apb_bfm.sv", "tb_apb_registers.sv")]
    simulation = build / "apb_registers.vvp"
    commands = [
        [compiler, "-g2001", "-Wall", "-tnull", *rtl],
        [compiler, "-g2012", "-Wall", "-s", "tb_apb_registers", "-o", str(simulation),
         *rtl, *testbench],
        [runtime, str(simulation), *(["+vcd"] if args.vcd else [])],
    ]
    with (build / "test.log").open("w", encoding="utf-8") as log:
        for command in commands:
            log.write(f"Command: {command!r}\n")
            try:
                result = subprocess.run(command, cwd=build, text=True, capture_output=True,
                                        timeout=60, check=False)
            except (OSError, subprocess.TimeoutExpired) as error:
                log.write(f"FAIL: {error}\n")
                print(f"FAIL: {error}", file=sys.stderr)
                return 1
            output = result.stdout + result.stderr
            log.write(output)
            print(output, end="")
            if result.returncode:
                print(f"FAIL: exit code {result.returncode}; see {build / 'test.log'}", file=sys.stderr)
                return 1
        if "PASS: tb_apb_registers (" not in result.stdout:
            log.write("FAIL: testbench did not report completion\n")
            print("FAIL: testbench did not report completion", file=sys.stderr)
            return 1
    print(f"Log: {build / 'test.log'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

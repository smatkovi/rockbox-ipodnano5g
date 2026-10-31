#!/usr/bin/env python3
"""Compile and run a bounded ASCII tail-byte sweep of the N82 QEMU rehost."""

from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parents[5]
OUT = Path(__file__).resolve().parent
SRC = ROOT / "utils/ipodnano5g/analysis/evidence/xml-heap-2026-10-29/OSOS_iPodSettings_shared_heap_rehost_20261030.S"
LD = ROOT / "utils/ipodnano5g/analysis/evidence/xml-heap-2026-10-29/OSOS_iPodSettings_shared_heap_fullrange_rehost_20261030.ld"
ALPHABET = "09ABaz_-."
HEAP_BASE = "0x08e54e4c"
HEAP_BYTES = "0x02d51094"
ARENA_BYTES = "0x031ab000"


def run_case(first: str, second: str) -> dict[str, str]:
    tag = f"{ord(first):02x}_{ord(second):02x}"
    name_tail4 = 0x4141 | (ord(first) << 16) | (ord(second) << 24)
    expected_header = ord(first) | (ord(second) << 8)
    with tempfile.TemporaryDirectory(prefix=f"tail-{tag}-", dir=OUT) as build_dir:
        elf = Path(build_dir) / "probe.elf"
        build = subprocess.run(
            [
                "arm-none-eabi-gcc", "-nostdlib", "-static", "-fno-pie", "-no-pie",
                "-march=armv6", "-marm",
                f"-DNAME_LEN=82", f"-DNAME_TAIL4=0x{name_tail4:08x}",
                f"-DEXPECTED_HEADER_WORD=0x{expected_header:04x}",
                "-DEXPECTED_FOLLOWUP_PTR=0x0bb636fc",
                f"-DHEAP_BASE={HEAP_BASE}", f"-DHEAP_BYTES={HEAP_BYTES}",
                f"-DARENA_BYTES={ARENA_BYTES}", "-DLOADER_ROOT",
                "-DMODEL_ROOT_FIRST_CALLBACK", "-DPREALLOC_APP_LAYOUT",
                "-DMODEL_DOCUMENT_CLEANUP", "-DMODEL_STREAM_SLOT",
                f"-Wl,-T,{LD}", "-Wl,-e,_start", "-o", str(elf), str(SRC),
            ],
            cwd=ROOT,
            capture_output=True,
            text=True,
            timeout=30,
        )
        if build.returncode != 0:
            category = "BUILD_FAILURE"
            stdout = ""
            stderr = build.stderr
            rc = build.returncode
        else:
            try:
                run = subprocess.run(
                    ["prlimit", "--core=0", "--", "qemu-arm", "-cpu", "arm1176", str(elf)],
                    cwd=ROOT,
                    capture_output=True,
                    text=True,
                    timeout=10,
                )
                stdout, stderr, rc = run.stdout, run.stderr, run.returncode
                if rc == 0:
                    category = "PASS"
                elif "uncaught target signal 11" in stderr or rc == 139:
                    category = "SIGSEGV"
                elif stdout.startswith("FAIL:"):
                    category = "HARNESS_ASSERT"
                else:
                    category = "OTHER"
            except subprocess.TimeoutExpired as exc:
                stdout = exc.stdout.decode(errors="replace") if isinstance(exc.stdout, bytes) else (exc.stdout or "")
                stderr = exc.stderr.decode(errors="replace") if isinstance(exc.stderr, bytes) else (exc.stderr or "")
                rc = "TIMEOUT"
                category = "TIMEOUT"

        log = OUT / f"tail_{tag}.run.log"
        log.write_text(
            f"tail={first}{second} bytes=0x{ord(first):02x},0x{ord(second):02x}\n"
            f"name_tail4=0x{name_tail4:08x} expected_header=0x{expected_header:04x}\n"
            f"category={category} exit={rc}\n"
            f"--- stdout ---\n{stdout}"
            f"--- stderr ---\n{stderr}",
            encoding="utf-8",
        )
        return {
            "tail": first + second,
            "bytes": f"{ord(first):02x}{ord(second):02x}",
            "name_tail4": f"{name_tail4:08x}",
            "expected_header": f"{expected_header:04x}",
            "category": category,
            "exit": str(rc),
            "log": log.name,
        }


def main() -> None:
    cases = [(a, b) for a in ALPHABET for b in ALPHABET]
    results: list[dict[str, str]] = []
    with ThreadPoolExecutor(max_workers=8) as pool:
        futures = [pool.submit(run_case, a, b) for a, b in cases]
        for future in as_completed(futures):
            results.append(future.result())
    results.sort(key=lambda row: row["bytes"])
    out = OUT / "results.tsv"
    columns = ("tail", "bytes", "name_tail4", "expected_header", "category", "exit", "log")
    out.write_text(
        "\t".join(columns) + "\n" + "".join("\t".join(row[c] for c in columns) + "\n" for row in results),
        encoding="utf-8",
    )
    counts: dict[str, int] = {}
    for row in results:
        counts[row["category"]] = counts.get(row["category"], 0) + 1
    (OUT / "summary.txt").write_text(
        f"cases={len(results)} alphabet={ALPHABET!r} workers=8\n"
        + "\n".join(f"{key}={value}" for key, value in sorted(counts.items()))
        + "\n",
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Compare later original-allocator results for the eight passing N82 tails."""

from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parents[5]
OUT = Path(__file__).resolve().parent
SRC = OUT / "OSOS_iPodSettings_postalloc_sweep_rehost.S"
LD = ROOT / "utils/ipodnano5g/analysis/evidence/xml-heap-2026-10-29/OSOS_iPodSettings_shared_heap_fullrange_rehost_20261030.ld"
TAILS = ("0-", "00", "09", "0A", "0B", "0_", "0a", "0z")


def run_case(tail: str) -> dict[str, str]:
    first, second = tail
    tag = f"{ord(first):02x}_{ord(second):02x}"
    name_tail4 = 0x4141 | (ord(first) << 16) | (ord(second) << 24)
    expected_header = ord(first) | (ord(second) << 8)
    with tempfile.TemporaryDirectory(prefix=f"postalloc-{tag}-", dir=OUT) as build_dir:
        elf = Path(build_dir) / "probe.elf"
        build = subprocess.run(
            [
                "arm-none-eabi-gcc", "-nostdlib", "-static", "-fno-pie", "-no-pie",
                "-march=armv6", "-marm", "-DNAME_LEN=82",
                f"-DNAME_TAIL4=0x{name_tail4:08x}",
                f"-DEXPECTED_HEADER_WORD=0x{expected_header:04x}",
                "-DEXPECTED_FOLLOWUP_PTR=0x0bb636fc",
                "-DHEAP_BASE=0x08e54e4c", "-DHEAP_BYTES=0x02d51094",
                "-DARENA_BYTES=0x031ab000", "-DLOADER_ROOT",
                "-DMODEL_ROOT_FIRST_CALLBACK", "-DPREALLOC_APP_LAYOUT",
                "-DMODEL_DOCUMENT_CLEANUP", "-DMODEL_STREAM_SLOT",
                "-DMODEL_POSTALLOC_SWEEP", f"-Wl,-T,{LD}", "-Wl,-e,_start",
                "-o", str(elf), str(SRC),
            ],
            cwd=ROOT,
            capture_output=True,
            text=True,
            timeout=30,
        )
        if build.returncode != 0:
            stdout, stderr, rc, category = "", build.stderr, build.returncode, "BUILD_FAILURE"
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
                else:
                    category = "OTHER"
            except subprocess.TimeoutExpired as exc:
                stdout = exc.stdout.decode(errors="replace") if isinstance(exc.stdout, bytes) else (exc.stdout or "")
                stderr = exc.stderr.decode(errors="replace") if isinstance(exc.stderr, bytes) else (exc.stderr or "")
                rc, category = "TIMEOUT", "TIMEOUT"

        log = OUT / f"postalloc_{tag}.run.log"
        log.write_text(
            f"tail={tail} name_tail4=0x{name_tail4:08x} expected_header=0x{expected_header:04x}\n"
            f"category={category} exit={rc}\n--- stdout ---\n{stdout}--- stderr ---\n{stderr}",
            encoding="utf-8",
        )
        return {"tail": tail, "bytes": tag, "category": category, "exit": str(rc), "log": log.name}


def main() -> None:
    rows: list[dict[str, str]] = []
    with ThreadPoolExecutor(max_workers=8) as pool:
        futures = [pool.submit(run_case, tail) for tail in TAILS]
        for future in as_completed(futures):
            rows.append(future.result())
    rows.sort(key=lambda row: row["tail"])
    columns = ("tail", "bytes", "category", "exit", "log")
    (OUT / "postalloc_results.tsv").write_text(
        "\t".join(columns) + "\n" + "".join("\t".join(row[col] for col in columns) + "\n" for row in rows),
        encoding="utf-8",
    )
    counts: dict[str, int] = {}
    for row in rows:
        counts[row["category"]] = counts.get(row["category"], 0) + 1
    (OUT / "postalloc_summary.txt").write_text(
        f"cases={len(rows)} sizes=10,20,40,50,80,100,200,400,1000 workers=8\n"
        + "\n".join(f"{key}={value}" for key, value in sorted(counts.items()))
        + "\n",
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()

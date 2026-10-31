#!/bin/sh
set +e
ulimit -c 0
qemu-arm -cpu arm1176 -d in_asm,cpu \
  -D utils/ipodnano5g/analysis/evidence/xml-heap-qname-sweep-2026-10-31/N82_tail_BB.trace.log \
  utils/ipodnano5g/analysis/evidence/xml-heap-qname-sweep-2026-10-31/N82_tail_BB.elf \
  > utils/ipodnano5g/analysis/evidence/xml-heap-qname-sweep-2026-10-31/N82_tail_BB.run.log 2>&1
qemu_status=$?
printf '\nqemu_exit=%s\n' "$qemu_status" \
  >> utils/ipodnano5g/analysis/evidence/xml-heap-qname-sweep-2026-10-31/N82_tail_BB.run.log
exit 0

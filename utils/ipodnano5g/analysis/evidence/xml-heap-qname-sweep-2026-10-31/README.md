# N82 QName Endbyte-Varianten

ARM1176 Usermode-QEMU Rehost des gemeinsamen iPodSettings-Parser-/Heaptests.
Alle Läufe sind offline. Der Quellcode und der Linkerentwurf liegen im
Nachbarverzeichnis `../xml-heap-2026-10-29/`.

## Getestete Namen und Ergebnisse

| Variante | QName | Erwartetes Nachbarwort | Ergebnis |
| --- | --- | ---: | --- |
| `N82_tail_00` | `A*78 + "0000"` | `0x3030` | Exit 0, `PASS`; beide Callback-Aufrufe, Original-Freecode, Dokument-Cleanup und zusätzlicher Originalallocator-Aufruf kehren zurück. Folgezeiger `0x0bb63bdc`. |
| `N82_tail_00_streamslot_pass` | `A*78 + "0000"` | `0x3030` | Exit 0, `PASS`; zusätzlich Original-Hilfsvektor `FUN_0822491c`/`FUN_08281cf4`. Folgezeiger `0x0bb636fc`. |
| `N82_tail_00_streamslot` | `A*78 + "0000"` | `0x3030` | Kein Fault; Exit 1 nur wegen alter Folgezeiger-Assertion (`0x0bb63bdc` statt `0x0bb636fc`). Die getrennte `_pass`-Variante aktualisiert die Erwartung. |
| `N82_midpatch_B` | `A*40 + "BAAA" + A*38` | `0x4141` | Exit 139 im Original-Freiliste-Unlink: Knoten `0x0bb63aa4`, Vorgängerpointer `1`; der nächste Store zielt auf Adresse `0x9`. |
| `N82_tail_BB` | `A*80 + "BB"` | `0x4242` | Exit 139 beim Original-Freepfad: bereits der Knotenparameter `r1=0xca74f90b` ist ungültig. |

Alle Zeichen sind im untersuchten XML-Namenslexer zulässige ASCII-Namensbytes.
Die Länge ist in allen drei Fällen 82. Die erfolgreiche Variante zeigt, dass
das zuvor bei `A*82` beobachtete Unlink-Fault nicht für jeden gleich langen
QName auftritt. Sie belegt keinen kontrollierten PC und keine Gerätewirkung.
Die beiden Fehlertraces zeigen unterschiedliche Ursachen: einmal ein
ungültiges Linkfeld eines gültigen Knotens, einmal einen ungültigen
Knotenpointer. Keiner belegt einen frei gewählten Zielwert in einem echten
OSOS-Objekt.

## Reproduktion

Aus dem Repository-Stammverzeichnis:

```sh
arm-none-eabi-gcc -nostdlib -static -fno-pie -no-pie -march=armv6 -marm \
  -DNAME_LEN=82 -DNAME_TAIL4=0x30303030 \
  -DEXPECTED_HEADER_WORD=0x3030 -DEXPECTED_FOLLOWUP_PTR=0x0bb63bdc \
  -DHEAP_BASE=0x08e54e4c -DHEAP_BYTES=0x02d51094 -DARENA_BYTES=0x031ab000 \
  -DLOADER_ROOT -DMODEL_ROOT_FIRST_CALLBACK -DPREALLOC_APP_LAYOUT \
  -DMODEL_DOCUMENT_CLEANUP \
  -Wl,-T,utils/ipodnano5g/analysis/evidence/xml-heap-2026-10-29/OSOS_iPodSettings_shared_heap_fullrange_rehost_20261030.ld \
  -Wl,-e,_start \
  -o utils/ipodnano5g/analysis/evidence/xml-heap-qname-sweep-2026-10-31/N82_tail_00.elf \
  utils/ipodnano5g/analysis/evidence/xml-heap-2026-10-29/OSOS_iPodSettings_shared_heap_rehost_20261030.S

sh utils/ipodnano5g/analysis/evidence/xml-heap-qname-sweep-2026-10-31/run_N82_tail_00.sh
```

Für die Variante mit Stream-Hilfsvektor ergänze `-DMODEL_STREAM_SLOT` und
verwende `-DEXPECTED_FOLLOWUP_PTR=0x0bb636fc`; der zugehörige Runner ist
`run_N82_tail_00_streamslot_pass.sh`.

For the other ELFs, replace `-DNAME_TAIL4=0x30303030` and
`-DEXPECTED_HEADER_WORD=0x3030` respectively with:

- `N82_midpatch_B`: `-DNAME_MIDPATCH_AT=40 -DNAME_MIDPATCH4=0x41414142 -DEXPECTED_HEADER_WORD=0x4141`
- `N82_tail_BB`: `-DNAME_TAIL4=0x42424141 -DEXPECTED_HEADER_WORD=0x4242`

The runner scripts invoke `qemu-arm -cpu arm1176 -d in_asm,cpu` and preserve
the stdout/status and instruction/register trace. The compiler may warn that
the host Rehost ELF has an RWX load segment; this is a property of the local
test image.

## Grenzen

Der synthetische Heapmanager, die Startup-Vorbelegung und die Registry sind
vorgegeben. Der Harness ruft die beiden dokumentierten Callbackpaare direkt
auf und führt Dokument-Cleanup aus, aber nicht den echten XML-Loader
`FUN_08059ab0`, dessen VFS-Open/Read, vollständigen Treewalk oder den
Streamcleanup `FUN_081d0ff0`/`FUN_08191cdc`. `MODEL_STREAM_SLOT` bildet nur
den Hilfsvektoraufbau/-destruktor nach. Kein Dateisystem auf dem Gerät wurde
verändert.

`SHA256SUMS` deckt diese README sowie die drei ELFs, Runlogs, Traces und
Runner-Skripte ab.

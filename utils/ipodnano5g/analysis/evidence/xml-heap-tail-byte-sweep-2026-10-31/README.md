# iPodSettings N82 QName-Tailbyte-Matrix

Stand: 31.10.2026. 81 Offline-Läufe mit ARM1176-Usermode-QEMU und dem
vorhandenen Originalparser-/Heap-Rehost. Je Lauf wurde nur das letzte
ASCII-Bytepaar des gleich langen QNames verändert. Der synthetische Heap und
die übrigen Laufparameter blieben konstant.

## Resultat

Alphabet: `09ABaz_-.` (9 × 9 Paare).

- `PASS=8`: `0-`, `00`, `09`, `0A`, `0B`, `0_`, `0a`, `0z`.
- `SIGSEGV=64`: QEMU meldet einen Gast-SIGSEGV, bevor der Rehost vollständig
  endet.
- `OTHER=9`: alle Paare mit erster Überlaufbyte `.`, Exit 1 an der
  Harness-Assertion `callback did not alter adjacent size word`.

Alle acht `PASS`-Läufe melden den Folgezeiger `0x0bb636fc`. Das überwachte
Nachbarwort und einzelne Allocatorzähler variieren mit den Eingabebytes.
Die Ergebnisse betreffen ausschließlich dieses synthetische Rehostlayout;
sie belegen keine Speicherwirkung auf dem iPod.

## Dateien und Reproduktion

- `run_tail_byte_sweep.py` baut jede Variante separat mit
  `arm-none-eabi-gcc` und startet sie mit `qemu-arm -cpu arm1176`.
- `results.tsv` ordnet alle Varianten, Exitcodes und Runlogs zu.
- `summary.txt` enthält die Kategorien.
- `tail_*.run.log` enthält stdout/stderr pro Eingabepaar.
- `OSOS_iPodSettings_postalloc_sweep_rehost.S` fügt nach dem bisherigen
  `0x50`-Folgeallocator weitere originale Allokationen ein.
- `run_postalloc_matrix.py`, `postalloc_results.tsv`,
  `postalloc_summary.txt` und `postalloc_*.run.log` enthalten die acht
  Folgeallokationsläufe für die acht vollständig erfolgreichen QName-Enden.

In allen acht Fällen liefern Größen bis `0x200` dieselben Pointer. Bei
`0x400` variieren die Rückgaben von `0x0bb65ef4` (`0-`) bis `0x0bb6abf4`
(`0z`), also über `0x4d00` Byte im Modell. Die Rückgaben bei `0x1000` folgen
derselben Verschiebung. Das zeigt Heapformung für größere Anforderungen im
Rehost. Diese zusätzlichen Größen wurden vom Harness vorgegeben; es wurde
nicht nachgewiesen, dass der echte MainApp-Aufrufer sie nach dem Parser
anfordert. Der echte äußere Stream-Cleanup bleibt ebenfalls unmodelliert.

Das Skript nutzt acht Buildworker. Temporäre ELFs werden jeweils im
Evidenzverzeichnis erzeugt und nach dem zugehörigen QEMU-Lauf entfernt; die
Eingaben, Resultate und vollständigen stdout/stderr-Logs bleiben dauerhaft
hier abgelegt. Die ELFs des vorherigen Einzeltests bleiben separat unter
`../xml-heap-qname-sweep-2026-10-31/` erhalten.

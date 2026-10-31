# iPodSettings N82: Matrix der letzten QName-Bytes

Stand: 31.10.2026. Offline ARM1176-QEMU mit dem Originalparser-/Heap-Rehost.
Kein Geräte-, USB-, DFU-, NAND-, NOR- oder Firmwarezugriff.

## Ergebnis

Ich habe die letzten beiden Bytes des 82-Zeichen-QNames für alle 81 Paare aus
`09ABaz_-.` durchlaufen lassen. Die Tests starteten jeweils einen frischen
Rehost mit demselben synthetischen Heap, dem Original-Freepfad, dem
Hilfsvektor und dem Dokument-Cleanup.

- Acht Eingaben mit erster Überlaufbyte `0` kehren vollständig mit `PASS`
  zurück: `0-`, `00`, `09`, `0A`, `0B`, `0_`, `0a`, `0z`. In allen acht
  Fällen bleibt der Folgeallocator bei `0x0bb636fc`.
- 64 weitere Eingaben faulten in QEMU mit SIGSEGV, bevor der vollständige
  Lauf endet.
- Die neun Paare mit erster Überlaufbyte `.` enden mit Exit 1 an der
  Harness-Assertion `callback did not alter adjacent size word`; das ist kein
  QEMU-SIGSEGV und kein unabhängiger Nachweis eines Geräteeffekts.

Die `PASS`-Fälle schreiben unterschiedliche Werte in das überwachte
Nachbarwort (beispielsweise `0x3030` für `00` und `0x7a30` für `0z`). Der
Folgezeiger bleibt dabei gleich, während einzelne synthetische Allocatorzähler
variieren. Das bestätigt eine enge Eingabeabhängigkeit des Heap-/Free-Verlaufs
im Rehost. Es zeigt weder eine frei wählbare Adresse in einem echten OSOS-
Objekt noch Kontrollflussübernahme.

## Nachfolgende Original-Allokationen im gleichen Rehost

Für die acht vollständigen Fälle habe ich anschließend `FUN_08020df4` mit den
Größen `0x10, 0x20, 0x40, 0x50, 0x80, 0x100, 0x200, 0x400, 0x1000`
aufgerufen. Alle acht Läufe enden weiter mit `PASS`. Die Rückgabepointer bis
einschließlich `0x200` sind über alle Fälle identisch. Erst bei `0x400` und
`0x1000` variieren sie:

| QName-Endbytes | Rückgabe für `0x400` | Rückgabe für `0x1000` |
| --- | ---: | ---: |
| `0-` | `0x0bb65ef4` | `0x0bb64eec` |
| `00` | `0x0bb661f4` | `0x0bb651ec` |
| `09` | `0x0bb66af4` | `0x0bb65aec` |
| `0A` | `0x0bb672f4` | `0x0bb662ec` |
| `0B` | `0x0bb673f4` | `0x0bb663ec` |
| `0_` | `0x0bb690f4` | `0x0bb680ec` |
| `0a` | `0x0bb692f4` | `0x0bb682ec` |
| `0z` | `0x0bb6abf4` | `0x0bb69bec` |

Die `0x400`-Rückgaben spannen im synthetischen Heap `0x4d00` Bytes. Das ist
ein neuer Hinweis auf dateibyteabhängige Heapformung bei größeren
Allokationen, aber kein beliebiger Adressschreibzugriff. Der Test fügt diese
Anforderungen künstlich nach Dokument- und Hilfsvektor-Cleanup ein; er zeigt
nicht, dass OSOS danach tatsächlich genau diese Größen anfordert. Außerdem
fehlt weiterhin der echte äußere Stream-Cleanup `FUN_081d0ff0` samt Provider-
und Registryzustand.

## Einordnung

Die Matrix stützt den Befund eines überlaufenden QName-Kopierpfads auf einen
benachbarten Heapheader im modellierten Layout. Sie präzisiert zugleich, dass
der zuvor erfolgreiche `0000`-Fall nicht isoliert ist: Weitere Endbytes mit
erstem Überlaufbyte `0` überstehen denselben synthetischen Ablauf. Für die
anderen Fälle unterscheiden die bisherigen Traces zwei Faultarten: Ein
Unlink mit gültigem Knoten und ungültigem Vorgängerpointer (`1`) sowie ein
bereits ungültiger Knotenpointer (`0xca74f90b`). Die Matrix allein bestimmt
nicht, welche der beiden Arten bei jedem einzelnen Eingabepaar auftritt.

Ein vollständiger Rehost des echten `FUN_08059ab0`-VFS-/Providerpfads und ein
reales Heaplayout fehlen weiter. Kein Lauf beweist Geräte-RCE, Persistenz,
Rockbox-Handoff oder untethered Boot.

## Dauerbelege

- `evidence/xml-heap-tail-byte-sweep-2026-10-31/README.md`
- `evidence/xml-heap-tail-byte-sweep-2026-10-31/results.tsv`
- `evidence/xml-heap-tail-byte-sweep-2026-10-31/summary.txt`
- `evidence/xml-heap-tail-byte-sweep-2026-10-31/run_tail_byte_sweep.py`
- `evidence/xml-heap-tail-byte-sweep-2026-10-31/run_postalloc_matrix.py` und
  `postalloc_results.tsv`
- 81 einzelne QEMU-Runlogs; `SHA256SUMS` deckt Skript, Matrix, README und
  Runlogs ab. Weitere acht Postallocation-Runlogs sind enthalten.

Keine Dateidaten am iPod wurden geändert.

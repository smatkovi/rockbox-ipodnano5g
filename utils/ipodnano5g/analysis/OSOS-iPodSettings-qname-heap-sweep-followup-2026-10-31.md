# iPodSettings XML: QName-Endbytes im Heap-Rehost

Stand: 31.10.2026. Offline-ARM1176-QEMU-Rehosts mit unveränderten OSOS-
Parser-, Callback-, Free- und Allocatorfunktionen. Kein Geräte-, USB-, DFU-,
NAND-, NOR- oder Flashzugriff.

## Ergebnis

Die bekannte `iPodSettings.xml`-Eingabe `A*82 + ".X"` trifft im Rehost den
Header eines benachbarten 0x58-Byte-Callbackchunks. Eine Variation der letzten
ASCII-Zeichen bei unveränderter QName-Länge von 82 verändert die Auswirkung
deutlich:

| Probe | Ergebnis im Rehost |
| --- | --- |
| `A*78 + "0000"` | Original-Freecode, Dokument-Cleanup und zusätzlicher Allocator-Aufruf kehren zurück. |
| `A*40 + "BAAA" + A*38` | SIGSEGV im Original-Freilisten-Unlink; der Knoten ist gültig, aber sein Vorgängerlink ist `1`, sodass der nächste Store auf Adresse `0x9` zielt. |
| `A*80 + "BB"` | SIGSEGV im Original-Freepfad mit ungültigem Knotenparameter `0xca74f90b`. |
| 81 Varianten mit neun zugelassenen Endzeichenpaaren | 8 `PASS`, 64 Gast-SIGSEGV, 9 Abbruch an einer Harness-Assertion. |

Die acht vollständig erfolgreichen Varianten liefern bei kleinen
Folgeallokationen identische Zeiger. Bei den im Harness zusätzlich
angeforderten Größen `0x400` und `0x1000` variieren die Rückgaben jedoch um bis
zu `0x4d00` Byte. Das zeigt, dass die korrumpierten Metadaten die modellierte
Heapbelegung beeinflussen können. Es ist kein Nachweis, dass der echte
MainApp-Code diese Folgeallokationen nach dem XML-Callback ausführt.

## Aussagekraft und Grenzen

Die XML-Namen sind mit dem untersuchten Lexer vereinbar, und der Rehost führt
den Original-Pushparser beziehungsweise die Original-Callback-/Freepfade für
die dokumentierten Fälle aus. Der Heap, die Registry, die Startbelegung und
die Callbackpaar-Reihenfolge sind jedoch vorgegeben. Der Rehost führt nicht
den vollständigen Loader `FUN_08059ab0`, dessen echten VFS-Open/Read,
Stream-Cleanup, Scheduler-Interleavings oder den Geräteheap aus.

Damit ist die Heapkorruption für konkrete Namen im Modell bestätigt und ihre
Abhängigkeit von den überschriebenen Headerbytes eingegrenzt. Kontrollierter
Rücksprung, überlappende lebende OSOS-Objekte, Codeausführung, Rockbox-Handoff
und untethered Boot sind nicht belegt.

## Belege

- `evidence/xml-heap-qname-sweep-2026-10-31/README.md` und die fünf
  QEMU-Ausgabelogs: gezielte QName-Endvarianten und Reproduktionsparameter.
- `evidence/xml-heap-tail-byte-sweep-2026-10-31/README.md`: 81 Endbytepaare
  und acht nachfolgende Allokationsläufe.
- Die Ordner enthalten Prüfsummenlisten und gespeicherte Ergebnisse. Der
  QName-Ordner enthält zusätzlich vollständige Instruktionsspuren und QEMU-ELFs;
  diese waren bereits in früheren Branch-Commits enthalten. Jedes ELF bindet
  das Runtime-Abbild ein und ist etwa 6,9 MB groß.
- Die gemeinsam genutzte Rehost-Quelle und das Linkerskript liegen unter
  `evidence/xml-heap-2026-10-29/OSOS_iPodSettings_shared_heap_rehost_20261030.S`
  und `evidence/xml-heap-2026-10-29/OSOS_iPodSettings_shared_heap_fullrange_rehost_20261030.ld`.
  Die Quelle bezieht das lokale OSOS-Runtime-Abbild aus
  `/home/sebastian/ipod-re/local-analysis/inputs/`; dieses Abbild ist kein
  Bestandteil des Repository-Commits.

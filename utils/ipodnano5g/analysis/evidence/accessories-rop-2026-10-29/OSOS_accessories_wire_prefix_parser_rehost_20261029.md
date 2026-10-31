# `accessories.reg`: Originalparser mit vollständigem Kandidaten-Byte-Stream

## Ergebnis

Der lokale QEMU-Rehost endet mit `PASS` (Exitcode 0). Er startet den
unveränderten `FUN_0802c3c4` bei `0x0802c3c4` und liest den vollständigen
704-Byte-Kandidaten `candidate_accessories_reg_unexecuted.bin` über einen
synthetischen Stream-Read-Stub ein. Der Tokenreader `FUN_0826dd26`, der
Containerprüfer `FUN_0826abb0`, der Integerhelper `FUN_0826ab24`,
`FUN_0823f4f4` und der Längenhelper `FUN_08039048` laufen als Originalbytes.

Der Parser konsumiert die echten Kandidatenbytes in Reihenfolge:

1. Container-Tags `0x40000029` und `0x4000002a`.
2. Integerdatensatz `0x2b`, Länge `4`, Wert `3` und Abschluss `0x8000002b`.
3. Tag `0x44`, Länge `0x284` und genau `0x284` Feldbytes.
4. Abschluss-Tag `0x80000044`.

Danach steht der Streamoffset bei `0x2a8` und der Parser folgt dem
Kandidatenpfad durch Cleanup, Epilog und die Original-Gadgetfolge bis zum
vorgelinkten Loader-Sentinel. Zehn Stream-Read-Aufrufe und der Endoffset
`0x2a8` werden vom Loader-Sentinel geprüft. Im Trace ist beim Aufruf von
`FUN_08039048` `max_length=0x100` zu sehen; der Originalhelper fordert danach
trotzdem `length=0x284` an.

## Was der Lauf belegt

- Der serielle Aufbau des lokalen Kandidaten ist mit dem unveränderten
  Parser-Tokenloop und den Originalprüfern konsistent.
- Der überlange `0x44`-Datensatz wird bei dieser Bytefolge tatsächlich in den
  Parserstack kopiert; der fehlende Vergleich mit `max_length` ist nicht nur
  eine isolierte Helperbeobachtung.
- Der Parser verarbeitet danach noch `0x80000044` und erreicht aufgrund des
  überschriebenen Loopzustands den Epilog. Die Bytes hinter Offset `0x2a8`
  werden in diesem Lauf nicht konsumiert.
- Das vorhandene lokale `build-n5g-blramdisk/bootloader.bin` hat Größe
  `0x10f80` (69.504 Byte), SHA-256
  `09b2dc3ff4940855b175508ce817c5f913798f3d7b2ba7669edef3427e224d03` und
  passt damit exakt zur statisch angeforderten Loader-Leselänge. Sein ELF hat
  Entry `0x09000000` und ein erstes LOAD-Segment mit `FileSiz=0x10f80` an
  derselben Adresse. Der normale OSOS-Taskkontext ist laut separater
  CPSR-Analyse SVC-privilegiert; das entfernt die Usermode-Schranke, belegt
  aber keinen realen Übergang.

## Was weiterhin simuliert wird

Der Stream selbst ist ein Prüf-Stub, der die Kandidatenbytes aus einem
eingebetteten lokalen Artefakt kopiert. Initialisierung, Pfad-/String-
Konstruktion, Open und Destruktor sind Prüf-Stubs; der VFS-Slot-0-Provider,
FAT-Cache und echte Block-/Dateizugriffe laufen nicht. Der zweite Open für
`/BOOT.BIN` wird geprüft, aber nicht über den realen FAT-Resolver ausgeführt.
Der Loader-Read-Stub prüft Länge und Zieladresse, füllt `0x09000000` jedoch
nicht mit dem Bootloader. Dort liegt stattdessen ein Loader-Sentinel. Es wird
kein Rockbox-Code ausgeführt.

Der aktuelle Gerätebestand enthält weiterhin die normale 69-Byte-Datei mit
`0x44`-Länge 9. `/BOOT.BIN` und der 704-Byte-Kandidat sind nur lokale
Analyseartefakte; sie wurden nicht auf das Gerät geschrieben. Es gab keinen
USB-, DFU-, Neustart-, NAND-/NOR-, Flash- oder Gerätezugriff.

## Reproduktion

Vom Verzeichnis `rb-n5g` aus:

```sh
clang --target=arm-linux-gnueabi -nostdlib -no-pie -fno-pie -fuse-ld=lld \
  -Wl,-T,utils/ipodnano5g/analysis/evidence/accessories-rop-2026-10-29/OSOS_accessories_wire_prefix_parser_rehost_20261029.ld \
  -Wl,--build-id=none \
  -o utils/ipodnano5g/analysis/evidence/accessories-rop-2026-10-29/OSOS_accessories_wire_prefix_parser_rehost_20261029.elf \
  utils/ipodnano5g/analysis/evidence/accessories-rop-2026-10-29/OSOS_accessories_wire_prefix_parser_rehost_20261029.S
qemu-arm -d in_asm,cpu \
  -D utils/ipodnano5g/analysis/evidence/accessories-rop-2026-10-29/OSOS_accessories_wire_prefix_parser_rehost_20261029.qemu-trace.log \
  utils/ipodnano5g/analysis/evidence/accessories-rop-2026-10-29/OSOS_accessories_wire_prefix_parser_rehost_20261029.elf
```

Quelle, Linkerskript, ELF, Trace und `run.log` liegen neben diesem Bericht.

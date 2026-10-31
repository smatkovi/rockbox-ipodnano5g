# `accessories.reg`: vollständiger Parser-Tokenloop im lokalen QEMU-Rehost

## Ergebnis

QEMU endet mit `PASS` (Exitcode 0). Der Harness startet den unveränderten
`FUN_0802c3c4` bei `0x0802c3c4` mit synthetischem `param_1` und lässt dessen
Prolog den Frame bei `S=0x08e55000` anlegen. Ein Token-Stub liefert einmal
`0x44`; danach führt der Originalparser seine `0x44`-Prüfung aus, ruft den
unveränderten `FUN_08039048` auf und schreibt eine Länge von `0x284` aus dem
Stream-Read-Stub nach `S+4`. Der Helper erhält anfangs `max_length=0x100`,
verwendet dieses Argument aber nicht als Obergrenze.

Der Lauf führt außerdem den Originalcode von `FUN_081965fe` und
`FUN_081936ec` aus. Das Kandidatenfeld beginnt mit NUL; die originale
Stringzuweisung springt deshalb über die VTable auf den Prüf-Stub für
`FUN_081ada60`. Der vom Feld überschriebene Loopzustand veranlasst den Parser,
nach diesem einen `0x44`-Feld auszusteigen. Der Original-Close-Wrapper und der
Parser-Epilog laufen; anschließend folgt die Original-Gadgetkette bis zum
vorgelinkten Loader-Sentinel. Open, Konstruktor, Tokenreader, Read-Dispatcher,
Helper-Finish, temporäre Stringkonstruktion und Loader bleiben Stubs.

Der Rehost belegt damit die bedingte Kontrollflussfolge innerhalb des
Originalparsers, wenn ein geöffneter Stream einmal `0x44` liefert und die
Read-Stubs die Kandidatenbytes zurückgeben. Er belegt weder einen echten
`accessories.reg`-Open noch, dass die reale Datei-/Containerstruktur diesen
Token und diese Länge liefert. Die Parser-Tokenquelle wird injiziert; das
Kandidatenfeld wird direkt aus der separaten Testeingabe kopiert. Es gibt
keinen echten FAT-/VFS-/Streamzugriff, keinen realen Loaderinhalt und keinen
Geräte- oder untethered Bootnachweis.

## Ausgeführte Originalbytes und Stubs

- Unverändert ausgeführt: `FUN_0802c3c4`, `FUN_08039048`,
  `FUN_081965fe`, `FUN_081936ec`, `FUN_082721d8` sowie die bereits geprüfte
  Gadgetfolge aus dem Runtime-Abbild.
- Aufrufe mit Prüf-Stubs: Parser-Initialisierung `FUN_0827e7ca` und
  `FUN_081a3790`, lokale String-/Pfadkonstruktion, `FUN_082721f0`, Tokenreader
  `FUN_0826dd26`, Read-Dispatcher `FUN_08268c3a`, Helper-Finish und Loader.
- Der Stub bei `FUN_0826dd26` setzt beim Parseraufruf das Token `0x44`; beim
  Helper-Finish liefert er nur Erfolg. Die Read-Stubs schreiben `0x284` in den
  Längenparameter und kopieren exakt 0x284 Bytes vom Kandidatenfeld nach
  `S+4`. Der dritte Read-Aufruf prüft nur die Loaderargumente und füllt
  `0x09000000` nicht.
- Der echte Stringdestruktor `FUN_081ada60` ist durch einen Prüf-Stub ersetzt.
  Die originale `FUN_081936ec` und die originale VTable werden ausgeführt;
  nur deren tatsächlich aufgerufener Destruktor ist gestubbt.
- Die nachfolgenden Konstruktor-, Open- und Loaderstubs prüfen Zieladressen,
  Pfadbytes, Aufrufreihenfolge und den Cleanup-Byte-Store. Der Loader-Sentinel
  bei `0x09000000` ist vorgelinkt und kein geladener Rockbox-Code.

## Reproduktion

Vom Verzeichnis `rb-n5g` aus:

```sh
clang --target=arm-linux-gnueabi -nostdlib -no-pie -fno-pie -fuse-ld=lld \
  -Wl,-T,utils/ipodnano5g/analysis/evidence/accessories-rop-2026-10-29/OSOS_accessories_full_parser_rehost_20261029.ld \
  -Wl,--build-id=none \
  -o utils/ipodnano5g/analysis/evidence/accessories-rop-2026-10-29/OSOS_accessories_full_parser_rehost_20261029.elf \
  utils/ipodnano5g/analysis/evidence/accessories-rop-2026-10-29/OSOS_accessories_full_parser_rehost_20261029.S
qemu-arm -d in_asm,cpu \
  -D utils/ipodnano5g/analysis/evidence/accessories-rop-2026-10-29/OSOS_accessories_full_parser_rehost_20261029.qemu-trace.log \
  utils/ipodnano5g/analysis/evidence/accessories-rop-2026-10-29/OSOS_accessories_full_parser_rehost_20261029.elf
```

`run.log`, ELF, Quelle, Linkerskript und Trace liegen neben diesem Bericht.
Die Dateien und das Kandidatenfeld sind im `SHA256SUMS`-Manifest erfasst.

## Nachtrag: vollständiger Kandidaten-Byte-Stream

Der spätere Rehost `OSOS_accessories_wire_prefix_parser_rehost_20261029`
führt zusätzlich den Original-Containerprüfer, Integerparser und Tokenreader
mit dem vollständigen lokalen 704-Byte-Kandidaten als Streamquelle aus. Er
verarbeitet die Präfix-Tags und den `0x80000044`-Abschluss; der Feldread hat
Länge `0x284`. Das ersetzt für Parser und Bytefolge die frühere
Tokenstub-Grenze. VFS-/FAT-Provider, echte Opens/Blockreads und Loaderinhalt
bleiben weiterhin gestubbt. Details stehen im Wire-Rehost-Bericht daneben.

# N5G-Loader im gepackten `.ipod`-Buildartefakt (29.10.2026)

## Verifizierter Formatbefund

Der lokale Build enthält `build-n5g-blramdisk/bootloader-ipodnano5g.ipod`
(69.512 Byte, `0x10f88`, SHA-256
`833aeb7ef18bb874103e497a7aa9ebbc41baae6ca11d4edec9e00485d9ee7e6e`) und
`build-n5g-blramdisk/bootloader.bin` (69.504 Byte, `0x10f80`, SHA-256
`09b2dc3ff4940855b175508ce817c5f913798f3d7b2ba7669edef3427e224d03`).
`cmp -n 69504 -i 8:0` bestätigt bytegenau, dass die ersten
acht Paketbytes vor dem vollständigen unveränderten `bootloader.bin` stehen.
`tools/Makefile` setzt `MKFIRMWARE` auf `tools/scramble -add=nn5g`; der
entsprechende Code in `tools/scramble.c` schreibt bei diesem Format acht
Bytes aus Add-up-Prüfsumme und Modellnamen vor den Eingabeblob.

Der frühere ROP-Kandidat liest 69.504 Bytes direkt nach `0x09000000` und
erwartet dort den rohen Rockbox-Entry. Das gepackte `.ipod`-Artefakt kann mit
derselben Entryadresse geladen werden, wenn der Read bei `0x08fffff8` beginnt:
die acht Paketbytes belegen dann `0x08fffff8..0x08ffffff`, und der identische
Rohblob beginnt genau bei `0x09000000`. Die gelinkten `bss_init`- und Entry-
Adressen bleiben dadurch `0x090001c8` und `0x09000000`.

## Getrennter, unausgeführter Kandidat

`build_candidate_accessories_reg_ipodpkg.py` erzeugt aus der vorhandenen
720-Byte-BSS-Variante eine neue 720-Byte-Datei. Sie ändert nur zwei ROP-Werte:
Read-Länge `0x10f88`, Ziel `0x08fffff8`. Pfad `/BOOT.BIN`, BSS-Aufruf, Entry,
Parserdaten und die unveränderte Basiskandidaten bleiben gleich. Das
`bootloader-ipodnano5g.ipod`-Artefakt wäre als Nutzdatei unter dem 8.3-Namen
`BOOT.BIN` verwendbar; dieser Dateiname fehlte im gespeicherten Root-Cluster
vom 29.10. und wurde nicht auf das Gerät geschrieben.

`run_ipodpkg_chain_rehost.sh` prüft zuerst die Paket-/Rohbildidentität und
modelliert anschließend den Read und die BSS-/Entry-Gadgetkette in QEMU.
`run_ipodpkg_parser_rehost.sh` ergänzt den unveränderten Originalparser und
den vollständigen 720-Byte-Streamkandidaten. Beide Läufe enden mit Exitcode 0.
Der integrierte Rehost prüft Read-Länge und Ziel, ARM-Entrywort
`0xea00000d`, die Wiederherstellung der Instruktion bei `+0x40`, den gesamten
BSS-Clear und den Sentinel. Die Datei
`ipodpkg_parser_wire_rehost.results.txt` nennt die einzelnen Rehost-Grenzen;
Trace und Run-Log liegen daneben.

## Grenzen

Das ist ein lokaler Byte-/Adress- und Kontrollfluss-Rehost, kein realer VFS-
Open, FAT-Read oder Geräteversuch. Er beweist weder, dass `/BOOT.BIN` zur
Laufzeit geöffnet werden kann, noch dass `0x08fffff8..0x0919fd00` bei diesem
OSOS-Lauf gefahrlos überschrieben werden kann. Der dokumentierte OSOS-Heap
beginnt bei `0x08e54e4c`; das Paket- und Bootloaderziel liegt darin. Der
statische Allocator splittet seine Blöcke von oben. Unter der ausdrücklich
bedingten Annahme eines einzelnen, unverfragmentierten Heapblocks wären etwa
44.065.248 Byte (42,024 MiB) belegter Heap nötig, bevor dessen freier Bereich
das Ende des Rockbox-BSS erreicht. Das spricht gegen eine frühe Kollision,
beweist die tatsächliche Heapbelegung aber nicht. Stackbasis und dynamische
Allokationen von `MainAppTask` bleiben unbekannt; der Gegenbefund steht in
`OSOS_accessories_loader_heap_threshold_20261029.txt`. Außerdem bleiben
Trigger/Queue-Reihenfolge, echter Stream-Open, Loader-Read und die Übergabe aus
OSOS offen. Das Rockbox-CRT wird nicht gestartet.

Es gab keinen Geräte-, USB-, DFU-, NAND-/NOR- oder Flash-Zugriff. Die Datei
`candidate_accessories_reg_ipodpkg_unexecuted.bin` wurde nicht ausgeführt und
nicht auf das Gerät geschrieben.

# Echter FAT-Eintrag im `accessories.reg`-Rehost

Diese Ablage verbindet den read-only erfassten FAT32-Eintrag des Geräts mit den Originalbytes der FAT-/Cluster-Runtime und dem bereits bestehenden Parser-Kandidaten-Rehost.

## Ergebnis

- Beide FAT-Kopien führen Cluster 179788 als EOC (`0x0fffffff`); die Rohsektoren sind identisch.
- `FUN_082014fc` liefert im Rehost ein Cluster-Extent für genau Cluster 179788.
- `FUN_0822641e` berechnet die Start-LBA `0x2c5ca0`.
- Die integrierte ARM1176-QEMU-Ausführung liefert `PASS\n`, Exit 0.
- Der Kandidateninhalt mit 704 Byte ist synthetisch. Nur der FAT-Sektor ist ein Geräte-Read; Dateiinhalt und Dateisektorquelle sind lokal modelliert.

Die Assertions und Abgrenzungen stehen in `results.txt`; der Build- und Ausführungsbefehl steht in `commands.txt`. Der separate unvollständige Lauf mit dem 69-Byte-Backup liegt in `../real-fat-original-control-20261030/` und ist kein Geräte- oder Firmwarefehler.

## Dateien

- `OSOS_accessories_parser_real_fat_entry_rehost_20261030.S`: Parser-/Harness-Einstieg und Assertions
- `OSOS_accessories_parser_real_fat_entry_core_20261030.inc.S`: Original-FAT-/Cachebytes, lokale streng begrenzte Sektorquelle
- `OSOS_accessories_parser_real_fat_entry_rehost_20261030.ld`: ARM1176-Rehost-Speicherlayout
- `OSOS_accessories_parser_real_fat_entry_rehost_20261030.elf`: ausführbarer Rehost
- `OSOS_accessories_parser_real_fat_entry_rehost_20261030.qemu-trace.log`: QEMU-Instruktions-/Registertrace
- `OSOS_accessories_parser_real_fat_entry_rehost_20261030.stdout.bin`: Ausgabe `PASS\n`
- `SHA256SUMS`: Prüfsummen der Dateien dieses Rehosts

Kein Mounten, kein DFU-/USB-Statusabruf, keine Partition-/NAND-/NOR-/Firmware-Schreibaktion.

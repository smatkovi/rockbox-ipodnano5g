# `accessories.reg`: reale Volume-LBA und FAT-Kette im Parser-Rehost

Stand: 30.10.2026

## Verifizierte Ergebnisse

Ein read-only Snapshot erfasste den FAT32-Eintrag für den Startcluster 179788 von `accessories.reg` in beiden gespiegelten FAT-Kopien. `ExtFlags=0` bedeutet gespiegelte FATs; beide Einträge sind `0x0fffffff` (EOC), beide vollständigen 512-Byte-Sektoren haben SHA-256 `3d8e64debc6be2debd552dc75172c0ea037a37439e8edc862fa5ca28c4493dde`. Der Eintrag steht in FAT-Kopie 0 auf 512-Byte-LBA `0x67c`, in Kopie 1 auf `0x41fc`; die Sektoren sind byteidentisch.

Der ARM1176-Rehost verwendet den echten FAT-Sektor von LBA `0x67c` und unveränderte Runtimebytes von `FUN_082014fc`, `FUN_0822fbbc`, `FUN_082015bc`, `FUN_08143ccc`, `FUN_0814346c`, `FUN_081d7e1a`, `FUN_0822641e` sowie den benötigten Divider-/Cachecode. `FUN_082014fc` liefert für Cluster 179788 ein Extent der Länge 1 mit Startcluster 179788. Der originale Cluster-Mapper berechnet aus BPB-Datenstart `0x7800` und Cluster-Shift 4 die erste Daten-LBA `0x2c5ca0`. Der integrierte QEMU-Lauf endet reproduzierbar mit Exit 0 und `PASS`.

Die Sektorquelle ist streng begrenzt: FAT-Daten werden nur für LBA `0x67c` geliefert; Kandidatendaten nur für LBA `0x2c5ca0` und `0x2c5ca1`. Assertions kontrollieren den echten FAT-Read, Extent und Cluster, die Mapper-LBA, beide Kandidatensektoren, Daten über die 512-Byte-Grenze und den vorhandenen Parser-/Loader-Sentinelpfad.

## Bedeutung für den Kandidaten

Der Gerätesnapshot weist für die vorhandene `accessories.reg` 69 Byte aus. Der Offline-Kandidat ist 704 Byte. Bei 4096 Byte pro FAT-Sektor und zwei Sektoren pro Cluster hat ein Cluster 8192 Byte Kapazität; daraus folgt, dass eine 704-Byte-Datei größenmäßig in einen Cluster passt. Das ist eine Geometrie-Inferenz, kein Schreib- oder Gerätetest. Die bestehende logische Dateigröße von 69 Byte muss für einen solchen Kandidaten angepasst werden.

Der reale FAT-Eintrag zeigt eine normale Clusterkette mit EOC, keinen Überlauf und keinen Folgecluster-Alias. Frühere Slack-/EOC-Effekte aus synthetischen Markern belegen daher keine reale FAT-Kettenmanipulation für diese Datei.

## Grenzen und Kontrolllauf

Der erfolgreiche Lauf ist ein Offline-Rehost. Die Volume-/Handle-/Parser-Startzustände werden teilweise im Harness gesetzt. FAT-Sektor und EOC-Wert stammen vom Gerät; Kandidateninhalt, Datei-Read-Sektoren, VFS-Open, Dateisystem-Mount und ATA-/USB-I/O sind lokal modelliert. Der 704-Byte-Kandidat wurde nicht aufs Gerät geschrieben. `PASS` bestätigt weder reale Parser-Erreichbarkeit noch RCE, Rockbox-Handoff oder untethered Boot.

Der korrigierte 69-Byte-Kontrolllauf kehrt im ARM1176-Rehost normal zurück (Exit 0, `PASS`). Er führt den Originalparser bis zum Cleanup aus. Die Sektorquelle verzeichnet drei Transfers: den echten FAT-Sektor einmal sowie den ersten Dateisektor bei LBA `0x2c5ca0` zweimal; nur ein eindeutiger Dateisektor wird verwendet. Der Parser-Callbackstub läuft, aber der niedrigere VFS-Open-Zähler bleibt null, weil Stream und Handle im Harness vorbereitet sind. Der Loader-Wrapper bleibt unerreicht. Der frühere Abbruch war ein Harnessfehler: Der Stub erwartete vor `FUN_081ada60` einen Nullpuffer, obwohl der echte Destruktor einen Nichtnullpuffer freigibt und anschließend löscht.

Die Kontrolle ist weiterhin kein vollständiger VFS-/Gerätenachweis: Volume-/Handlezustand, Stream und Parseraufruf werden teilweise gesetzt, der FAT-Sektor ist echt, die Dateidaten stammen aus dem lokalen Backup. Der dynamische Referenzfreigabepfad `FUN_0819af00` bleibt im Kontrollstub modelliert. Es folgt daraus weder automatischer VFS-Open noch automatische Parser-Erreichbarkeit, RCE, Rockbox-Handoff oder untethered Boot.

Keine NAND-/NOR-/Firmware-Schreibaktion, kein DFU-/USB-Statusabruf und kein Flashversuch in dieser Runde.

## Dauerbelege

- FAT-Aufnahme und Berechnung: `evidence/accessories-rop-2026-10-29/OSOS_accessories_FAT_cluster_179788_capture_20261030.txt`
- Rohsektoren: `OSOS_accessories_FAT_cluster_179788_copy0_lba_0000067c_20261030.bin` und `OSOS_accessories_FAT_cluster_179788_copy1_lba_000041fc_20261030.bin`
- Erfolgreicher integrierter Rehost, Ergebnisse und Reproduktion: `evidence/accessories-rop-2026-10-29/real-fat-entry-20261030/`
- Benigner 69-Byte-Kontrolllauf mit korrigiertem Destruktor-Stub: `evidence/accessories-rop-2026-10-29/real-fat-original-control-20261030/`

## Nächste Schritte

1. Den automatischen VFS-Open-/Handle-Aufbau vom MainApp-Aufruf bis zum realen FAT-Reader schließen; der Rehost setzt wesentliche Startfelder weiterhin manuell.
2. Die Laufzeitreihenfolge und erfolgreiche Registrierung des Storage-/Providerpfads prüfen. Der statische Parsercaller beweist noch keinen erfolgreichen Open beim Gerätestart.
3. Im Kandidatenlauf getrennt bewerten, welche Längen- und Stack-/Callbackzustände für den Loader-Sentinel nötig sind. Die bestehenden QEMU-Sentinels sind kein Geräte-RCE-Nachweis.
4. Erst nach einem belastbaren Open-/Read-Nachweis eine rückrollbare Dateisystemänderung und den Rockbox-Handoff untersuchen; aus den Rehosts keine Boot-/Flashänderung ableiten.

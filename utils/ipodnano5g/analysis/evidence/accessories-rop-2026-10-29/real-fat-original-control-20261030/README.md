# Benigner 69-Byte-Kontrolllauf mit realer FAT-Abbildung

Der korrigierte ARM1176-Rehost verarbeitet den unveränderten 69-Byte-Inhalt
aus dem Backup und kehrt mit QEMU Exit 0 sowie `PASS\n` zurück. Der Lauf
verwendet den read-only erfassten FAT-Sektor von LBA `0x67c`, den originalen
Extent-Reader und den originalen Cluster-LBA-Mapper. Die strenge lokale
Sektorquelle verzeichnet drei Transfers: den FAT-Sektor einmal und den ersten
Dateisektor bei LBA `0x2c5ca0` zweimal. Es ist nur ein eindeutiger Dateisektor
betroffen; LBA `0x2c5ca1` wird nicht angefordert. Der Parser-Callback läuft,
der niedrigere VFS-Open-Stub bleibt jedoch unerreicht, weil Stream und Handle
im Harness vorbereitet sind. Der Loader-Wrapper bleibt unerreicht.

Die früheren Läufe in diesem Ordner scheiterten an einer falschen
String-Destruktor-Stub-Annahme. Das originale `FUN_081ada60` akzeptiert einen
Nichtnull-Pufferzeiger, gibt eine Referenz frei und setzt das Objektfeld auf
null. Die alte Stubversion verlangte vor dem Aufruf bereits null. Version 2
modelliert den bekannten statischen Puffer eingeschränkt und lässt genau
diesen Cleanup-Pfad passieren. Das ist ein korrigierter Harness, kein
Firmwarefehler.

Es bleibt ein Offline-Rehost: Volume-/Handlezustand und der Parseraufruf
werden teilweise im Harness gesetzt. VFS-Mount/Open, echter ATA-/Datei-I/O
und die Referenzfreigabe `FUN_0819af00` werden nicht vollständig ausgeführt.
Die FAT-Bytes sind echt; die Dateisektorquelle liefert die lokal eingebetteten
Backupbytes. Das Ergebnis beweist weder automatische Laufzeit-Erreichbarkeit
noch RCE, Rockbox-Handoff oder untethered Boot. Es gab keinen Gerätezugriff,
keine Dateiänderung und keine NAND-/NOR-/Flashaktion.

Die korrigierte Variante und ihr Ergebnis stehen in
`OSOS_accessories_parser_original_fat_control_rehost_20261030_v2.S`,
`..._v2.elf`, `..._v2.qemu-trace.log`, `..._v2.stdout.bin` und
`..._v2.results.txt`. Reproduktionsbefehle: `..._v2.commands.txt`.
Die früheren Varianten/Traces bleiben zur Fehlerhistorie erhalten.

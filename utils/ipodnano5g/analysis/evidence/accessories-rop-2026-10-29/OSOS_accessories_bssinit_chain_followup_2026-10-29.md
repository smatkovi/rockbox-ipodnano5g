# Rockbox-BSS vor dem Bootloader-Handoff (29.10.2026)

## Verifizierter Befund

Der lokal gebaute Rockbox-Bootloader `build-n5g-blramdisk/bootloader.bin` ist
69.504 Byte (`0x10f80`) groß. Seine ELF-Einstiegsadresse ist `0x09000000`;
`.bss` liegt separat und ohne Dateibytes bei `0x09100000..0x0919fd00`
(`0x9fd00`, 654.592 Byte). Der rohe Binärexport enthält daher keinen
initialisierten `.bss`-Inhalt.

Im Bootloader-Zweig von `firmware/target/arm/s5l8702/crt0.S` springt der
normale Einstieg nach der Stack- und Vektorinitialisierung direkt zu `main`;
die allgemeine automatische BSS-Löschung wird dort übersprungen. Derselbe
CRT-Quelltext stellt jedoch `bss_init` als aufrufbare ARM-Routine bereit.
Das gebaute ELF ordnet sie `0x090001c8` zu. Sie löscht den gesamten Bereich
`_edata.._end`, bewahrt r4–r9 und kehrt mit wiederhergestelltem SP zurück.
Die Routine liegt innerhalb der vom Kandidaten geladenen `0x10f80` Bytes.

Der bisherige lokale Kandidat sprang nach dem Read unmittelbar nach
`0x09000000`. Das hätte Rockbox mit nicht initialisiertem `.bss` gestartet.
Die neue, getrennte Datei
`candidate_accessories_reg_bssinit_unexecuted.bin` erweitert das `0x44`-Feld
von `0x284` auf `0x294` Bytes: Nach dem Read ruft der vorhandene
BLX-/Pop-Trampolinpfad `bss_init` auf; dessen Rückkehr führt über denselben
Trampolinpfad anschließend zu `0x09000000`. Die bisherige 704-Byte-Datei
wurde nicht verändert. Die neue Datei ist 720 Byte und bleibt innerhalb des
ursprünglichen 8192-Byte-Clusters des aktuellen Volumes.

Der Parser-Cleanup schreibt zuvor ein Nullbyte nach `param_1+0x40`. Der
Kandidat kontrolliert den gespeicherten `param_1`-Wert auf `0x09000000`, also
trifft dieser Store zunächst `0x09000040`. Dort steht im Rockbox-Abbild die
Instruktion `e24fb008` (`sub fp,pc,#8`). Die Reihenfolge ist entscheidend:
der Store geschieht vor der ROP-Rückkehr und vor dem Loader-Read. Ein
vollständiger `0x10f80`-Byte-Read nach `0x09000000` stellt diese Instruktion
wieder her. Die alten Parser-Sentinels verwendeten einen Read-Stub und
bestätigten deshalb nur den vorherigen Nullstore; sie bewiesen keine
Wiederherstellung.

## Offline-Rehosts

`run_bssinit_rehost.sh` lädt die unveränderte Routine aus der tatsächlichen
`bootloader.bin`, füllt den realen BSS-Adressbereich mit `0xa5`, ruft
`0x090001c8` auf und prüft anschließend jedes Wort, den Stack und r4–r9.
`qemu-arm -cpu arm1176` beendet den Rehost erfolgreich.

`run_bssinit_chain_rehost.sh` nimmt exakt die 0x294 Datenbytes aus der neuen
Kandidaten-Datei und startet mit dem vom Stackledger erwarteten Post-Read-SP
`S+0x278`. Es führt die zwei originalgetreu assemblierten Thumb-Instruktionen
bei `0x08030cbc` aus (`blx r3; pop {r3,r4,r5,pc}`), ruft dadurch das echte
`bss_init` aus dem Rockbox-Binärblob auf und erreicht danach einen QEMU-Sentinel.
Der Rehost ersetzt ausschließlich das zweite Zielwort am Feldoffset `0x284`
durch die Sentinel-Adresse `0x09300000`; der Produktionskandidat enthält an
dieser Stelle weiter `0x09000000`. Der Sentinel bestätigt den erwarteten SP
`S+0x298` und den vollständig auf null gesetzten `.bss`-Bereich.

`run_bssinit_parser_rehost.sh` integriert die Variante außerdem in den
bounded-wire-Rehost: Originalparser und Tokenreader konsumieren das
720-Byte-Registry-Record, laufen durch Cleanup und ROP, und der Read-Dispatcher
kopiert den tatsächlichen Rockbox-Binärblob aus einem separaten QEMU-
Quellbereich nach `0x09000000`. Der Sentinel prüft, dass `0x09000040` wieder
`e24fb008` enthält, die Originalroutine `bss_init` lief und alle BSS-Wörter
null sind. QEMU endet mit `PASS`. Details und Ereignisfolge stehen in
`bssinit_parser_wire_rehost.results.txt`.

## Loader-Datei im gespeicherten Volume-Abbild

Der read-only Root-Directory-Capture vom 29.10. endet bei Slot 23 mit dem
FAT-Endrecord. Er enthält keinen Eintrag `BOOT.BIN`; vorhanden ist das
Verzeichnis `.rockbox`. Die gespeicherte `.rockbox`-Verzeichnisliste vom
26.10. enthält `rockbox.ipod` und `n5g-ramdisk.img`, aber kein
`bootloader.bin`. Das lokale Host-Image `build-n5g-blramdisk/bootloader.bin`
existiert und passt bytegenau zur geforderten Read-Länge, befindet sich laut
diesen Snapshots aber nicht an einem der dokumentierten Gerätepfade.

Die Prüf-Rehosts kontrollieren einen String `/BOOT.BIN`; ein älterer
Gadget-Vermerk beschreibt dagegen die Konstruktion
`/.rockbox/bootloader.bin`. Weil VFS-Open und Pfadauflösung im Rehost gestubbt
sind, ist der tatsächlich aufgelöste Gerätepfad noch offen. Beide genannten
Dateien fehlen in den jeweiligen gespeicherten Verzeichnislisten. Die
Snapshots sind zeitgebunden; sie beweisen nicht den aktuellen Gerätezustand.
Quelle und Einordnung stehen in
`OSOS_accessories_bootloader_file_presence_2026-10-29.txt`.

## Grenzen und nächste Prüfung

Damit ist der Parser-/ROP-/Read-/BSS-Teil im Rehost verbunden. VFS-Open,
Initial-Refill aus dem echten Volume, reale MainAppTask-Stackbasis und die
Task-Ausführungsrechte sind weiterhin nicht nachgewiesen. Der Rockbox-Einstieg
`start` wurde bewusst nicht ausgeführt: sein CRT verändert privilegierte
CP15-/MMU-/Cachezustände und greift auf SoC-Hardware zu. Ein erfolgreicher
QEMU-Sentinel ist daher weder ein Geräte- noch ein Bootnachweis.

Nächste statische Schranke ist die reale Open-/Refill-Kette für die derzeit
69 Byte große `accessories.reg`, die aufgelöste Loader-Datei und der Read der
69.504 Byte. Ein RAM-Handoff-Test kann anschließend separat erfolgen; ein
Flash-Schreibvorgang ist für diesen Nachweis nicht erforderlich.

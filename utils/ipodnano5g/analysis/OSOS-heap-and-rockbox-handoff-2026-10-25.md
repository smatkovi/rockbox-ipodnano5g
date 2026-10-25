# OSOS-Heapgrenze und möglicher Rockbox-RAM-Handoff

Stand: 25.10.2026. Nur Offline-Analyse. Kein USB-, DFU-, Boot-, NAND- oder
NOR-Zugriff.

## Abbildzuordnung

Das vollständige entschlüsselte OSOS-Binary
`/home/sebastian/ipod-re/nano5g/osos_decrypted/osos_body.bin` wurde im alten
Ghidra-Projekt ab `0x08000000` abgebildet. Das Runtime-Abbild
`/tmp/osos_runtime_dram_20261025.bin` bildet den Body ab Dateioffset `0x2e27c`
auf `0x08000000` ab. Für enthaltene Funktionen gilt deshalb:

```text
Runtime-VA = Full-Body-VA - 0x2e27c
```

Das wurde an mehreren Funktionen byte- und pseudocodeweise bestätigt:
`0x082a06f0` → `0x08272474` (Heap-Setup), `0x0838ad08` → `0x0835ca8c`
(DRAM-Bereich) und `0x0804c354` → `0x0801e0d8` (Speicherbereich-Aufteilung).
Gleichlautende Adressen aus den beiden Ghidra-Abbildungen dürfen daher nicht
direkt verglichen werden.

## Tatsächlicher OSOS-Heapbereich

Im Runtime-Abbild erstellt `FUN_08272474` den globalen Heap-Manager bei Bedarf.
Sie übergibt `0x086cfb9c` und die Konfiguration bei `0x0843e6c0` an
`FUN_08264964`. Danach ruft sie `FUN_0835ca8c` und `FUN_0801e0d8` auf und
initialisiert den Allocator über `FUN_08196860`.

`FUN_0835ca8c` holt den Systemdatensatz über `FUN_081927a4` und setzt den Anfang
des verwalteten DRAM-Bereichs auf `0x08e54e4c`. Die Länge berechnet sie als
`Systemdatensatz[0xe0] + Systemdatensatz[0xe4] - 0x08e54e4c`, also als
Speichergröße plus Basisadresse minus Heap-Anfang.

Die Aufteilung in `FUN_0801e0d8` verwendet die Konfiguration bei
`0x08550a48`. Die im Runtime-Abbild gespeicherten Werte sind bei `+0x14`
`0x0012e060`, bei `+0x24` `0x00196060` und bei `+0x28` `2`. Bei einem
64-MiB-Systemdatensatz mit DRAM-Basis `0x08000000` rechnet die Funktion das
obere Ende auf `0x0bf00000` herunter, zieht die reservierten Bereiche ab und
übergibt dem Allocator den Bereich:

```text
0x08e54e4c .. 0x0bba5ee0
```

Der vorhandene Rockbox-Loader ist bei `0x09000000` gelinkt. Diese Adresse
liegt `0x001ab1b4` hinter dem Heap-Anfang und damit **innerhalb des von OSOS
verwalteten Heapbereichs**. Ein Live-Heapabbild fehlt; daher ist nicht bekannt,
welche OSOS-Allokationen beim tatsächlichen Start gerade diese Adresse
belegen. Der Loader kann dort nicht als unbenutzter Speicher vorausgesetzt
werden.

## Vorhandener Loader als Einweg-Handoff-Ziel

Das lokale ELF `build-n5g-blramdisk/bootloader.elf` hat den Entry Point
`0x09000000`. Sein erstes LOAD-Segment liegt dort; `.text`, `.rodata`, `.data`
und Stacks belegen im Linkerlayout bis `0x09013780`. Die BSS liegt separat ab
`0x09100000` und umfasst `0x9fd00` Byte. Das daraus gebaute
`build-n5g-blramdisk/bootloader.bin` ist 69.504 Byte groß. Der bestehende
Hostpfad lädt diese Datei über U-Boot/USB-ACM nach `0x09000000` und startet
genau dort.

`crt0.S` des N5G-Bootloaders wechselt früh in den Supervisor-Modus, maskiert
IRQ/FIQ, schaltet MMU und Caches ab, leert TLB und Prefetch-Puffer und setzt
die CPU-Stapel neu. Danach initialisiert `main()` Rockbox-Systemzustand und
BSS. `system_preinit()` überspringt beim Nano 5G ausdrücklich die frühe
SDRAM-/Taktinitialisierung, weil die SRAM-Startstufe diese erledigt. OSOS hat
SDRAM bereits eingerichtet; dass sämtliche CPU-/MMU-/IRQ-Annahmen beim
Übergang aus einer OSOS-Task passen, ist dennoch nicht bewiesen.

Damit ist ein konzeptioneller Pfad vorhanden: Eine bereits erreichte
OSOS-Codeausführung könnte den Loader aus einer Datei der FAT-Partition in
RAM lesen, ihn an seinen festen Entry Point übertragen und die Kontrolle
dauerhaft übergeben. Das würde den OSOS-Heap überschreiben und ist nur als
Einwegübergabe plausibel, bei der OSOS nicht weiterlaufen soll. Das aktuelle
Abbild belegt weder eine solche Codeausführung noch einen automatischen
Datei-Trigger, passende Dateisystemrechte, ausführbaren RAM oder den nötigen
privilegierten CPU-Modus. Die Loaderdatei ist außerdem in den bisherigen
Installationsnotizen nicht als auf der FAT-Partition vorhanden verifiziert;
der aktuelle Testablauf liefert sie vom PC.

Der Loader prüft beim Start den Hold-Schalter und startet bei gesperrtem
Schalter das signierte Apple-OS. Falls ein OSOS-Autostartfehler auch bei
gesperrtem Hold erneut ausgeführt würde, könnte daraus eine Rückkehrschleife
entstehen. Der spätere Trigger muss den gesperrten Fall daher vor dem Handoff
auslassen oder anderweitig sicher beenden.

## Bewertung der OSOS-Lücke

Eine Schwachstelle im normalen signierten OSOS kann prinzipiell einen
untethered Rockbox-Start ermöglichen, wenn sie bei jedem Kaltstart automatisch
über persistente Benutzerdaten erreicht wird und zu Codeausführung führt. Die
bisher untersuchten Notes-, ArtworkDB- und Tasknamenfehler erfüllen diese
Kette noch nicht: Bei Notes/ArtworkDB fehlen ein nachgewiesener automatischer
Kaltstart-Trigger und kontrollierte Kontrollflussübernahme; die Tasknamen im
bekannten Pfad sind statisch und kurz. Es wurde keine reproduzierbare OSOS-RCE
gefunden.

## Nächste Offline-Schritte

1. Die dynamische Registrierung/Initialisierung der MainApp-Handler und der
   BootTask-Tabelle weiter über Laufzeitdaten und Overlays verfolgen.
2. Für Notes, ArtworkDB und Device Preferences einen konkreten
   Kaltstart-Dateipfad bis zum fehlerhaften Parser nachweisen oder verwerfen.
3. Die Taskprivilegien, MMU-Attribute für DRAM und die OSOS-Datei-I/O-API
   prüfen, bevor der Einweg-Handoff als ausführbar eingestuft wird.
4. Wenn ein automatischer RCE-Trigger belegt ist, den Loader als Datei auf der
   FAT bereitstellen und den Handoff erst bei verfügbarer Hardware in RAM
   kontrolliert prüfen. Dafür ist kein NAND-/NOR-Schreibpfad erforderlich.

Rohbelege: `/tmp/OSOS_runtime_heap_init_translated_20261025.txt`,
`/tmp/OSOS_runtime_heap_translated_refs_20261025.log`,
`/tmp/OSOS_runtime_heap_init_callers_20261025.txt` und
`arm-none-eabi-readelf -h -l -S build-n5g-blramdisk/bootloader.elf`. Die
Ghidra-Läufe verwendeten `-noanalysis -readOnly`.

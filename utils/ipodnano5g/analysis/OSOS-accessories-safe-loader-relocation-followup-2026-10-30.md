# Relokierter Rockbox-Zwischenloader für den Accessories-ROP-Pfad

Stand: 30.10.2026. Offline-Link und ARM1176-QEMU-Rehost; kein Gerät, USB,
DFU, Neustart oder Flashzugriff.

## Ergebnis

Der bestehende Rockbox-Bootloader lässt sich unverändert im Quellcode, aber
mit einem separaten Linkerskript bei `0x0bf00000` starten. Das Load-Segment
bleibt `0x10f80` Byte groß und passt damit in die vom Accessories-Kandidaten
vorgesehene Leselänge. Der Link legt Stack und Code bis `0x0bf13780` und BSS
bei `0x0bf20000..0x0bfbfd00` ab. Damit liegen Loader-Code, Stack und BSS
außerhalb des zuvor berechneten OSOS-Heapbereichs
`0x08e54e4c..0x0bba5ee0`.

Eine separate Kopie des 704-Byte-ROP-Eingabekandidaten wurde an seinen drei
Wörtern mit `0x09000000` auf `0x0bf00000` umgestellt. Der auf dem echten FAT-
EOC-Capture und dem bestehenden Parser-Rehost beruhende ARM1176-Lauf endet
mit `PASS`; der QEMU-Trace zeigt den abschließenden Sprung nach
`0x0bf00000`. Der Rehost enthält dort weiterhin einen Loader-Sentinel, keinen
geladenen oder ausgeführten Rockbox-Bootloader. Das ist ein Link- und
Argumentnachweis im lokalen Modell, kein Geräteboot.

### Exakter Loader-Read im erweiterten Rehost

Ein zweiter Rehost bettet nun `bootloader-safe.bin` ein und modelliert den
erfolgreichen Datei-Read als Bytekopie an `0x0bf00000`. GDB hält QEMU direkt
am Loader-Entry an, bevor irgendeine Loader-Instruktion läuft. Der ausgelesene
Bereich umfasst genau 69.504 Byte (`0x10f80`); der Speicher-Dump ist bytegleich
mit `bootloader-safe.bin`, beide SHA-256 sind
`ba355bf5771a686a07829d3df45772c2d4bc9c33ca9cf0346d17408a5f20b4b2`.

Eine zusätzliche GDB-Zeitaufnahme zeigt am Eintritt des Loader-Read-Callbacks
`0x00` bei `0x0bf00040`; direkt vor dem Loader-Entry steht dort wieder das
Originalbyte `0x08`. Der Nullmarker im alten Sentinel-Rehost ist somit ein
Zwischenzustand **vor** dem Datei-Read. Er belegt keine Beschädigung des
geladenen Loaders nach dem Read.

Der neue Rehost speist die Bytekopie aus einem eingebetteten lokalen Abbild;
die FAT-/VFS-/ATA-Lesefunktion ist weiter gestubbt. Er beweist daher weder
einen echten OSOS-Datei-Read noch eine freie Live-Speicherregion auf dem Gerät.
Am Breakpoint wurde der Rockbox-Code nicht ausgeführt.

Die ersten Loaderbytes disassemblieren bei der relocatierten Adresse korrekt:
`start` verzweigt zu `_newstart` bei `0x0bf0003c`; dort stellt `MSR CPSR_c,
#0xd3` den SVC-Modus mit maskierten IRQ/FIQ ein. Die separate OSOS-Taskanalyse
weist für reguläre Tasks ebenfalls SVC-Modus (`CPSR=0x13`, Thumb `0x33`) nach.
Das macht den Privilegübergang architektonisch plausibel, belegt aber weder
den konkreten Accessories-Kontrollfluss auf dem Gerät noch die tatsächliche
MMU-/Cache-/DMA-Übergabe. Danach arbeitet der Loader unter anderem mit seinem
MMU-Neustart und der BSS bei `0x0bf20000..0x0bfbfd00`; diese Region ist
statisch außerhalb des berechneten OSOS-Heaps, aber nicht als live frei
gemessen.

Der Startpfad macht die Einweg-Annahme konkret: `crt0.S` schaltet ab
`start_loc` die bisherige MMU und Caches ab und setzt die Interruptmasken.
`bootloader/ipodnano4g.c:498-499` ruft anschließend `memory_init()` und
`bss_init()` auf. Wegen `MEMORYSIZE=32` liegt die neue 16-KiB-Tabelle bei
`0x09ffc000..0x0a000000`, also innerhalb des alten OSOS-Heaps. `set_page_tables`
füllt Einträge dort, bevor die BSS bei `0x0bf20000..0x0bfbfd00` genullt wird.
Das ist nur als endgültige Übergabe plausibel: Der Loader überschreibt bewusst
OSOS-Zustand und kann nicht zu dessen Task zurückkehren. Die statische
Gadgetfolge endet am Loader-Entry; ein tatsächlicher Laufzeit-Handoff bleibt
offen.

## Speichergrenzen und Vorbehalte

- Das Repository dokumentiert für dieses 16-GB-Gerät 64 MiB SDRAM ab
  `0x08000000`; `NOTES.md` hält außerdem die frühere U-Boot-`bdinfo`-Messung
  mit 64 MiB fest.
- Der bisherige Loader lag bei `0x09000000` und sein BSS bei
  `0x09100000`, beides innerhalb des errechneten OSOS-Heaps. Das neue Layout
  verlegt diese Bereiche über das Heapende.
- OSOS' berechnetes Heapende ist nicht die gesamte belegungsfreie
  Speichergrenze. Das Intervall oberhalb davon bis zum DRAM-Ende kann
  OSOS-reservierte Daten oder laufzeitabhängige Hardware-Puffer enthalten.
  Eine Live-Speicheraufnahme fehlt; die neue Adresse ist daher nicht als
  zur Laufzeit frei bewiesen.
- Der Bootloader-Build behält `MEMORYSIZE=32` aus dem vorhandenen Build bei.
  Sein Rockbox-MMU-Tabellenzeiger bleibt damit bei `0x09ffc000`; der
  Linkerskriptbereich endet vorsorglich vor `0x0bffc000`. Der Bootloader
  initialisiert den MMU neu, bevor `bss_init()` den ausgelagerten Bereich
  nullt. Dass der Übergang aus dem OSOS-Task unter realer MMU-/DMA-Belegung
  stabil ist, wurde nicht dynamisch geprüft.
- Die Kandidatdatei `accessories.reg` wurde nicht auf das Gerät geschrieben.
  Der zuletzt erfasste Inhalt ist weiterhin die harmlose 69-Byte-Datei.
  `BOOT.BIN` fehlt in der gesicherten Root-Verzeichnisaufnahme; eine
  Installation auf dem Nutzdatenvolume fand nicht statt.

## Dauerhafte Belege

Alle neu erzeugten Link-, Kandidaten- und Rehostdateien liegen unter
`analysis/evidence/accessories-safe-loader-relocation-2026-10-30/`. Die dortige
README enthält Dateiliste, Prüfsummen und Reproduktionskommandos.

Der statische Taskreihenfolge-Abgleich ist in
`OSOS-RTOS-scheduler-order-and-accessories-startup-followup-2026-10-30.md`
festgehalten. Er bestätigt eine aufsteigende Ready-Liste und macht die Folge
DeviceDiscovery → ATA-Queue-4-Post → Slot-0-Mount → MainApp mit den bekannten
Prioritätswerten plausibel, lässt aber Dispatch/Preemption und die reale
Kaltstartfolge offen. Außerdem ist `FUN_080039b0` als CP15-Registerhelper
identifiziert, nicht als Taskselektor.

Der nächste Offline-Schritt ist daher der vollständige VFS-Open-/Read-Rehost
ohne vorausgefüllten Stream/Handle und eine genauere Simulation der
Task-Dispatchfolge. Für eine spätere Hardwareprüfung fehlen weiterhin ein
erfolgreicher OSOS-Datei-Open, ein Beleg, dass die obere DRAM-Region beim
OSOS-Lauf frei ist, und der echte Handoff. Weder eine OSOS-RCE noch ein
untethered Rockbox-Boot ist bestätigt.

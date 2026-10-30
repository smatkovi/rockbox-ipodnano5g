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

Nächster Offline-Schritt: denselben Zielwechsel in einen vollständigen
Loader-Read-Rehost einbauen, der die 69.504 echten Loaderbytes an das neue
Ziel kopiert und Stack/BSS-Grenzen prüft. Danach bleibt für Hardware nur ein
kontrollierter, RAM-only Test nötig; vorher muss die freie Belegung der
reservierten oberen SDRAM-Region geklärt werden. Weder ein OSOS-Exploit noch
ein untethered Rockbox-Boot ist damit bestätigt.

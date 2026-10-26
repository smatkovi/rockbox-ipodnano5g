# Laufende iPod-Software als möglicher untethered Rockbox-Einstieg

Stand: 26.10.2026. Read-only-Prüfung lokaler Quelltexte und vorhandener
OSOS-Analysen. Keine USB-, DFU-, Boot-, NAND-/NOR- oder Geräteaktion.

## Kurzantwort

Ja, ein Fehler in der laufenden, signierten iPod-Software könnte prinzipiell
einen PC-freien Rockbox-Start ermöglichen, ohne dass eine Apple-Signatur
gefälscht oder ein Bootloader dauerhaft ins Flash geschrieben wird: Nach jedem
Kaltstart müsste eine persistente Datei automatisch einen OSOS-Fehler auslösen,
der kontrollierte Codeausführung erreicht. Dieser Code könnte den vorhandenen
Rockbox-Loader von der FAT-Partition nach RAM laden und dorthin springen. Hold
müsste vorher geprüft werden, damit der gesperrte Fall im Apple-OS bleibt.

Ein einmaliger Exploit nach manuellem Öffnen einer App reicht nicht. Auch ein
beliebiger Schreibzugriff auf Dateien auf der Datenpartition reicht allein
nicht, solange OSOS beim Kaltstart keine entsprechende Datei automatisch
ausführt.

## Verifizierte lokale Start- und Speicherpfade

- `utils/ipodnano5g/n5g-installed-boot.sh` wartet ausdrücklich auf BootROM-DFU,
  startet wInd3x/U-Boot und überträgt den Rockbox-Bootloader per YMODEM nach
  SDRAM-Adresse `0x09000000`; anschließend springt es mit `go` dorthin. Der
  Skriptkommentar und die ausgeführten Befehle bestätigen: Das ist ein
  RAM-Start, kein persistenter Bootloader-Installer.
- `firmware/export/config/ipodnano5g.h` kennzeichnet den N5G-NAND-Treiber als
  schreibgeschützt. In `firmware/target/arm/s5l8702/ipodnano4g/nand-target.h`
  wird `NAND_WRITABLE` für `IPOD_NANO5G` nicht definiert; die N5G-Implementierung
  von `nand_write_sectors()` gibt bei nichtleeren Schreibanforderungen deshalb
  `-3` zurück. Das belegt nur die Grenze des lokalen Rockbox-Treibers, nicht
  Apples eigenen NAND-Treiber oder dessen Berechtigungen.
- `bootloader/ipod-s5l87xx.c` enthält den Datei-Ladepfad für `rockbox.ipod`;
  die N5G-RAM-Bootloader-Analyse bestätigt außerdem Fallbacks zu OSOS bei
  gesperrtem Hold oder fehlender/nicht ladbarer Rockbox-Datei. Diese Pfade
  belegen den möglichen RAM-Handoff, nicht dass Apple-OSOS den Loader starten
  kann.
- Das lokale Projekt beschreibt wInd3x als temporären DFU-/RAM-Pfad. Die
  Upstream-Dokumentation sagt ebenfalls, dass haxed DFU bis zum nächsten
  Neustart gilt und den persistenten Gerätezustand nicht verändert
  ([wInd3x README](https://github.com/freemyipod/wInd3x)).

## OSOS-Eingabepfade und Exploitstatus

Die vorhandenen Analysen belegen persistente Eingaben, aber bisher keine
vollständige Kombination aus automatischem Kaltstart-Trigger und
Kontrollflussübernahme:

- **Notes:** Der UTF-8-Pfadtrim kann bei einer unvollständigen Drei-Byte-Sequenz
  eine Kopierlänge von `0xffffffff` erzeugen. Das ist ein ernstzunehmender
  Out-of-bounds-Schreibkandidat. Der Notes-/VFS-Übergang, ein automatischer
  Start des verwundbaren Pfads und kontrollierte Codeausführung sind nicht
  belegt.
- **ArtworkDB:** `mhia_count << 2` kann eine zu kleine Allokation verursachen.
  Die bisherigen Heapmodelle zeigen Korruption, aber keinen kontrollierten
  PC/LR-Wert. Der automatische Kaltstartaufruf des Parsers ist offen.
- **eApp/Games:** `_skipgamedrm` kann unter den untersuchten Bedingungen die
  optionale `Manifest.plist.p7b`-Prüfung umgehen. `.sinf`- und
  Metadatenverarbeitung folgen weiter; ein beliebiges ausführbares eApp oder
  ein automatischer Spielstart beim Einschalten ist nicht nachgewiesen.
- **TunerSettings:** Ein persistenter Leser ist über das MainApp-Setup
  erreichbar, verarbeitet im geprüften Pfad aber feste typisierte Felder.
  Kein Speicherfehler oder RCE ist belegt.
- **Alarmdatei:** Der Starttask-Plan enthält einen `AlarmTask`, dessen
  Ereignisschleife den Dateiparser nicht aufruft. Das MainApp-Setup schreibt
  den Alarmzustand; der Importpfad hat weiterhin keinen belegten automatischen
  Startaufrufer. Das geprüfte Feld `0x3c` liefert nur einen bedingten
  Stack-OOB-Read, keine bestätigte Kontrollflussübernahme.
- **ArtworkDB-Start:** Der von `TMusicLoadingTask` benötigte Kontextslot ist im
  gespeicherten Runtime- und Full-Body-Abbild null. Im OSOS-Code wurde kein
  Schreiber gefunden; ein zusätzlicher Literal-Scan der verfügbaren Firmware-
  und PE32-Module fand keine direkten Referenzen auf diesen Slot. Berechnete
  oder nicht extrahierte Laufzeitverweise bleiben offen.
- **Play Counts, Contacts, Device-Konfiguration, Workout-XML und weitere
  geprüfte Pfade:** bislang kein bestätigter Speicherfehler mit
  Kontrollflusswirkung und kein vollständiger automatischer Bootpfad.

Quellen im Arbeitsbaum: `OSOS-runtime-exploit-boot-feasibility-2026-10-25.md`,
`OSOS-persistent-device-file-reader-audit-2026-10-25.md`,
`OSOS-additional-persistent-paths-followup-2026-10-26.md`,
`OSOS-play-counts-input-followup-2026-10-26.md`,
`OSOS-radio-tuner-settings-parser-followup-2026-10-26.md` und
`OSOS-workout-parser-and-ramboot-audit-2026-10-26.md` sowie
`OSOS-DiskMgrTask-startup-followup-2026-10-26.md`.

## Schlussfolgerung und nächste Schritte

Der laufende OSOS-Pfad ist als Konzept ein realistischerer Weg als der Versuch,
einen privaten Apple-Schlüssel zu erraten. Im geprüften Material wurde jedoch
noch keine Lücke gefunden, die sich bereits als wiederholbarer untethered
Start verwenden lässt. Die zwei stärksten Speicherfehlerkandidaten (Notes und
ArtworkDB) brauchen weiterhin sowohl einen belegten automatischen
Kaltstart-Trigger als auch eine belastbare Kontrollflussübernahme.

Weiterhin offen sind:

1. dynamische Factory-/Overlay-Registrierungen, die den Notes- oder
   ArtworkDB-Parser beim normalen Kaltstart erreichen könnten;
2. die tatsächliche Kontrollflusswirkung der Notes-Unterlaufkopie und des
   ArtworkDB-Heap-Overflows;
3. ob OSOS einen beliebigen RAM-Handoff aus seinem normalen Taskkontext
   durchführen kann, ohne den Hold-gesperrten Apple-Pfad zu stören;
4. Apples eigener NAND-/Firmware-Schreibpfad. Die lokale Rockbox-Sperre ist
   kein Beleg dafür, dass Apple-OSOS keine Flashoperation ausführen kann; ein
   solcher Schreibpfad würde außerdem die Signaturprüfung beim nächsten Start
   nicht automatisch umgehen.

Das Gerät blieb unangetastet. Es wurden keine Tests oder Builds ausgeführt.

## Nachtrag: MainApp-Media-Setup hängt an bedingtem Event (26.10.2026)

Der zuvor offene Aufruf des MainApp-Setups `FUN_08086ce8` wurde eine Ebene
weiter zurückverfolgt. Der direkte Aufrufer ist `FUN_08079fb4`; diese Routine
wird im gespeicherten OSOS-Code nur aus dem Eventdispatcher `FUN_08066fb4`
aufgerufen. Der Dispatcher akzeptiert hier Eventtyp `0x12` und verlangt, dass
der Nutzdatenzeiger aus Feld `0xd00` genau auf `MainApp + 0x818` zeigt.

Vor dem Setup prüft `FUN_08079fb4` über `FUN_08280452` das Byte
`MainApp + 0x8e1`. Bei Wert `0x2c` (ASCII-Komma) setzt der Helper ein
separates Statusbyte und die Setup-Routine wird übersprungen. Bei anderen
Werten kann `FUN_08086ce8` folgen, sofern der zusätzliche globale
Zustandstest ebenfalls den Setup-Zweig auswählt. `FUN_08086ce8` führt
anschließend MainApp-/Device-Service-Initialisierung aus, darunter
`FUN_0828bd04`; dieser Aufruf allein belegt keinen automatischen Lauf eines
verwundbaren Dateiparsers.

Für `FUN_08066fb4` gibt es im Ghidra-Projekt keinen direkten Code-Xref. Ein
Rohscan des Full-Body-Binaries fand weder das absolute noch das 24-/32-Bit-
relative Funktionsoffset für ARM- oder Thumb-Einstieg als gespeicherten
Funktionszeiger. Damit ist die Eventquelle bzw. dynamische Registrierung
weiterhin unbekannt. Die MainApp startet zwar ihren Eventloop, aber in den
gespeicherten Daten ist kein Kaltstart-Sender für genau dieses Event
nachgewiesen. Dies ist eine bedingte Runtime-Spur und kein bestätigter
Kaltstart-Trigger oder Exploit.

Rohbelege: `/tmp/OSOS_event_dispatch_08066fb4_20261026.txt`,
`/tmp/OSOS_mainapp_setup_dispatch_20261026.txt`,
`/tmp/OSOS_event_object_helpers_20261026.txt` und
`/tmp/OSOS_mainapp_setup_refs_20261026.txt`. Ghidra wurde mit
`-readOnly -noanalysis` auf dem Full-Body-Abbild verwendet; keine
Geräte-/USB-/DFU-/Boot-/Flashaktion. Der Rohscan auf absolute und
base-relative Funktionszeiger ist in
`/tmp/OSOS_mainapp_event_pointer_scan_20261026.txt` festgehalten.

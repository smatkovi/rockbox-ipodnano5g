# iTunes-PLIST-Kandidat: Rehost und Pfadprüfung

Stand: 31.10.2026. Offline-Analyse des OSOS-Runtime-Abbilds
`osos_runtime_dram_20261025.bin`. Keine Geräte-, USB-, DFU-, NAND-, NOR- oder
Firmwareoperation.

## Verifizierte Ergebnisse

1. **Der dynamische Pfad wird aus einem festen iTunes-Präfix und einem
   variablen String gebildet.** `FUN_08213400` beginnt mit
   `iPod_Control\\iTunes\\`, hängt den variablen Parameter an und reicht den
   String an `FUN_080b1904` weiter. Der Wrapper bei `0x08058c44` nimmt sein
   fünftes Stackargument, baut daraus ein Stringobjekt und ruft
   `FUN_0807c380` auf. Diese Funktion extrahiert einen Dateinamen-Basename.
   `FUN_08220abc` verarbeitet den Sonderfall für die aktuelle
   On-The-Go-Playlist. Die Konstanten dekodieren zu
   `CurrentOnTheGoPlaylist.plist` und `iPod_Control\\iTunes\\`.

2. **Der Fehlerpfad kann im synthetischen QEMU-Präfix eine dateinamenabhängige
   ARM-Verzweigung erreichen.** Auf dem ARM1176-Modell führt der Erfolgszustand
   `N=0,V=0` bei `LDCLPL` an Pfadoffset `+0x10` zu Undefined Instruction.
   Unter künstlich gesetzten Fehlerflags `N=1,V=0` wird diese Instruktion
   übersprungen; ein ASCII-Suffix führt zum kontrollierten UDF-Testziel. Ein
   UTF-8-Suffix kann einen rückwärts gerichteten `BMI` bilden. Das belegt die
   Instruktionsarithmetik des Präfixes in QEMU, nicht die Register- und
   Flagwerte eines echten OSOS-Laufs.

3. **Der UTF-8-Decoder kann zwei- und drei-Byte-Sequenzen lesen, aber die
   reale Eingabeerhaltung ist offen.** `FUN_0827f2a0` dekodiert 2- und
   3-Byte-Folgen, ohne eine vollständige UTF-8-Validierung zu zeigen. Ob der
   FAT-LFN-Pfad die dafür nötigen Bytes in genau diesem Callback erhält und
   wie die iPod-Software Dateinamen normalisiert, wurde nicht verifiziert.

4. **Ein Testzweig erreicht unveränderten OSOS-Code, aber nur synthetisch.**
   QEMU lud das Runtime-Abbild bei `0x08000000`; bei eigens gewähltem
   Pfadpuffer `0x0a16e928` sprang der konstruierte `BMI` nach `0x0818ece0`.
   Die reale Funktion schreibt `1` nach `DAT_0818ecf8[1]`, `0` nach
   `DAT_0818ecf8[0]` und kehrt mit `BX LR` zurück. Das ist kein Nachweis
   beliebiger Codeausführung. Die Adresse des echten Pfadpuffers wurde nicht
   gemessen.

5. **Die erreichbare Zielspanne bleibt ein Problem.** Druckbare VFAT-sichere
   ASCII-Zeichen können laut Rechenlauf von der Heap-Untergrenze aus nur Ziele
   `0x0969d300..0x0adf4874` bilden; sie überschneiden den vorhandenen Rockbox-
   Loadertext bei `0x09000000` und dessen BSS nicht direkt. UTF-8 kann
   rechnerisch andere Ziele bilden; der Loader wird aber nicht nachweislich an
   der dafür nötigen Adresse gehalten oder über diesen Callback geladen. Die
   konkreten Pufferadressen im Bericht sind hypothetische Lösungen der
   Branchgleichung, keine Heapmessung.

6. **Der reale `r4`-Wert ist kein frei gewählter kleiner Pointer.** Im
   erkannten Aufrufer `FUN_08213400` wird `r4` an `0x08213418` aus
   `FUN_080b0cb6()` geladen. Diese Funktion baut den festen Pfad
   `iPod_Control\\iTunes\\iTunesDB` und übergibt ihn an `FUN_08270164`; der
   Parser initialisiert sein Ergebnis zunächst auf null und schreibt bei
   erfolgreicher Datumsverarbeitung einen aus Kalenderfeldern berechneten
   Sekundenwert in das Ergebnis. Der Aufrufer führt eine bedingte
   Zeitzonenkorrektur erst **nach** `FUN_080b1904` aus; wenn dessen gespeicherte
   Rücksprungadresse überschrieben ist, erreicht der Kontrollfluss diese
   Korrektur nicht. Daher ist `r4` bei der fehlerhaften Rückkehr der
   unbereinigte iTunesDB-bezogene Datums-/Zeitwert, bei Parserfehler vermutlich
   null.
   Das konkrete Gerätedatum und der reale Fehlerstatus wurden nicht gelesen.

7. **Der Präfix enthält davor einen zusätzlichen speicherabhängigen Zugriff.**
   Bei Pfadoffset `+0x0c` dekodiert das erste Wort zu
   `LDRBVC r6,[r4,#-0x95c]`; `LDCLPL` folgt bei `+0x10`. Die bekannte
   identitätsabgebildete OSOS-DRAM-Spanne ist
   `0x08000000–0x0bffffff`. Damit liegt die Ladeadresse nur dann in diesem
   bekannten Fenster, wenn `r4` im halb offenen Bereich
   `0x0800095c–0x0c00095c` liegt. Als Unix-Sekunden entspricht das ungefähr
   1974-04-03 11:22:04 bis vor 1976-05-19 04:43:08 UTC. Ein aktueller Wert und
   auch der Nullwert adressieren außerhalb dieses DRAM-Fensters. Das beweist
   noch keinen Absturz: MMU-Abbildungen, Busantwort und Fehlerbehandlung des
   S5L8730 an dieser Adresse sind nicht festgestellt.

8. **Der echte Returnpfad führt den `LDRBVC` aus.** Bei diesem Call sind der
   Parser-Ausgabezeiger nicht null und `param_3=0`. Der Parser vergleicht
   `param_3` mit null, wodurch `V=0` wird; die untersuchten direkten
   Rückgabepfade und der `FUN_080b1904`-Epilog ändern das nicht. Damit ist der
   `LDRBVC` für diese Pfade nicht bloß eine frei erfundene Flagannahme. Der
   ausführlichere MMU-/Data-Abort-Abgleich steht in
   `OSOS-iTunes-prefix-data-abort-followup-2026-10-31.md`.

## Erreichbarkeit und Bewertung

`FUN_08037746` registriert die Playlist-Callbacks und liegt in der
Controller-VTable ab `0x084f7558` bei Slot `+0xb4`. Die erkannten Referenzen
zeigen diesen Funktionszeiger in der Tabelle, aber keinen direkten Codecaller.
Der erneute Ghidra-Scan fand 159 erkannte `LDR`-Zugriffe mit Offset `0xb4` in
70 Funktionen; die Decompilierung dieser Funktionen löste keinen passenden
indirekten Aufruf des Playlist-Callbacks auf. Das schließt nicht erkannte,
transient dekodierte oder anders berechnete Dispatchpfade nicht aus.

Damit sind derzeit **kein echter Trigger beim Start, keine beliebige
Codeausführung und kein Rockbox-Handoff** belegt. Der QEMU-Test setzt Register,
Flags, Pfadpufferposition und teils RAM-Speicherinhalt künstlich. QEMU emuliert
hier ARM1176/versatilepb, nicht den S5L8730. Insbesondere sagt der QEMU-Fehler
bei `LDCLPL` nichts Abschließendes über den möglicherweise kundenspezifischen
Coprocessorpfad des iPod-Chips aus. Zwei ergänzende QEMU-Fälle mit einem
synthetischen 2010-Unixzeitwert und mit `r4=0` erreichten weiterhin den
kontrollierten `BMI`-Testpunkt: `versatilepb` ignoriert die unzugewiesenen
Reads. Diese Ergebnisse bestätigen gerade nicht, dass der iPod den Zugriff
überlebt; der Harness bildet dessen MMU und Bus nicht nach.

## Dauerhafte Belege

- QEMU-Präfix: `evidence/itunes-partial-lr-2026-10-31/qemu-prefix-reachability-20261031/`
- Reales Runtime-BX-LR-Gadget: `evidence/itunes-partial-lr-2026-10-31/qemu-runtime-bx-lr-20261031/`
- Callback-Aufrufkettenquery: `evidence/itunes-partial-lr-2026-10-31/dispatch-followup-20261031/`
- Herkunft von `r4`/`r5`, Parser-Rückgaben und Konstanten: `evidence/itunes-partial-lr-2026-10-31/prefix-state-followup-20261031/`
- Read-only-Ghidra-Quellabfragen zu Wrappern, Stringaufbau, Konstanten und UTF-8 liegen in `evidence/itunes-partial-lr-2026-10-31/qemu-prefix-reachability-20261031/`.
- Vorherige Stack- und Heapanalyse: `OSOS-iTunes-partial-lr-target-gadget-audit-followup-2026-10-31.md`.

## Nächste Schritte

1. Die konkrete MainApp-/Controller-Lifecycle-Dispatchroutine suchen, die Slot
   `+0xb4` auf dem Objekt mit VTable `0x084f7558` aufruft; dabei unbekannte
   Thumb-Funktionen und indirekte Objektübergaben getrennt verfolgen.
2. Prüfen, ob der S5L8730/MMU den durch `r4-0x95c` erzeugten Zugriff bei
   aktuellem iTunesDB-Datumswert oder Parserfehler abfängt; die QEMU-Probe ist
   dafür ungeeignet. Dazu müssen zuvor MMU-Kontext und etwaige Bus-Fault-Handler
   aus dem Runtime-Abbild nachvollzogen werden.
3. `N` und den genauen Parserstatus bis zur fehlerhaften Rückkehr trennen; `V=0`
   ist für die untersuchten echten Returnpfade belegt. Zusätzlich die mögliche
   spätere Änderung der L1-Tabelle vor dem Callback begrenzen.
4. Den FAT-LFN-Pfad bis zum Iterator-Callback im Offline-Modell schließen,
   einschließlich der realen UTF-8-Konvertierung.
5. Erst danach lässt sich bewerten, ob der Kandidat für einen Gerätetest
   taugt. Aktuell wurde keiner ausgeführt.

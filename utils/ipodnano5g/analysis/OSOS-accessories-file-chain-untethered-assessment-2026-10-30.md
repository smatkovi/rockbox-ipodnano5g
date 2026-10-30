# `accessories.reg`-Kandidat als dateibasierter Rockbox-Startpfad

Stand: 30.10.2026. Ausschließlich Offline-Prüfung vorhandener Ghidra-, FAT-,
QEMU- und Build-Artefakte. Kein Geräte-/USB-/DFU-Zugriff, kein Neustart und
keine NAND-/NOR-/Firmware-Schreib- oder Löschoperation.

## Ergebnis

Der stärkste derzeitige Persistenzkandidat ist der automatische OSOS-Parser
für `iPod_Control/Device/accessories.reg`. Eine lokale 704-Byte-Datei bildet
einen ROP-Kandidaten ab, der anschließend `/BOOT.BIN` öffnen, `0x10f80` Byte
nach `0x09000000` lesen und dorthin springen soll. Der lokale Rockbox-
Bootloader hat genau diese Dateigröße und diesen ELF-Einstieg. Wenn dieser
Kontrollfluss auf dem Gerät funktioniert und die benötigten FAT-Dateien
vorhanden sind, wäre dies ein dateibasierter OSOS→Rockbox-Pfad, der keine
Änderung an NAND, NOR oder signierten Firmware-Images voraussetzt.

Das ist noch kein bestätigter Exploit oder untethered Boot: Die QEMU-Rehosts
verwenden synthetische Stream-/VFS-/Providerzustände und einen Loader-Sentinel.
Der erfolgreiche automatische FAT-Open, das Laden der echten Bootloaderbytes,
die Gerätestacklage und der Sprung in den Bootloader wurden nicht beobachtet.

## Verifizierte Kette und Artefakte

1. Der MainApp-Parser `FUN_0802c3c4` öffnet statisch
   `iPod_Control/Device/accessories.reg` über `FUN_082721f0(..., 0)` und
   verwendet damit VFS-Slot 0. Der überlange `0x44`-Datensatz liest laut
   Originalparser-Rehost `0x284` Byte in den 256-Byte-Stackpuffer; der
   `max_length=0x100`-Parameter von `FUN_08039048` begrenzt diesen Read nicht.
2. Die Startupanalyse verfolgt den ATA-Worker-Queue-4-Event 0 zu
   `DeviceDiscovery` und von dort zu `FUN_08000a10(r5, 0)`. Bei erfolgreichem
   MBR-/Partitionsparse legt dieser Pfad statisch den FAT-Provider in Slot 0
   ab. Scheduling, Queuezustellung und erfolgreicher MBR-Read bleiben
   dynamisch unbestätigt.
3. Der Kandidat
   `evidence/accessories-rop-2026-10-29/candidate_accessories_reg_unexecuted.bin`
   ist 704 Byte groß, enthält das `0x44`-Feld mit Länge `0x284` und die
   Pfadbytes `/BOOT.BIN\0`. SHA-256:
   `7045ca2fe6a5f2660a815bdd182ff015691d90991ddc6f023972affcbd54e851`.
4. Der Kandidat setzt als geplanten Folgeschritt Read-Größe `0x10f80`, Ziel
   `0x09000000` und abschließenden Sprung über den Thumb-Trampolin.
   `build-n5g-blramdisk/bootloader.elf` bestätigt mit `readelf` Entry
   `0x09000000`, ein erstes LOAD-Segment derselben Größe `0x10f80` und BSS ab
   `0x09100000`. Die passende lokale Binärdatei hat SHA-256
   `09b2dc3ff4940855b175508ce817c5f913798f3d7b2ba7669edef3427e224d03`.
5. Der Rockbox-Bootloader enthält im lokalen Quell-/Buildpfad bei gesperrtem
   Hold einen Rückfall auf signiertes OSOS. Dadurch könnte derselbe
   Dateieinstieg die Hold-Anforderung berücksichtigen, falls der Loader
   tatsächlich erreicht wird.

Die genauen Ghidra- und Rehostgrenzen stehen in:

- `OSOS-accessories-full-path-reachability-followup-2026-10-29.md`
- `OSOS-accessories-real-volume-LBA-rehost-followup-2026-10-30.md`
- `OSOS-accessories-ROP-gadget-disassembly-followup-2026-10-28.md`
- `OSOS-accessories-loader-path-lfn-followup-2026-10-28.md`
- `evidence/rtos-task-order-2026-10-29/OSOS_runtime_ata_worker_queue4_startup_followup_20261030.txt`
- `evidence/accessories-rop-2026-10-29/OSOS_accessories_full_parser_rehost_20261029.md`

## Open-Modus und Providerdispatch

Die Ghidra-Listings schließen für diesen Aufruf die Übergabeparameter enger:

1. `FUN_082721f0(..., param_3=0, ...)` ruft `FUN_0827ea84` mit dem
   Wahrheitswert `param_3==0` auf.
2. `FUN_0827ea84` übergibt diesen als `1` an `FUN_0819878c`. Dort wird der
   Wert an Streamoffset `+0x14` gespeichert: Das Listing bei `0x081987ae`
   schreibt ihn relativ zum temporären Unterobjekt `+8`; dessen Basis ist
   `Stream+0x0c`.
3. `FUN_08224970` verwendet diesen Bytewert beim Provider-VTable-Aufruf an
   Slot `+0x14`. Der Slot-0-Provider stammt beim erfolgreichen
   DeviceDiscovery-/MBR-Pfad aus `FUN_08110e30`.
4. In `FUN_0812a870` wählt ein nichtnull Modus die Flags `0` und `0x80`.
   Der Providerkonstruktor setzt sein Cachefeld `+0x60` zuerst auf null;
   damit nimmt der frische Provider standardmäßig `FUN_081382b6` und dessen
   Pfad über `FUN_081382c2`.
5. `FUN_081382c2` splittet den Pfad, löst das Elternverzeichnis über
   `FUN_081fdb38` auf und sucht den letzten Namen über
   `FUN_0814f238`/`FUN_08158b64`. Das ist konsistent mit den bereits
   rehosteten physischen LFN-Slots für `iPod_Control`, `Device` und
   `accessories.reg`.

Damit ist der statische Open-Dispatch ein Read-Open über Slot 0. Der
`FUN_0814f238`-Scanner-Rehost bestätigt die betreffenden Eintragsnamen; die
separaten FAT-Rehosts bestätigen den EOC-Eintrag und die Daten-LBA. Diese
Bausteine wurden noch nicht in einem Lauf mit dem echten
`FUN_082721f0`→Provider-Open→Handle-Aufbau verbunden. Die Bedingungen in
`FUN_081382c2` für einen aktiven Mount/Directory-Handle und die Übergabe eines
echten File-Objekts bleiben daher das entscheidende dynamische Loch. Für den
zweiten ROP-Open ist `/BOOT.BIN` ein kurzer Root-Pfad ohne LFN; der
gespeicherte Root-Dump enthält diesen Eintrag nicht.

## Rootziel und RAM-Überlappung

Die absolute Pfadauflösung ist statisch nachvollziehbar: `FUN_081fdb38`
erkennt `/` als Wurzelpräfix und holt den Root-Directory-Handle über
`FUN_082014b6` direkt vom FAT-Provider. Danach wird `BOOT.BIN` als letzte
Komponente im Root-Verzeichnis gesucht. Der ROP-Open hängt damit nicht vom
aktuellen Arbeitsverzeichnis ab, benötigt aber einen tatsächlich vorhandenen
Root-Eintrag; in der gespeicherten Root-Seite vom 29.10. fehlt er.

Zusätzlich liegt das geplante Loadziel im von OSOS verwalteten Heap. Die
vorhandene Heaprechnung setzt dessen Bereich auf
`0x08e54e4c..0x0bba5ee0`; das Bootloader-LOAD-Segment belegt
`0x09000000..0x09013780`, und die separat genullte BSS liegt bei
`0x09100000..0x0919fd00`. Die Adressen sind schreibbar und ausführbar, aber
keine freie Reservierung: ein Dateiread dorthin kann lebende OSOS-Heapobjekte
überschreiben. Ob dabei der aktive FAT-Provider, Cache oder File-Handle
getroffen wird, ist aus dem Heapgrenzennachweis nicht abzuleiten. Ein
Einweg-Sprung könnte nur funktionieren, wenn der gesamte Read bis zum Ende
überlebt und der Loader danach keine beschädigten OSOS-Strukturen mehr nutzt.
Belege: `OSOS-heap-and-rockbox-handoff-2026-10-25.md` und
`evidence/accessories-rockbox-entry-2026-10-30/bootloader_elf_layout_20261030.txt`.

Die alte Allocatoranalyse grenzt das Risiko ein, beseitigt es aber nicht: Der
Allocator zerlegt einen freien Block von dessen hoher Adresse her. Unter dem
vereinfachten Modell einer einzigen unverfragmentierten Region müsste er etwa
42,0 MiB vergeben haben, bevor die Loader-BSS-Endadresse erreicht wird, und
43,6 MiB, bevor die Code-/Stackregion erreicht wird. Daraus folgt keine
Live-Belegung und kein Sicherheitsnachweis. Der echte FAT-Datei-Read wird über
`FUN_0812ac00` in begrenzte Teilreads zerlegt und `FUN_0814346c` kopiert die
Cachebytes jeweils direkt in den caller-supplied Zielpuffer. Der alte
Stream/FAT-Rehost hat diese Daten-/Cache- und ATA-Abhängigkeiten noch gestubbt;
ein Read in den Loaderzielbereich mit realem OSOS-Heapzustand ist also offen.
Beleg: `evidence/accessories-rop-2026-10-29/OSOS_accessories_loader_heap_threshold_20261029.txt`
und `OSOS_accessories_fat_read_deep_decompile_20261029.log`.

## Eingabe- und Dateizustand der gespeicherten Aufnahmen

Der read-only FAT-Dump vom 29.10. zeigt `accessories.reg` bei Directory-Slot
31, Größe 69 Byte, Attribut `0x20` (Archive) und Startcluster 179788. Der
gesicherte 69-Byte-Inhalt hat SHA-256
`b7203385b92dc4b3df094d0d0889b0f48dbd6766a687f54fa874d0c5f4e48854` und
enthält den normalen String `Pedometer`; der Kandidat wurde nicht auf das
Gerät geschrieben.

In der Root-Aufnahme vom 29.10. fehlt `BOOT.BIN`. Eine Verzeichnisaufnahme vom
26.10. listet unter `.rockbox` `rockbox.ipod` und `n5g-ramdisk.img`, aber kein
`bootloader.bin`. Der lokale Backupordner vom 24.10. enthält `rockbox.ipod`,
jedoch kein `n5g-ramdisk.img`. Das sind Aufnahmen verschiedener Zeitpunkte;
keine davon belegt den aktuellen Gerätezustand.

## Sicherheitsbewertung

- **Eingabe bei normalem Kaltstart:** statisch plausibel; kein Geräte-Trace.
- **Speicherkorruption/Kontrollfluss:** im synthetischen QEMU-Rehost bis zum
  Loader-Sentinel gezeigt; auf Hardware nicht bestätigt.
- **Datei-only-Persistenz ohne Flash:** als Konzept plausibel, sofern die
  manipulierte Registry-Datei und `/BOOT.BIN` auf dem Datenvolume liegen.
- **Untethered Rockbox-Boot:** nicht erreicht oder bestätigt.
- **Signaturbypass/Apple-Privatschlüssel:** hierfür nicht erforderlich und
  weiterhin weder gefunden noch abgeleitet.

## Nächste Offline-Schritte

1. Den in `FUN_081382c2` offenen Mount-/Directory-Handlezustand mit dem
   Startup-Provider verbinden und den Openpfad ohne vorgefüllte
   Stream-/Handlefelder rehosten.
2. Den Root-Scan für `/BOOT.BIN` mit einem synthetischen FAT-Verzeichniseintrag
   und dem echten `bootloader.bin` verbinden; prüfen, ob der vollständige Read
   den Eintritt bei `0x09000000` erreicht. Das bleibt ein Emulatorbefund.
3. Für den bestätigten Heap-Überlappungsbereich `0x09000000..0x09013780` den
   Teilreadablauf mit einem realistischen OSOS-Allocator-/Cachezustand
   rehosten. Zusätzlich prüfen, welche OSOS-Heapbereiche der Loader beim
   BSS-Init `0x09100000..0x0919fd00` überschreibt. Die bisherige
   Allocatorrechnung verrät keine Live-Belegung.
4. Erst wenn die Offlinekette ohne Loader-/Open-Stubs trägt, den reversiblen
   Test auf dem FAT-Datenvolume planen. Dieser Bericht veranlasst keine
   Geräte- oder Flashaktion.

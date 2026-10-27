# OSOS-Device-Dateien: Preferences, alarms und SysInfo

Stand: 27.10.2026. Statische Ghidra-Auswertung des Runtime-Mappings
`/tmp/osos_runtime_dram_20261025.bin` sowie read-only Inventur des aktuell
angeschlossenen Geräts. Es gab keine Dateiänderung, keinen Neustart und keine
DFU-, NAND-, NOR- oder Firmwareaktion.

## Aktueller Gerätezustand

USB meldet `05ac:1265` (iPod nano 5G im Massenspeicher-Modus), nicht DFU.
`/dev/sda1` trägt das Label `SEBIPOD` und ist unter `/tmp/ipod-current-ro` mit
`ro,nosuid,nodev,noexec` eingehängt. Vorhanden sind `Device/Preferences`
(2.960 Byte), `Device/alarms` (8 Byte) und `Device/SysInfo` (48 Byte). Die
Dateiinhalte von Preferences und SysInfo wurden nicht in den Bericht
übernommen.

## Preferences

Der feste Pfad `iPod_Control/Device/Preferences` wird von `FUN_081533c0`
verarbeitet. Der Einstieg prüft zunächst `FUN_08264e24` sowie zwei globale
Zustände (`FUN_081a8950`, `FUN_0815ab10`). Nur wenn alle den Ladezweig
freigeben, kopiert `FUN_08193d44` den konstanten Pfad in den 258-Byte-Stack-
Puffer und erzeugt danach ein Objekt der Größe `0xb90`. `FUN_08264e74` öffnet
den zugehörigen Stream; `FUN_0824d560` delegiert das Lesen über
`FUN_0819888c` an `FUN_0825985c`.

`FUN_0825985c` ist ein generischer Stream-Read-Pfad. Die untersuchte Kette
übernimmt die dateigesteuerte Länge nicht als Stack-Kopiergröße. Für diese
Preferences-Leseroute ist daher bislang kein speicherkorruptierender Fehler
belegt. Das ist keine vollständige Prüfung aller nachgelagerten
Preferences-Callbacks.

`FUN_081533c0` wird nur bei gesetztem Statusbyte über `FUN_0814870c`
aufgerufen. `FUN_0814870c` wird von `FUN_0825da88` aufgerufen; direkte
Aufrufer von `FUN_0825da88` sind `FUN_08058a6c`, `FUN_08251624` und
`FUN_0835ed24`. Damit ist der Parser statisch erreichbar, aber ein normaler
Kaltstart mit gesetzter Bedingung ist nicht nachgewiesen.

## Alarms

`FUN_08260ec8(param, 0)` öffnet `iPod_Control/Device/alarms` und liest
Datensätze mit Tag `0x05` bis zum Endtag `0xc000003a`. Unbekannte Tags gehen an
den rekursiven Skip-Parser `FUN_0826dca0`, der schon beim separaten
`Device/PlayCounts`-Pfad als möglicher Stackerschöpfungspfad dokumentiert ist.
Das belegt hier einen bedingten Verfügbarkeitskandidaten, keine kontrollierte
Rücksprungadresse oder Codeausführung.

Der Lese-Modus wird von `FUN_0803930c` aufgerufen. Dessen einziger gefundener
Codeaufrufer liegt bei `0x08028d00` in einem nicht als Funktion markierten
Thumb-Block ab `0x08028ce8`. Für `0x08028ce9` gibt es einen Dateneintrag bei
`0x084f970c`; der Konsument der umgebenden Tabelle und deren Aufrufbedingung
sind noch nicht aufgelöst. Der direkte Pfad ist daher kein belegter
Kaltstart-Trigger.

Der andere Aufruf aus `FUN_0825da88` läuft über `FUN_0814874e` mit Modus `1`
und schreibt den aktuellen Alarmzustand. Er importiert die Datei nicht.
Die aktuelle 8-Byte-Datei enthält ein leeres `0x3a`-Containerpaar
(`3a 00 00 40 3a 00 00 c0`) und erreicht keine tiefe unbekannte
Verschachtelung.

## SysInfo und offene Punkte

`FUN_0802638c` verwendet den konstanten Pfad `iPod_Control/Device/SysInfo`
und richtet einen `0x400`-Byte-Stream ein. Die Ghidra-Referenzsuche fand für
diese Funktion keinen direkten Codeaufrufer. Automatisches Lesen beim
Kaltstart oder ein durch den Dateiinhalt erreichbarer unsicherer Schreibpfad
sind damit nicht belegt.

Die nächste statische Arbeit ist die Dispatch-Tabelle um `0x084f970c` bis zu
ihrem Laufzeitkonsumenten zu verfolgen und zu klären, ob der Callback bei
`0x08028ce8` vor oder während eines normalen Kaltstarts läuft. Für den
`accessories.reg`-Stackfehler bleibt zusätzlich der erfolgreiche FAT-LFN-
Pfadauflauf offen. Ein Gerätetest würde einen gezielt geänderten Datenträger
und einen OSOS-Neustart erfordern; beides wurde in diesem Durchlauf nicht
ausgeführt.

Rohbelege:

- `/tmp/OSOS_sysinfo_preferences_alarms_analysis_20261027.txt`
- `/tmp/OSOS_device_config_path_parents_20261027.txt`
- `/tmp/OSOS_preferences_file_helper_audit_20261027.txt`
- `/tmp/OSOS_preferences_parser_followup_20261027.txt`
- `/tmp/OSOS_preferences_config_parser_core_20261027.txt`
- `/tmp/OSOS_device_config_callers_20261027.txt`

## Nachtrag: Alarm-Callback im Runtime-Dispatch (27.10.2026)

Die bislang offene Alarm-Aufrufspur wurde im Runtime-Mapping
`/tmp/N5G_OSOS_runtime_analysis/N5G_OSOS_runtime` weiterverfolgt. Der
32-Bit-Wert an `0x084f970c` ist dort `0x08028ce9`, also der Thumb-Zeiger auf
`thumb_8028ce8`. Die Funktion setzt kurzzeitig ein Statusbyte bei
`param_1+0x2a1`, löscht `param_1+0x2a4` und ruft bei `0x08028d00`
`FUN_0803930c(param_2)` auf.

`FUN_0803930c` erreicht `FUN_0804b394`; diese Funktion ruft
`FUN_08260ec8(param, 0)` auf. Modus 0 öffnet
`iPod_Control/Device/alarms` zum Lesen. Unbekannte Tags werden an den
rekursiven Skip-Parser `FUN_0826dca0` gegeben. Der zuvor dokumentierte
Stackerschöpfungskandidat ist damit an einen konkreten Runtime-Callback
gebunden.

Die Nachbareinträge der Dispatch-Tabelle zeigen Kalenderkontext:
`thumb_8028e98` registriert über `FUN_081a79aa` unter anderem
`TSilverCalendarCntlr_CalendarMenu`, `MonthViewer`, `DayViewer`,
`EventViewer`, `ToDoList`, `ToDoDispatcher` und `Alarm`. `thumb_8029030`
initialisiert Controller-Zustand. Das stützt die Einordnung als
Kalender-/Controller-Eventpfad. Es ist eine statische Kontextinferenz, kein
Beweis, dass der Alarm-Callback beim normalen Kaltstart ausgeführt wird.

Der Runtime-Referenzlauf findet keinen direkten Code-Xref auf
`0x084f96c0`, `0x084f970c` oder die Tabelleneinträge. Der Consumer der Tabelle,
die Bedingung für diesen Event und eine automatische Kaltstarterreichbarkeit
bleiben offen. Die in diesem Nachtrag untersuchten Funktionen stammen aus dem
Runtime-Mapping; gleichnamige Adressen im separaten Full-Body-Projekt können
andere Bytes enthalten und wurden für diese Zuordnung nicht verwendet.

**Auswirkung:** Unbekannte oder tief verschachtelte Tags können beim Erreichen
des Alarm-Readers einen Stackerschöpfungs-/Verfügbarkeitsfehler auslösen. Eine
Kontrollflussübernahme, Codeausführung oder ein Rockbox-Handoff ist nicht
belegt. Für den untethered Boot fehlt weiterhin sowohl ein bestätigter
automatischer Trigger als auch eine sichere Übergabe an Rockbox.

Neue Read-only-Rohbelege:

- `/tmp/OSOS_runtime_alarm_callback_20261027.txt`
- `/tmp/OSOS_runtime_alarm_dispatch_table_words_20261027.txt`
- `/tmp/OSOS_runtime_alarm_sibling_08028d71_20261027.txt`
- `/tmp/OSOS_runtime_alarm_sibling_08028e21_20261027.txt`
- `/tmp/OSOS_runtime_alarm_sibling_08028e99_20261027.txt`
- `/tmp/OSOS_runtime_alarm_sibling_08029031_20261027.txt`
- `/tmp/OSOS_runtime_alarm_sibling_08029065_20261027.txt`
- `/tmp/OSOS_runtime_calendar_controller_helpers_20261027.txt`

Keine Geräteabfrage, kein Neustart und kein Flash-/NAND-/NOR-Zugriff in
diesem Nachtrag.

## Nachtrag: Alarm-Stringfeld und Preferences-Puffer (27.10.2026)

Die feste Preferences-Datei wird in einen neu angeforderten `0xb90`-Byte-
Heapblock gelesen. `FUN_0824d560` reicht genau diese feste Länge an den
generischen Streamreader weiter. Nach dem Read setzt der Caller nur ein
Statusbyte, schließt den Stream und gibt den Block frei. Ein expliziter
Nach-Read-Parser, Copy-back oder Callback ist im sichtbaren Pfad nicht
vorhanden. Vor dem Read ruft der Caller den externen Helper `FUN_0826d0f4`
mit dem Zustands- und Blockzeiger auf; dessen interne Semantik ist im
Runtime-Mapping nicht enthalten. Eine indirekte gemeinsame Nutzung des Blocks
kann deshalb nicht ausgeschlossen werden. Ein dateigesteuerter
Speicherfehler im sichtbaren Reader ist nicht belegt.

Im Alarm-Record-Parser `FUN_081c4b56` gibt es dagegen einen kleinen
Stack-Read-Kandidaten. Die Funktion reserviert `0x108` Byte und verwendet ab
`sp+4` einen 256-Byte-Puffer für Feld `0x3c`. `FUN_0822cc02` liest zuerst die
32-Bit-Länge, begrenzt den Read auf höchstens `0x100` Byte und schreibt keinen
Stringabschluss. Direkt danach ruft `FUN_081936ec` den Längenhelfer
`FUN_08196ac6` auf dem Puffer auf und übernimmt den so ermittelten C-String in
das Stringobjekt bei `record+0x20`.

Bei einem kürzeren Feld ohne NUL kann `strlen` daher nicht geschriebene Bytes
des lokalen Puffers lesen; `FUN_081936ec` kopiert sie anschließend in den
Heap-String. Der aktuelle Tag liegt bei `sp+0x104` und hat die niedrigen Bytes
`0x3c, 0x00`. Wenn zuvor im gesamten 256-Byte-Puffer kein NUL steht, endet
die Suche spätestens beim zweiten Byte dieses Tagworts. Damit reicht der
statische Read höchstens bis `sp+0x105`; gespeicherte Register und LR liegen
oberhalb davon und werden nicht erreicht. Der Pfad zeigt keine Stack-Schreib-
oder Rücksprungadresskontrolle.

Ein erfolgreich geparster Record wird über `FUN_0827eef4` in die Alarm-Liste
übernommen. Der Schreibmodus von `FUN_081c4b56` serialisiert Feld `0x3c`
wieder aus diesem Stringobjekt. Das macht eine begrenzte Offenlegung von
Stack-Restdaten in einer später gespeicherten Alarmdatei plausibel. Ob der
Callback im normalen Kaltstart läuft, der OSOS-Open den LFN-Pfad passiert und
die geänderten Bytes anschließend tatsächlich gespeichert und auslesbar
werden, ist nicht belegt. Das ist ein bedingter Informationsleck-Kandidat,
kein nachgewiesener Codeausführungspfad.

Neue Rohbelege:

- `/tmp/OSOS_alarm_record_parser_20261027.txt`
- `/tmp/OSOS_alarm_string_field_20261027.txt`
- `/tmp/OSOS_preferences_lifecycle_followup_20261027.txt`

## Nachtrag: gemeinsamer LFN-Openpfad (27.10.2026)

Der Alarm-Reader erzeugt den konstanten Pfad `iPod_Control/Device/alarms` und
öffnet ihn mit `FUN_082721f0`, also derselben Stream-API, deren FAT-Auflösung
im Zubehör-Registry-Audit untersucht wurde. Der Kurzname `DEVICE` passt zu
`Device` und `ALARMS` zu `alarms`; der Root-Bestandteil `iPod_Control` passt
jedoch nicht zum vorhandenen Alias `IPOD_C~1`. Der untersuchte Resolver
expandiert den 8.3-Alias im Fallback nicht und hat zusätzlich den
LFN-Zustandsfehler. Daher ist auch für diesen Alarm-Parser ein erfolgreicher
Open über den untersuchten FAT-Provider nicht belegt und statisch eher
blockiert.

Das gilt als Reachability-Einschränkung, keine Widerlegung des Parserbefunds:
die genaue Provider-Auswahl und ein alternativer Openpfad wurden für den
Alarm-Callback nicht dynamisch geprüft. Der bekannte Alarm-Stringread bleibt
ein begrenzter bedingter Stack-Restdaten-Kandidat; die rekursive Skip-Routine
bleibt ein bedingter Verfügbarkeitskandidat. Keiner davon belegt RCE oder
untethered Rockbox.

Belege: `/tmp/OSOS_accessories_lfn_name_fallback_20261027.txt`,
`/tmp/OSOS_accessories_open_dispatch_deep_20261027.txt` und die oben
aufgeführten Alarm-Parser-Rohbelege. Read-only-Ghidra; keine Geräteabfrage,
kein Neustart und keine Flash-/NAND-/NOR-Änderung.

Die Ghidra-Abfragen liefen mit `-readOnly -noanalysis`; kein Gerät wurde
abgefragt und es gab keine Datei-, NAND-, NOR- oder Flashänderung.

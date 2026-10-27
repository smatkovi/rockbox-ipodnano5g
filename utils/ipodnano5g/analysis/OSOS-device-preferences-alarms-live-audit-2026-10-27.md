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

# OSOS-Persistenzdateien: zusätzlicher Leser-Audit

Stand: 25.10.2026. Ausschließlich statische Offline-Analyse von
`osos_body.bin` im read-only-Ghidra-Projekt
`/tmp/N5G_OSOS_RTOS_analysis/N5G_OSOS_RTOS`. Kein Gerätezugriff, USB, DFU,
Neustart oder Flashzugriff.

## Ergebnis

Eine Schwachstelle in der laufenden, signierten OSOS-Software könnte
grundsätzlich einen PC-unabhängigen Rockbox-Start ermöglichen: Ein Exploit
müsste bei jedem Kaltstart durch eine persistente Datei automatisch ausgelöst
werden, Codeausführung erreichen und den vorhandenen Rockbox-Loader aus der
FAT-Partition in RAM starten. Das würde die Signaturprüfung der vorherigen
Bootstufen nicht umgehen. Für die bisher geprüften Kandidaten bleibt gerade
der wiederholbare automatische Trigger unbelegt.

Dieser Schritt hat zusätzliche OSOS-Dateipfade eingegrenzt:

- `iPod_Control/Device/alarms`: `FUN_0828f144` kann im Modus `param2 == 0`
  Datensätze laden. Der einzige gefundene direkte Aufrufer dieses Modus ist
  `FUN_08079610`, das von `FUN_08067588` aufgerufen wird. Für `FUN_08067588`
  wurde weder ein direkter Codeaufrufer noch ein gespeicherter Thumb-Zeiger
  `0x08067589` im OSOS-Abbild gefunden. Ein zusätzlicher Rohscan fand auch
  keine absoluten Thumb-Zeiger auf `0x08067589`, dessen Runtime-Adresse
  `0x0803930d` oder dessen Prefix-relokierte Adresse `0x2203930d` in den
  extrahierten IPSW-Segmenten und `Firmware.MSE`. Ein Scan des OSOS-Bodys nach
  einfachen 32-Bit-relativen Einträgen zu diesen Zielen blieb ebenfalls leer.
  Das schließt dynamisch erzeugte, anders kodierte oder nicht extrahierte
  Dispatches nicht aus; automatischer Kaltstart ist nicht belegt.
- `iPod_Control/Device/Users` und `.../PlayCounts`: `FUN_0828bd04` ruft die
  jeweiligen Routinen `FUN_081ddc3c` und `FUN_081dde48` mit `param2 == 1` auf.
  Dieser Modus serialisiert die internen Objektlisten in Dateien. Insbesondere
  der Aufruf aus dem MainApp-Setup `FUN_08086ce8` ist damit ein Schreibpfad,
  kein Nachweis eines automatischen Dateilese-/Parserpfads. Andere indirekte
  Aufrufer oder Modi bleiben gesondert zu prüfen.
- `iPod_Control/Device/iPod_Contacts.db`: `FUN_08277218` erstellt lazy einen
  kleinen Pfad-haltenden Heap-Eintrag für diese Datenbank. Die Funktion selbst
  parst keine Daten. Vier direkte Aufrufer wurden gefunden, ihre vollständige
  Erreichbarkeit und ein möglicher Parser dahinter wurden in diesem Schritt
  nicht untersucht.

Für den Alarm-Parser ist damit ein persistenter Eingabepfad belegt, aber keine
Kontrollflussübernahme. Ein bedingter Stack-OOB-Read-Kandidat ist jedoch
sichtbar: Für Feldtag `0x3c` liest `FUN_081f2dd2` über `FUN_0825ae7e` höchstens
`0x100` Byte in einen gleich großen Stackpuffer. Der Reader begrenzt zwar die
Länge, schreibt aber keinen NUL-Terminator. Danach ruft der Parser
`FUN_081c1968` auf; diese Funktion ermittelt die Länge über
`FUN_081c4d42`, eine unbeschränkte `strlen`-Schleife, und kopiert so viele
Bytes aus dem Puffer in das Stringziel. Ein 256-Byte-
Feld ohne NUL kann deshalb über das Pufferende hinaus Stackbytes lesen und
anschließend in den String übernehmen. Der sichtbare Pfad schreibt nicht über
das Zielobjekt hinaus, weil es mit der ermittelten Länge angelegt wird. Damit
ist derzeit nur ein möglicher OOB-Read/Stackdatenübertrag in ein internes
Objekt belegt, keine RCE oder Kontrollflussübernahme. Ob Tag `0x3c` in einer
realen Alarmdatei frei kontrollierbar ist, wurde nicht mit einer Fixture
geprüft.

## Belege

- `/tmp/OSOS_device_persistent_file_handlers_20261026.txt` – Alarm-, Users-,
  PlayCounts- und Contacts-Routinen.
- `/tmp/OSOS_device_alarms_context_20261026.txt` – direkte Alarm-Leser und
  Parserhelfer.
- `/tmp/OSOS_alarm_string_import_helper_20261026.txt` – `strlen`- und
  Stringkopierpfad für Alarmfeld `0x3c`.
- `/tmp/OSOS_device_file_service_roots_20261026.txt` – Aufrufer von
  `FUN_0828bd04`, einschließlich MainApp-Setup `FUN_08086ce8`.
- Read-only-Ghidra-Referenzläufe: direkte Referenzen auf
  `FUN_08079610`, `FUN_0828bd04` und die Datei-Wrapper; Rohresultate wurden
  während dieser Analyse über die Headless-Konsole ausgegeben.

Der separate, bereits bekannte ArtworkDB-Heap-Schreibfehler bleibt der
stärkste statische Speicherkorruptionskandidat. Seine automatische
Kaltstarterreichbarkeit und eine Kontrollflussübernahme sind weiterhin nicht
nachgewiesen. Das angeschlossene Gerät blieb unberührt und im bisherigen
U-Boot-Zustand; es wurden keine Boot-, Reset-, NAND-/NOR-Schreib- oder
-Löschaktionen ausgeführt.

## Nächste Offline-Schritte

1. Prüfen, ob Alarmfeld `0x3c` laut Format NUL-terminiert oder binär ist und
   welche Stackbytes bei maximaler Länge in das Stringobjekt gelangen.
2. Indirekte Registrierung bzw. externe Dispatch-Wurzel von
   `FUN_08067588` untersuchen.
3. Die vier Aufrufer von `FUN_08277218` bis zu einem möglichen
   Contacts-DB-Parser und dessen Startbedingungen verfolgen.
4. Den vorhandenen ArtworkDB- und Music-Loading-Task-Pfad weiter auf einen
   automatischen Kaltstarttrigger eingrenzen.

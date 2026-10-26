# OSOS-Reader `iPod_Control/Device/dst`: Überprüfung des 2-Byte-Schreibens

Stand: 26.10.2026. Read-only-Prüfung des Full-Body-OSOS-Abbilds in
`nano5g/ghidra-projects/N5G_OSOS_RTOS.gpr`. Keine Geräte-, USB-, DFU-, Boot-,
NAND-, NOR- oder Flashaktion.

## Ergebnis

Der Reader `FUN_080e08c0` schreibt die ersten zwei Bytes der persistenten Datei
`iPod_Control/Device/dst` in `0x08552970`. Das dort im OSOS-Abbild stehende
32-Bit-Wort ist `0x081543a7`, ein Thumb-Codezeiger-artiger Wert auf
`0x081543a6` innerhalb von `FUN_0815434c`. Das ist ein verdächtiger
dateigesteuerter Teil-Overwrite, aber **kein bestätigter Kontrollflussfehler**:
Die statisch gefundenen Verbraucher des zugehörigen globalen Zustands lesen
nur die Felder bei `+4` und `+8`. Für das überschriebene erste Wort wurde im
untersuchten Abbild kein statischer Lese- oder Aufrufpfad gefunden.

Außerdem ist kein normaler Kaltstartpfad bis zum Reader belegt. Selbst wenn
das erste Wort später genutzt würde, wären damit weder automatische
Ausnutzbarkeit noch Codeausführung oder ein Rockbox-Handoff nachgewiesen.

## Nachvollzogener Reader

`FUN_080e08c0` wird direkt aus `FUN_081da69c` bei `0x081da7fc` aufgerufen. Der
Reader öffnet `iPod_Control/Device/dst`; bei vorhandener Datei fordert er
zunächst einen 2-Byte-Read nach `0x08552970` an. Anschließend fordert er
höchstens `0xcd0` (3280) Bytes in den festen Puffer `0x087631c0` an und setzt
den aktiven Tabellenzeiger bei `0x08552978` auf diesen Puffer. Bei fehlender
Datei oder fehlgeschlagenem Tabellen-Read wird der Zeiger auf die
Standardtabelle `0x08552980` gesetzt. Die Stream-Read-Routine begrenzt die
tatsächliche Länge auf die verfügbaren Dateidaten.

Der Tabellenbereich umfasst `0xcd` (=205) Records zu je `0x10` Bytes. Die
geprüften Verbraucher iterieren maximal über diese 205 Records. Der aus einem
Record gelesene Switchindex läuft durch einen begrenzten Thumb-Dispatcher;
dieser begrenzt ungültige Werte auf den letzten Switchfall. In diesen Pfaden
ergibt sich kein Tabellenüberlauf und kein direkter Aufruf eines
dateikontrollierten Funktionszeigers.

## Bedeutung des überschriebenen Wortes

- Ghidra- und Rohdaten zeigen für `0x08552970` initial `0x081543a7`.
- Der bereinigte Thumb-Codeeintritt `0x081543a6` liegt innerhalb der Funktion
  `FUN_0815434c`, nicht an deren Funktionsanfang. Damit ist der Wert zwar
  codezeiger-artig, seine genaue Rolle im Objekt ist aber nicht bestimmt.
- Der Read-Call fordert nur zwei Bytes an; im Little-Endian-Layout kann er
  höchstens die unteren 16 Bits dieses Wortes ändern. Der Aufrufer verwendet
  den Rückgabewert dieses ersten Reads nicht.
- Eine Referenzabfrage auf `0x08552970` findet als Code-/Datenreferenz nur den
  Schreibparameter aus `FUN_080e08c0`. Eine Rohsuche nach dem Basiszeiger
  `0x08552970` findet sieben globale Pointer-Aliase. Deren auflösbare
  Codeverwendungen führen zu `FUN_080fa398`, `FUN_08123edc`, `FUN_08254724`,
  `FUN_0826fdb8`, `FUN_0826ff90`, `FUN_08273424` und `FUN_08285c70`. Die
  untersuchten Zugriffe lesen/schreiben Tabellenfelder bei `+4` oder `+8`,
  nicht das erste Wort bei `+0`.
- Das Ghidra-Memory-Block-Attribut für den betroffenen `ram`-Block lautet
  lesbar/schreibbar/ausführbar. Das ist eine Eigenschaft der lokalen
  Projektabbildung und belegt keine konkrete Laufzeit-MPU-Konfiguration des
  Geräts.

Ein berechneter Zugriff, ein nicht extrahiertes Modul oder eine dynamische
Registrierung kann durch die statischen Xrefs nicht vollständig ausgeschlossen
werden. Nach den aktuell auflösbaren OSOS-Verwendungen sieht das
überschriebene erste Wort jedoch ungenutzt aus.

## Erreichbarkeit beim Einschalten

Die direkten Aufrufer von `FUN_081da69c` sind `FUN_08053670` und
`FUN_081199ac`. `FUN_08053670` wird in der gespeicherten Code-Xref-Kette von
`FUN_08050d84` aufgerufen; der zuvor untersuchte Konstruktionspfad führt weiter
über `FUN_0804f224` zu `FUN_0804cb72`. Für `FUN_081199ac` wurde kein direkter
Code-Xref gefunden. Die Konstruktions-/Factory- bzw. Overlay-Registrierung zu
diesen Einstiegspunkten und ihre normale Kaltstart-Ausführung bleiben offen.
Der Readeraufruf ist daher statisch vorhanden, aber kein bestätigter
automatischer Boottrigger.

## Schlussfolgerung

`Device/dst` ist ein sinnvoller Prüfpunkt, weil eine persistente Datei zwei
Bytes in ein codezeiger-artiges Wort schreibt. Mit den bislang gefundenen
Verwendungen ist daraus aber weder eine nutzbare Speicherbeschädigung noch
eine Codeausführung ableitbar. Für einen untethered Rockbox-Start fehlen
weiterhin sowohl ein belegter Kaltstartpfad als auch ein belegter
Kontrollfluss-Handoff. Der Kandidat sollte als unbestätigte Teilkorruption,
nicht als Exploit, geführt werden.

## Rohbelege

- `/tmp/OSOS_device_dst_reader_20261026.txt`
- `/tmp/OSOS_dst_record_processing_20261026.txt`
- `/tmp/OSOS_stream_read_impl_20261026.txt`
- `/tmp/OSOS_dst_pointer_target_20261026.txt`
- Ghidra-Skripte: `nano5g/ghidra-logs/FindOSOSReferenceBatch.java`,
  `nano5g/ghidra-logs/AnalyzeOSOSFunctions.java`
- Die Abfragen liefen mit `-readOnly -noanalysis`; das Quellabbild und das
  Ghidra-Projekt wurden nicht geändert.

# Workout-Parser und Nano-5G-RAM-Bootloader: Folgeprüfung

Stand: 26.10.2026. Diese Prüfung war offline und statisch. Es gab keinen
Gerätezugriff, keine USB-/DFU-Aktion, keinen Neustart und keinen NAND-/NOR-
oder sonstigen Flashzugriff.

## Ergebnis

Der aktuelle Nano-5G-RAM-Bootloader lässt sich bauen und enthält die erwarteten
Pfade zurück zur signierten Apple-Firmware. Das belegt keinen untethered Start:
der vorhandene Startworkflow überträgt den Bootloader nur in RAM, und der
Nano-5G-NAND-Treiber ist im Build schreibgeschützt. In der zusätzlich
untersuchten Workout-XML-Spur ist kein Speicherfehler oder automatischer
Kaltstart-Trigger bestätigt.

## Frischer Bootloader-Build

`make -j16` in `build-n5g-blramdisk` wurde erfolgreich abgeschlossen. Die
erzeugten Dateien haben folgende SHA-256-Werte:

| Datei | SHA-256 |
| --- | --- |
| `build-n5g-blramdisk/bootloader.bin` | `09b2dc3ff4940855b175508ce817c5f913798f3d7b2ba7669edef3427e224d03` |
| `build-n5g-blramdisk/bootloader-ipodnano5g.ipod` | `833aeb7ef18bb874103e497a7aa9ebbc41baae6ca11d4edec9e00485d9ee7e6e` |

Die Disassemblierung von `bootloader.elf` bestätigt in `main`:

- Ist Hold gesperrt, ruft der Bootloader `nand_init()` auf und startet danach
  `launch_apple(APPLE_IMG_OSOS)`. Bei NAND-Initialisierungsfehler fällt er in
  die Boot-Fehleranzeige.
- Bei einem Storage-Fehler wird Hold erneut geprüft; bei gesperrtem Hold folgt
  derselbe Apple-OS-Pfad.
- Wenn keine FAT-Partition gefunden wird, ruft er `launch_apple(OSOS)` auf.
- Wenn `/.rockbox/rockbox.ipod` fehlt oder nicht ladbar ist, ruft er ebenfalls
  `launch_apple(OSOS)` auf.

`nm` listet im gebauten ELF `nand_init` und NAND-Lesefunktionen, aber keine
`nand_device_program`- oder `nand_device_erase`-Funktion. Dazu passt
`firmware/target/arm/s5l8702/ipodnano4g/nand-target.h`: `NAND_WRITABLE` wird
für `IPOD_NANO5G` nicht definiert. Das verhindert, dass dieser Rockbox-Treiber
den N5G-NAND beschreibt; es ist keine Aussage über Apples eigenen
NAND-Treiber.

Der vorhandene `utils/ipodnano5g/n5g-installed-boot.sh`-Workflow lädt U-Boot
und den Rockbox-Bootloader per wInd3x/YMODEM in RAM und springt dorthin. Er
schreibt keinen persistenten Bootloader. Daher bestätigen Build und
Disassemblierung nur die Fallback-Logik eines RAM-Bootloaders; weder der
Hold-Fallback noch ein Kaltstart wurden am Gerät geprüft.

## Workout-XML- und generischer Parserpfad

Im read-only-Ghidra-Projekt `/tmp/N5G_OSOS_RTOS_analysis/N5G_OSOS_RTOS.gpr`
wurde `FUN_081a3704` mitsamt den zuvor offenen Parserhelfern untersucht.
`FUN_081a3704` durchsucht `Trainer_Workouts_Empeds` nach
`preferences.xml` und `lastWorkout.xml`. Es gibt im analysierten OSOS-Body
keinen direkten Codeverweis auf diese Funktion. Der bereits dokumentierte
Rohscan fand außerdem keinen direkten absoluten oder 24-Bit-relativen
Funktionszeiger auf sie. Eine dynamische Overlay-/Factory-Registrierung bleibt
als Unsicherheit offen; ein automatischer Kaltstart-Aufruf ist nicht belegt.

Die interne Verarbeitung führt über `FUN_0827af50`, `FUN_082abe04` und
`FUN_081eedb2`. `FUN_081eedb2` fügt Einträge über `FUN_082e24d0` in eine
dynamische, sortierte Liste ein. Bei Platzmangel berechnet `FUN_082e24d0` eine
größere Kapazität und allokiert einen neuen Puffer; die geprüften Helfer zeigen
keinen festen Puffer, dessen Grenze unmittelbar durch XML-Daten überschrieben
wird. Die Kapazitätsarithmetik ist 32-bittig, aber ein Wrap würde eine
Vektorkapazität nahe der Adressraumgrenze voraussetzen; ein erreichbarer
Speicherfehler ist daraus nicht abgeleitet.

`FUN_0827af50` hat einen zweiten direkten Aufrufer, `FUN_0823fe0c`. Dieser
generische Pfad wird unter anderem aus Media-/Datensatz-Verarbeitung
aufgerufen. Die untersuchten Aufrufer liefern keinen Nachweis, dass dadurch
beim normalen Kaltstart eine vom Nutzer präparierte Datei geparst wird.
Daher ist auch diese zweite Verwendung kein bestätigter Boottrigger oder
Exploit.

Die Analyseauszüge liegen unter:

- `/tmp/OSOS_workout_deep_body_20261026.txt`
- `/tmp/OSOS_workout_parser_other_caller_20261026.txt`
- `/tmp/OSOS_generic_object_parser_callers_20261026.txt`
- `/tmp/OSOS_xml_other_reader_parents_20261026.txt`
- `/tmp/OSOS_workout_vector_helpers_20261026.txt`

Die Ghidra-Projekte wurden mit `-readOnly -noanalysis` geöffnet.

## Einordnung und nächste Schritte

Eine Laufzeitlücke in OSOS könnte theoretisch Rockbox aus persistentem
Dateispeicher in RAM starten, wenn ein verwertbarer Fehler nach jedem Kaltstart
automatisch erneut ausgelöst wird. Bisher fehlt weiterhin mindestens eines der
entscheidenden Glieder: ein bestätigter automatischer Dateieingang, eine
Kontrollflussübernahme und ein Startpfad, der den Rockbox-Payload beim nächsten
Kaltstart erneut erreicht. Eine einmalige Codeausführung in einer laufenden
iPod-Software würde für untethered Boot allein nicht genügen.

Als nächste Offline-Schritte bleiben die dynamische Factory-/Overlay-Quelle
des Workout-Scanners und die noch offenen Aufrufer des generischen
Media-Parsers. Die Bootloader-Fallbacks können erst am Gerät als Laufzeitpfad
bestätigt werden; bis dahin wird der bekannte RAM-/DFU-Workflow nicht
angestoßen.

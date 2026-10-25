# OSOS-BootTask und Task-Tabelle: Folgeanalyse (2026-10-25)

## Rahmen

Nur lokale statische Analyse. Kein USB-Zugriff, kein DFU, kein Neustart und kein NAND-/NOR-Schreib- oder Löschzugriff. Der analysierte Runtime-Dump `/tmp/osos_runtime_dram_20261025.bin` ist ein Mapping des OSOS-Bodys ab Dateioffset `0x2e27c` auf `0x08000000`, kein Live-RAM-Dump.

## BootTask-Dispatcher

`FUN_083534e8` ist der ARM-Einstieg, den der zuvor untersuchte Bootprefix über den indirekten Übergang bei `0x22003908` mit Ziel `0x083534e8` startet. Der BootTask prüft zuerst einen Kontextwert, setzt danach den Scheduler auf, ruft `FUN_08354b08` auf, verarbeitet anschließend die Task-Tabelle mit `FUN_0801c684` und initialisiert danach weitere Dienste über `FUN_08354ba8`.

`FUN_0801c684` liest die Tabellengrenzen und zwei Callback-Zeiger aus seinem Literalpool:

- Anfang `0x087600c0`
- Ende `0x08760250`
- Schrittweite `0x14` Byte, also 25 Datensätze
- Callback `0x0801d785` ruft `FUN_0801e2b4` auf
- Callback `0x0801d78d` ruft `FUN_0801e2d6` auf

Der erste Callback legt pro Datensatz einen Task an: Er speichert den erzeugten Handle an Offset `+0`, initialisiert Kontextdaten anhand des Worts bei `+0x10` und übergibt Werte aus `+0x4`, `+0x8` und `+0xc` an einen importierten Task-Create-Dienst. Der zweite Callback zerstört den Task anhand des gespeicherten Handles. `FUN_0801c642`, das unmittelbar davor im BootTask aufgerufen wird, ist im gespeicherten Runtime-Abbild nur `bx lr` und initialisiert diese Tabelle nicht.

Ghidras direkte Referenzen zeigen `FUN_083534e8` als einzigen direkten Aufrufer des Dispatchers. Die beiden Callback-Einstiege werden nur über die berechneten Aufrufe in `FUN_0801c684` erreicht. Die Tabelle selbst liegt außerhalb des gespeicherten OSOS-Bodys. Außerdem umfasst der zuvor identifizierte Startup-Nullungsbereich `0x086c43a8..0x08e54e4b` auch `0x087600c0..0x08760250`; die Datensätze sind somit nicht als bereits befüllte OSOS-Body-Daten nachgewiesen.

`FUN_08354b08` baut vor dem Dispatcher einen 0x20-Byte-Service-/Konfigurationsdatensatz auf. In seinem sichtbaren Code gibt es keinen direkten Store in die Task-Tabelle. `FUN_08354ba8` initialisiert weitere Dienste und endet nach mehreren bedingten Aufrufen in einem indirekten Sprung über `DAT_08218508` mit Argument `0x3d`. Die importierten SVC-/Overlay-Ziele und die Quelle der 25 Task-Datensätze sind im gespeicherten OSOS-Abbild nicht aufgelöst. Da der normale OSOS-Start diesen Dispatcher erreicht, müssen die benötigten Laufzeitdaten anderswo bereitgestellt werden; welcher Dienst oder welches Overlay das erledigt, ist eine offene Hypothese.

Ein exakter Scan der lokalen `Firmware.MSE` und der extrahierten Firmware-Segmente fand keinen gespeicherten Zeiger `0x087600c0`. Ein Treffer auf `0x08760250` liegt in `rsrc.bin` bei `0x6cc3b04` (derselbe Inhalt in `Firmware.MSE` bei `0x6f3eb04`); die umgebenden Bytes zeigen keine erkennbare Pointertabelle. Dieser isolierte Treffer belegt daher keine serialisierte OSOS-Task-Tabelle.

## Bedeutung für den Musik-/ArtworkDB-Pfad

Die Folgeanalyse löst den frühen Task-Dispatcher nicht bis zu den tatsächlichen Task-Einstiegen auf. Daher bleibt auch offen, ob ein dort angelegter Task beim normalen OSOS-Kaltstart automatisch die Media-/ArtworkDB-Factory abfragt. Der vorherige direkte Aufrufgraph ab `0x083534e8` erreichte 335 Funktionen, jedoch keinen bekannten Media- oder ArtworkDB-Einstieg; berechnete Aufrufe, Scheduler-Callbacks und externe Overlays begrenzen diese Aussage. Daraus folgt weder Nichterreichbarkeit noch eine bestätigte automatische ArtworkDB-Verarbeitung.

## Abgrenzung: wInd3x „CFW“

Der lokale `cmd/wInd3x/cmd_cfw.go`-Pfad `cfw run` fordert ein DFU-Gerät an, startet den Exploit, sendet ein defanged WTF und überträgt anschließend das ausgewählte Image über DFU. Der Code enthält in diesem Ablauf keinen NAND-/NOR-Schreibpfad. Die aktuelle Projekt-README beschreibt den CFW-Ablauf ebenfalls als `BootROM -> WTF, defanged (DFU) -> Modified RetailOS/U-Boot/... (DFU)` und erklärt den haxed-DFU-Zustand als bis zum nächsten Neustart temporär ([wInd3x README](https://github.com/freemyipod/wInd3x)). „CFW unterstützt“ ist daher hier kein Nachweis einer dauerhaften Installation.

## Reproduzierbare Exporte

Die zusätzlich erstellten Ghidra-Auszüge liegen außerhalb des Git-Arbeitsbaums:

- `/tmp/OSOS_boot_task_dispatch_followup.txt`
- `/tmp/OSOS_boot_task_services_followup.txt`
- `/tmp/OSOS_BootTask_callgraph.txt`
- `/tmp/OSOS_boot_table_end_refs.txt`

Analysiertes Projekt: `/tmp/N5G_OSOS_runtime_analysis/N5G_OSOS_runtime`.

## Ergebnis und nächste Offline-Schritte

Kein neuer Signatur-Bypass, kein persistenter OSOS-/Rockbox-Einstieg und keine kontrollierte Kontrollflussübernahme. Die nächste sinnvolle statische Spur ist die Zuordnung der importierten Bootprefix-/OSOS-SVC-Slots (`0x0820d53c`, `0x0820d544`, `0x0820d54c` und `0x08218508`) zu den geladenen Laufzeit-Overlays und deren Schreibzugriffen auf `0x087600c0..0x08760250`. Dafür muss die Rebind-/Overlay-Kette von Bootprefix und OSOS gemeinsam verfolgt werden.

Der `rb-n5g`-Arbeitsbaum war vor dieser Dokumentation sauber. Der separate lokale `wInd3x`-Checkout enthält bereits vorherige Änderungen und unversionierte Artefakte; er wurde nicht geändert.

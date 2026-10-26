# OSOS-BootTask und Task-Tabelle: Folgeanalyse (2026-10-25)

## Rahmen

Nur lokale statische Analyse. Kein USB-Zugriff, kein DFU, kein Neustart und kein NAND-/NOR-Schreib- oder Löschzugriff. Der analysierte Runtime-Dump `/tmp/osos_runtime_dram_20261025.bin` ist ein Mapping des OSOS-Bodys ab Dateioffset `0x2e27c` auf `0x08000000`, kein Live-RAM-Dump.

## BootTask-Dispatcher

`FUN_083534e8` ist der ARM-Einstieg, den der zuvor untersuchte Bootprefix über den indirekten Übergang bei `0x22003908` mit Ziel `0x083534e8` startet. Der BootTask prüft zuerst einen Kontextwert, setzt danach den Scheduler auf, ruft `FUN_08354b08` auf, verarbeitet anschließend die Task-Tabelle mit `FUN_0801c684` und initialisiert danach weitere Dienste über `FUN_08354ba8`.

`FUN_0801c684` liest die Tabellengrenzen und zwei Callback-Zeiger aus seinem Literalpool:

- Anfang `0x087600c0`
- Ende `0x08760250`
- Schrittweite `0x14` Byte, also 20 Datensätze (`0x190 / 0x14`)
- Callback `0x0801d785` ruft `FUN_0801e2b4` auf
- Callback `0x0801d78d` ruft `FUN_0801e2d6` auf

Der erste Callback legt pro Datensatz einen Task an: Er speichert den erzeugten Handle an Offset `+0`, initialisiert Kontextdaten anhand des Worts bei `+0x10` und übergibt Werte aus `+0x4`, `+0x8` und `+0xc` an einen importierten Task-Create-Dienst. Der zweite Callback zerstört den Task anhand des gespeicherten Handles. `FUN_0801c642`, das unmittelbar davor im BootTask aufgerufen wird, ist im gespeicherten Runtime-Abbild nur `bx lr` und initialisiert diese Tabelle nicht.

Ghidras direkte Referenzen zeigen `FUN_083534e8` als einzigen direkten Aufrufer des Dispatchers. Die beiden Callback-Einstiege werden nur über die berechneten Aufrufe in `FUN_0801c684` erreicht. Die Tabelle selbst liegt außerhalb des gespeicherten OSOS-Bodys. Außerdem umfasst der zuvor identifizierte Startup-Nullungsbereich `0x086c43a8..0x08e54e4b` auch `0x087600c0..0x08760250`; die Datensätze sind somit nicht als bereits befüllte OSOS-Body-Daten nachgewiesen.

`FUN_08354b08` baut vor dem Dispatcher einen 0x20-Byte-Service-/Konfigurationsdatensatz auf. In seinem sichtbaren Code gibt es keinen direkten Store in die Task-Tabelle. `FUN_08354ba8` initialisiert weitere Dienste und endet nach mehreren bedingten Aufrufen in einem indirekten Sprung über `DAT_08218508` mit Argument `0x3d`. Die Quelle der Task-Datensätze ist unten als Constructor in der relativen Constructor-Tabelle identifiziert; die externe Startkette zu dessen Runner bleibt offen.

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

Kein neuer Signatur-Bypass, kein persistenter OSOS-/Rockbox-Einstieg und keine kontrollierte Kontrollflussübernahme. Die nächste sinnvolle statische Spur ist die externe Start-/Rebind-Kette zu `FUN_08324af0` sowie die Zuordnung der importierten Bootprefix-/OSOS-SVC-Slots (`0x0820d53c`, `0x0820d544`, `0x0820d54c` und `0x08218508`) zu den geladenen Laufzeit-Overlays.

Der `rb-n5g`-Arbeitsbaum war vor dieser Dokumentation sauber. Der separate lokale `wInd3x`-Checkout enthält bereits vorherige Änderungen und unversionierte Artefakte; er wurde nicht geändert.

## Nachtrag: statische Task- und Stack-Metadaten (2026-10-25)

Korrektur zur Aussage, es gebe im OSOS-Body keinen gespeicherten Zeiger auf
`0x087600c0`: Der Zeiger ist in `osos_body.bin` vorhanden. Der Task-Table selbst
bleibt außerhalb des file-backed Images im Startup-Nullungsbereich; im Body
liegt aber ein Metadatenblock mit dem Zeiger und benachbarten Task-Einträgen.

- Datei `nano5g/osos_decrypted/osos_body.bin`, Offset `0x4222c` (Full-Body-VA
  `0x0804222c`, Runtime-VA `0x08013fb0`): Wort `0x087600c0`. Danach folgen
  Funktionszeiger und Namen, darunter `FirewireTask` (`0x08010d25`),
  `TouchwheelTask` (`0x08010d01`), `USBPowerSense` (`0x080005f1`),
  `DiskMgrTask` (`0x08010d5d`), `HoldSwitchTask` (`0x08017f31`),
  `DeviceDiscovery` (`0x08002151`), `USBAudioTask` (`0x22004fc1`) und
  `ChargeMgmtTask` (`0x08005a91`). `GraphicsManager` ist mit dem davorstehenden
  Zeiger `0x2200c0e0` verknüpft. Das belegt statische Task-Metadaten, aber noch
  nicht, welcher Startup-Dienst diesen Block auswertet.
- Die unmittelbar davor gespeicherten RAM-Adressen reichen von
  `0x08750020` bis `0x087600c0` und bilden 20 Intervalle. Jedes Intervall ist
  `0x808`, `0x1008`, `0x2008` oder einmal `0x2808` Byte groß. Nach Abzug von
  8 Byte pro Intervall summieren sich die Größen exakt zu `0x10000` Byte.
  Das spricht stark für ein statisch reserviertes Task-Stack-Areal; Bedeutung
  und Nutzung der zusätzlichen 8 Byte sind nicht belegt.
- `DiskMgrTask` zeigt im Runtime-Abbild ab `0x08010d5c` gültigen Thumb-Code. Der
  sichtbare Einstieg initialisiert einen Stack-Kontext, speichert ihn bei
  `0x08552284`, ruft interne Dienste auf und räumt den Kontext auf. In diesem
  Einstieg ist kein direkter iTunesDB-/ArtworkDB-Parseraufruf zu sehen. Das
  schließt spätere Verarbeitung über die aufgerufenen Dienste nicht aus.
- Der Dispatcherbereich `0x087600c0..0x08760250` (20 Datensätze × `0x14` Byte)
  und die Stackadressen liegen beide im Nullungsbereich. Ein read-only-Ghidra-
  Referenzlauf fand keine direkten Xrefs auf den Metadatenblock bei
  `0x08013fb0`; der Block wird über relative Constructor-Einträge referenziert.
  Ein exakter Binärscan nach absoluten Zeigern auf diesen Metadatenblock in
  `Firmware.MSE`, `rsrc.bin` und den extrahierten Bootloader-/Diags-PE32-Modulen
  blieb ohne Treffer.

Die Verbindung zum BootTask-Dispatcher und der Code, der die Null-Tabelle
befüllt, sind statisch gefunden: `FUN_08013d44` ist Eintrag 28 der relativen
Constructor-Tabelle und schreibt 20 Task-Datensätze. Offen bleibt, ob dessen
Runner über `FUN_08324af0` durch die reale externe OSOS-Startkette erreicht
wird. Diese Aussage wird durch den Kaltstart-Nachtrag unten korrigiert:
Der Resetpfad erreicht den Constructor-Runner über einen Relokationsstub.
Aus den Metadaten allein folgt kein automatisch erreichter Dateiparser
und keine OSOS-RCE. Analysequellen: `osos_body.bin`,
`/tmp/osos_runtime_dram_20261025.bin`, read-only-Ghidra-Projekt
`/tmp/N5G_OSOS_runtime_analysis/N5G_OSOS_runtime.gpr` sowie die Gegenprüfungen
mit `arm-none-eabi-objdump` und dem exakten Little-Endian-Pointer-Scan. Keine
Geräte-, USB-, DFU-, Boot- oder Flashaktion.

## Nachtrag: relativer Constructor-Verweis auf die Task-Initialisierung

Der direkte Xref- und absolute Pointer-Scan übersah die relative Constructor-
Kodierung. Die Laufzeitfunktion `0x08012a24` bildet aus den Literalen bei
`0x08012a40`/`0x08012a44` den Bereich `0x08550370..0x08550774` und iteriert
257 32-Bit-Relativzeiger. Pro Eintrag addiert sie den vorzeichenbehafteten
Wert zur Adresse des Eintrags und ruft das Ergebnis mit `BLX` auf.

- Eintrag 28 bei `0x085503e0` enthält `0xffac3965`; relativ zu seiner eigenen
  Adresse ergibt das den Thumb-Zeiger `0x08013d45` auf `FUN_08013d44`.
- `FUN_08324af0` ruft den Constructor-Runner bei `0x08324b90` direkt auf.
  Damit ist die Ausführung von `FUN_08013d44` belegt, wenn dieser Runner läuft.
  Einen direkten oder absoluten Verweis auf `FUN_08324af0` habe ich in den
  untersuchten Runtime-/Full-Body-Abbildern, `Firmware.MSE`, `rsrc.bin` und
  Bootloader-PE32-Modulen nicht gefunden. Ein externer Einstieg oder ein
  Overlay-/Rebind-Aufruf bleibt möglich; Kaltstart-Erreichbarkeit ist damit
  noch nicht bewiesen.
- `FUN_08013d44` erzeugt 20 Records mit Schrittweite `0x14` in
  `0x087600c0..0x08760250`. `FUN_0819dcbc` setzt je Record fünf Wörter: zuerst
  null, dann die vier übergebenen Felder. `FUN_0801e2b4` konsumiert die Felder,
  legt den Task-Handle ab und ruft den importierten Task-Create-Dienst auf.
- Die frühere Angabe „25 Datensätze“ war ein Zählfehler: `0x250 - 0xc0` ergibt
  `0x190` Byte; geteilt durch `0x14` sind das 20 Records.

Rohbelege: `utils/ipodnano5g/analysis/osos_runtime_constructor_table.tsv`,
`/tmp/OSOS_task_table_init_thumb.txt`, `/tmp/OSOS_ctor_runner_caller_thumb.txt`,
`/tmp/OSOS_boot_task_dispatch_followup.txt` sowie der read-only-Xref-Lauf zum
Constructor-Runner. Keine Geräte-, USB-, DFU-, Boot- oder Flashaktion.

## Korrektur: Resetpfad erreicht Constructor-Runner, BootTask und MainApp (26.10.2026)

Der vollständige OSOS-Body und das daraus rebaste Bootprefix-Abbild ergeben
eine zusammenhängende statische Startkette. Die früher offene
Kaltstart-Erreichbarkeit des Constructor-Runners ist damit für diesen Pfad
geschlossen:

1. Das Wort am IMG1-Body-Einstieg `0x08000000` ist `0xea001c0c` und verzweigt
   nach `0x08007038`. Dort setzt der ARM-Code den Stack und verzweigt nach
   `0x08005058`.
2. `0x08005058` richtet den Bootprefix ein. Der Aufruf bei `0x08005108` geht
   über den Stub `0x08003790`; dessen Literal bei `0x08003794` ist der
   Thumb-Zeiger `0x08012a25` auf den Constructor-Runner im Runtime-Adressraum.
   Das Runtime-Abbild beginnt mit dem Body-Suffix ab Offset `0x2e27c`; der
   Runner entspricht daher im vollständigen Body `0x08040ca0`. Der Code
   durchläuft 257 relative Constructor-Einträge, darunter Eintrag 28
   (`0x08013d44`), der die 20 BootTask-Records füllt.
3. Der Root legt anschließend den RTOS-Task `BootTask` an und geht in den
   Scheduler. Das rebaste Prefix-Abbild unter `/tmp/osos_bootprefix_22000000.bin`
   zeigt den Dispatch über `0x22003908`; dessen Literal bei `0x2200390c` ist
   `0x083534e8`, der Runtime-Einstieg von `FUN_083534e8`. Dieser BootTask ruft
   `FUN_0801c684` auf und lässt damit die zuvor befüllte 20-Record-Tabelle
   auswerten.
4. Im BootTask-Post-Init ruft `FUN_08354ba8` zunächst `FUN_0801d594(0)` auf.
   Diese Funktion ruft `FUN_0801e3a4`, die mit dem Namen `MainAppTask`, dem
   Thumb-Einstieg `0x080202d9` und dem Task-Create-Helfer `FUN_08193984` den
   MainApp-Task anlegt. Die statische Kette reicht damit bis zum automatischen
   MainApp-Start.

Die Mapping-Gegenprüfung bestätigt identische Runtime-/Full-Body-Bytes an
den relevanten Suffix-Adressen. Die unabhängige Funktion `FUN_08324af0` ruft
ebenfalls den Constructor-Runner, ist für den nachgewiesenen Resetpfad aber
nicht erforderlich. Die ältere Aussage, nur ein externer Einstieg oder ein
Overlay könne den Runner erreichen, ist hiermit überholt.

Der Befund ist ein statischer Kaltstart- und Taskstartnachweis, noch kein
Exploit: Die bereits analysierte frühe Media-Factory wird mit Nullkontext
aufgerufen und bricht vor `FUN_081ac420` ab. Der automatische Start von
MainApp belegt daher keinen automatischen Aufruf des ArtworkDB- oder Notes-
Parsers und keine kontrollierte Codeausführung. Die nächste sinnvolle Spur ist
die konkrete automatische MainApp-Nachricht samt Laufzeit-Handler und
Kontextquelle bis zu einem persistenten Dateiparser.

Zusätzliche Rohbelege: `/tmp/OSOS_ctor_runner_fullbody_mapped_20261026.txt`,
`/tmp/OSOS_task_ctor_helper_0819dcbc_20261026.txt`,
`/tmp/OSOS_boot_mainapp_task_setup_20261026.txt`,
`/tmp/OSOS_task_create_MainAppTask_helper_20261026.txt`,
`/tmp/OSOS_MainAppTask_creation_dispatch_20261026.txt`,
`/tmp/OSOS_boot_postinit_080cbbf8_20261026.txt` und
`/tmp/OSOS_boot_postinit_0819c7bc_20261026.txt`. Die Ghidra-Projekte wurden
read-only geöffnet. Weitere ältere Rohbelege: `/tmp/OSOS_reloc_prefix_boottask_20261025.txt`,
`/tmp/OSOS_bootprefix_functions_2026-10-25.txt` und
`/tmp/OSOS_BootTask_083534e8.txt`. Kein USB, DFU, Reset, NAND-/NOR-Zugriff
oder Geräteboot.

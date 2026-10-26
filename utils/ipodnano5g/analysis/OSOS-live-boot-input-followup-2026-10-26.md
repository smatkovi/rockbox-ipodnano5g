# OSOS-Kaltstartpfad und Live-Eingaben – Folgebefund

Stand: 26.10.2026. Diese Fortsetzung kombiniert read-only Ghidra-Analyse mit einer
read-only Bestandsaufnahme des aktuell per USB angeschlossenen iPods. Es gab
keinen Reset, DFU-Wechsel, NAND-/NOR-Schreibzugriff oder Firmware-Flash.

## Verifizierter Gerätezustand

- USB meldet `05ac:1265`, Produkt `Rockbox media player`, Hersteller
  `Rockbox.org`. Die 8-MiB-LUN `/dev/sda` ist die Rockbox-RAM-Disk `NANO5G`.
- `/dev/sdb` ist die iPod-Nutzdaten-LUN (`Apple iPod Nano 5G`, 14,9 GiB,
  Partition `/dev/sdb1`, FAT32-Label `SEBIPOD`). `/dev/sdc` ist die separate
  FTL-LUN (`Apple iPod Nano 5G FTL`, 15,1 GiB).
- `blockdev --getro` meldet für `/dev/sdb` und `/dev/sdc` jeweils `1`; keine
  dieser LUNs war eingehängt. `fsck.fat -n -v /dev/sdb1` ließ das Volume
  unverändert. Es meldet ein gesetztes Dirty-Bit und einen Unterschied zum
  Backup-Bootsektor; daraus wurde keine Dateisystemreparatur abgeleitet.
- Ein eigener FAT32-Verzeichnislauf mit ausschließlich `O_RDONLY` fand
  `/iPod_Control/Device` mit 15 Einträgen, aber keine Datei `dst`. Unter
  `/iPod_Control/Artwork` liegt `ArtworkDB` mit 26.992 Byte.
- Das bestätigt einen erfolgreichen Rockbox-Start aus dem zuvor über U-Boot
  übertragenen SDRAM-Image. Es bestätigt keine persistente Installation und
  keinen Start ohne den PC.

## BootTask und RTOS-Übergabe

Der frühe OSOS-Einstieg `FUN_08005058` erzeugt über den RTOS-Aufruf bei
`FUN_080051dc` einen `BootTask` mit Entry `0x2200657c`. Der dortige Code ruft
Service 40 (`FUN_08005624`) mit Task-ID 0 auf, übergibt den gelesenen Wert
anschließend an Service 41 (`FUN_080052f8`) und verzweigt danach zu
`0x08003908`.

Die Dispatch-Tabelle von `FUN_08000b70` führt Service 40 zu `0x08001f64` und
Service 41 zu `0x08001f88`. Die beiden Fälle lesen beziehungsweise schreiben
das 32-Bit-Feld `TCB+0x2c`; Task-ID 0 bedeutet den aktuellen Task. Im
BootTask-Pfad wird dieses Feld daher gelesen und auf null gesetzt. Diese
Operation ist kein sichtbarer Aufruf eines Datei- oder Datenbankparsers.

Der Veneer `0x08003908` lädt im rebasierten Bootprefix bei `0x2200390c` den
Wert `0x083534e8`. Die frühere Prüfung dieses Werts im Full-Body-Adressraum war
ein Mappingfehler: Das Runtime-Abbild beginnt bei OSOS-Dateioffset `0x2e27c`
auf Adresse `0x08000000`. Runtime-VA `0x083534e8` gehört damit zu OSOS-Body-
Dateioffset `0x381764` beziehungsweise Full-Body-VA `0x08381764`, nicht zu
Full-Body-VA `0x083534e8`. Ein Bytevergleich bestätigt für die 84 Byte des
BootTask-Einstiegs identischen Inhalt zwischen beiden korrekten Abbildungen.
Im Runtime-Abbild ist `0x083534e8` ein gültiger ARM-Einstieg (`arm_83534e8`):
Er richtet BootTask-Dienste ein, wertet mit `FUN_0801c684` die Tasktabelle aus,
ruft `FUN_08354ba8` auf und kehrt anschließend über den gemeinsamen Scheduler-
Pfad zurück. Die zuvor erwogene dynamische Rebindung oder ein Overlay ist für
diese Zieladresse nicht erforderlich. Im analysierten BootTask-Code wurde
keine Änderung des Veneer-Literals gefunden; eine globale Schreibersuche über
alle Laufzeitkomponenten war damit nicht verbunden.

Korrektur der älteren Spur: Die Sprünge über `0x080038f0` und `0x080038f8`
gehören zur separaten Kernel-Schleife. Sie sind nicht das Ziel des BootTask-
Veneers `0x08003908`.

## Media-Registry

`FUN_081d5c26` ruft `FUN_081df3a0` auf. Diese Funktion erzeugt bei leerem
Singleton-Feld ein 0x3c-Byte-Objekt über `FUN_083423c8` und speichert dessen
Adresse global. Der Konstruktor initialisiert zwei Listen. Die
Media-Controller-Konstruktoren benutzen das Objekt, um Zustandsnamen wie
`TMediaNowPlayingCntlr` und `TMediaNowPlayingCntlr_Playback` einzutragen.
Damit ist der Registry-Mechanismus konkreter bestimmt; sein Aufruf aus einem
automatischen Kaltstartpfad und ein Dateiparser-Callback sind weiterhin nicht
belegt.

## Bewertung der persistenten Eingabekandidaten

- `Device/dst`: Die Datei fehlt aktuell auf dem iPod. Der statische Reader
  schreibt zwei Dateibytes in ein codezeiger-artiges Wort, aber die bisher
  gefundenen Verbraucher greifen auf andere Strukturfelder zu. Der Kandidat
  liefert damit weder einen aktuellen Trigger noch Kontrollflussübernahme.
- `ArtworkDB`: Die Datei ist vorhanden. Die frühere read-only Prüfung des
  Live-Samples ergab null Albumdatensätze; damit wird der bekannte `mhba`-
  Überlauf durch den aktuellen Datenbankinhalt nicht ausgelöst. Ein speziell
  präparierter Datenbankkandidat verursacht im Hostmodell bedingte
  Heapkorruption beziehungsweise einen möglichen Absturz. Eine echte
  OSOS-Kontrollflussübernahme oder ein automatischer Kaltstartaufruf ist daraus
  weiterhin nicht abgeleitet.

Eine Schwachstelle im signierten OSOS könnte prinzipiell als PC-freier
Rockbox-Relay dienen, wenn eine persistente Datei den Fehler automatisch bei
jedem Kaltstart auslöst, der Fehler reproduzierbare Codeausführung liefert und
ein stabiler Übergang zu Rockbox in RAM gelingt. Keiner dieser drei Punkte ist
für die bisher geprüften OSOS-Kandidaten vollständig belegt.

## Reproduzierbarkeit und nächste Offline-Schritte

Neue Ghidra-Auszüge liegen vorübergehend unter:

- `/tmp/OSOS_boot_dispatch_20261026.txt`
- `/tmp/OSOS_boot_targets_20261026.txt`
- `/tmp/OSOS_syscalls_20261026.txt`
- `/tmp/OSOS_boot_loop_targets_20261026.txt`
- `/tmp/OSOS_registry_locator_20261026.txt`
- `/tmp/OSOS_registry_service_20261026.txt`
- `/tmp/OSOS_registry_ctor_20261026.txt`
- `/tmp/OSOS_registry_methods_20261026.txt`
- `/tmp/OSOS_boot_task_runtime_dispatch_20261026.txt`
- `/tmp/OSOS_boot_task_graph_20261026.txt`

Alle Headless-Aufrufe nutzten `-noanalysis -readOnly`; Ghidra meldete das
Verwerfen der Änderungen an der read-only Programmdatenbank.

1. Den frühen MainApp-/BootEvent-Dispatch weiterverfolgen und klären, ob
   `ArtworkDB` vor einer Benutzeraktion automatisch geladen wird.
2. Für einen Exploitpfad müssen Eingabequelle, Kaltstarterreichbarkeit,
   Kontrollflussgewinn und OSOS→Rockbox-Handoff gemeinsam nachgewiesen werden.
   Bis dahin bleibt der Gerätezustand unverändert und es werden keine
   NAND-/NOR-Schreib- oder Flashversuche durchgeführt.

## Nachtrag: BootTask-Ziel im Runtime-Adressraum (2026-10-26)

Die 84-Byte-Gegenprobe aus dem vollständigen Body und dem gemappten Runtime-
Abbild liegt unter `/tmp/OSOS_boot_task_runtime_mapping_20261026.txt`.
Der ARM-Einstieg und seine Aufrufer sind unter
`/tmp/OSOS_boottask_runner_caller_20261026.txt` exportiert. Das RTOS-
Startkontext-Setup steht in `/tmp/OSOS_rtos_start_task_case_20261026.txt`;
der Service-Dispatch und die BootTask-Aufrufe sind in
`/tmp/OSOS_syscalls_20261026.txt` und `/tmp/OSOS_boot_dispatch_20261026.txt`
belegt. Die Ghidra-Projekte wurden read-only geöffnet; das iPod-Gerät wurde
nicht angesprochen.

## Nachtrag: MainApp-Erreichbarkeit des ArtworkDB-Laders

Ein read-only-Direktaufrufgraph ab MainApp-Entry `0x080202d8` erreichte bei
Tiefe 32 insgesamt 3.956 Funktionen. Er erreichte `FUN_080253f4`,
`FUN_081ac420` und `FUN_080eb730` nicht über ausschließlich direkte
Call-Referenzen. Das ist kein vollständiger Erreichbarkeitstest, weil der
MainApp-Start Factory-Callbacks über Funktionszeiger ausführt.

Die frühere Zieladresse `0x08022b18` war kein Funktionseinstieg, sondern ein
Basic Block innerhalb von `thumb_8022b08`, dessen Thumb-Funktion bei
`0x08022b08` beginnt. Die korrigierte lineare Disassemblierung zeigt den
direkten Aufruf `0x08022b18 -> FUN_080253f4`.

`FUN_081ac420` hat im Runtime-Abbild zwei direkte Aufrufstellen:
`0x080254b6` in `FUN_080253f4` und `0x080eb73c` in `FUN_080eb730`. Letzterer
steht als Thumb-Zeiger `0x080eb731` im VTable-Wort bei `0x08504b14` und ruft
den Loader nur, wenn der verschachtelte Kontextzeiger und dessen Feld `+0x48`
nicht null sind. Der statische Dateiinhalt enthält an der untersuchten
Kontextposition null; ein Live-Runtime-Wert oder eine Laufzeitschreibstelle
ist damit nicht bewiesen.

## Korrektur: Factory-Pfad und Nullkontext (2026-10-26)

Der Callback-Pfad klärt die scheinbare Lücke des direkten Callgraphs. Der
MainApp-Einstieg `FUN_080202d8` ruft über VTable-Slot `+0x16c` den frühen
MainApp-Callback auf. Dieser stößt über Slot `+0x170` den Factory-Batch an;
der Eintrag für ID `0x3280` bei `0x08553a70` enthält den Thumb-Zeiger
`0x0801e8f7` auf `FUN_0801e8f6`. Der Callback ruft `FUN_08020fa8` mit zweitem
Argument `0` auf. Dessen direkter Aufruf `0x08021018 -> 0x08022b08` übergibt
den gespeicherten Nullkontext an `thumb_8022b08`.

`thumb_8022b08` ruft `FUN_080253f4(0, object+0x48)` auf. `FUN_080253f4` gibt
bei diesem Nullkontext über `FUN_08032850(0)` früh `-0x32` zurück; der
ArtworkDB-Aufruf bei `0x080254b6` wird in diesem frühen Factory-Pfad nicht
erreicht. Damit ist die Controllerkonstruktion im MainApp-Start statisch
belegt, aber kein automatischer ArtworkDB-Parse durch diesen Konstruktor.
Ein späterer Pfad über `FUN_080eb730` bleibt zustands- und kontextabhängig.

Rohbelege: `/tmp/OSOS_mainapp_artwork_path_graph_corrected_20261026.txt`,
`/tmp/OSOS_artwork_initializer_func_08022b08_20261026.txt`,
`/tmp/OSOS_factory_runtime_decomp_2026-10-25.txt`,
`/tmp/OSOS_music_callback_pointer_context_20261026.txt` und
`rb-n5g/utils/ipodnano5g/analysis/OSOS-factory-coldstart-2026-10-25.md`.
Die Ghidra-Aufrufe liefen mit `-noanalysis -readOnly`; kein Gerätezugriff.

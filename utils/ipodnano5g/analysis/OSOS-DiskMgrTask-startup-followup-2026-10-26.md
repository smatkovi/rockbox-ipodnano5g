# OSOS-DiskMgrTask: tatsächlicher Task-Einstieg und Dienstaufrufe

Stand: 26.10.2026. Ausschließlich statische Offline-Analyse. Ghidra-Projekte wurden mit `-noanalysis -readOnly` geöffnet. Kein USB-/DFU-Zugriff, Geräteboot, Reset oder NAND-/NOR-Schreibzugriff.

## Korrektur des vorherigen Exports

`/tmp/OSOS_DiskMgrTask_entry_20261026.txt` ist kein Export des `DiskMgrTask`-Einstiegs: Er analysiert `thumb_801317e`, einen anderen 20-Byte-Block. Die Task-Metadaten im vollständigen OSOS-Body nennen für `DiskMgrTask` dagegen den Thumb-Zeiger `0x08010d5d`; der korrekte Code beginnt bei `0x08010d5c`. Der korrigierte, mit gesetztem Thumb-Modus erzeugte Export ist `/tmp/OSOS_DiskMgrTask_entry_corrected_20261026.txt`.

## Verifizierter Kontrollfluss

- Im Metadatenblock bei `osos_body.bin+0x4222c` steht `0x08010d5d` unmittelbar vor dem Namen `DiskMgrTask`.
- Der Runtime-Einstieg `0x08010d5c` richtet einen Kontext mit `FUN_080067e8` ein, speichert dessen Zeiger bei `0x08552284` und ruft den externen Dienst über den Runtime-Trampolin `0x082002ac` auf. Danach ruft er `FUN_08006820` zum Kontextabbau und `FUN_0819396c`.
- `FUN_0819396c` ist acht Byte lang: Es ruft nur `FUN_080000bc` auf. `FUN_080000bc` setzt `r0` auf null und springt über denselben Trampolin `0x082002ac`.
- Der Trampolin bei `0x082002ac` ist ARM-Code `ldr pc,[pc,#-4]` mit Literal `0x220059d4`. Wegen der OSOS-Relokation des Prefixes von `0x08000000` nach `0x22000000` entspricht der Dienstcode dem Full-Body-Code bei `0x080059d4`. Dieser setzt Dienstnummer `25` und wechselt über `FUN_08004f14` in den SVC-/RTOS-Dispatcher `FUN_08000b70`. Die konkrete semantische Bezeichnung von Dienst 25 ist aus diesen statischen Belegen nicht sicher ableitbar.
- In den geprüften Körpern von `DiskMgrTask` und `FUN_0819396c` gibt es keinen direkten Aufruf eines Datei-, iTunesDB- oder ArtworkDB-Parsers. Das beweist nicht, dass andere Tasks oder dynamische Dienste beim Kaltstart keine Datenbank laden.

## Bedeutung für den OSOS-Rockbox-Pfad

Das ist kein neuer Exploit. Der Befund grenzt lediglich den benannten `DiskMgrTask`-Einstieg ein: Er liefert in diesem Runtime-Abbild keinen unmittelbaren automatischen ArtworkDB-Trigger. Der offene Pfad bleibt die bedingte `TMusicLoadingTask`-Kette bis `FUN_081ac420` und die Initialisierung ihres nichtnulligen Laufzeitkontexts. Eine OSOS-RCE könnte nach erfolgreichem signiertem OSOS-Start theoretisch den bereits vorhandenen Rockbox-Loader von FAT nach RAM laden; derzeit fehlen aber ein beim Kaltstart wiederholbarer Exploittrigger, kontrollierte Codeausführung und ein tatsächlich erreichter Handoff.

## Reproduzierbare Belege

- Runtime-Abbild: `/tmp/osos_runtime_dram_20261025.bin`
- Full-Body: `nano5g/osos_decrypted/osos_body.bin`
- Runtime-Ghidra-Projekt: `/tmp/N5G_OSOS_runtime_analysis/N5G_OSOS_runtime.gpr`
- Full-Body-Ghidra-Projekt: `nano5g/ghidra-projects/N5G_OSOS_RTOS.gpr`
- Korrigierter Task-Einstieg: `/tmp/OSOS_DiskMgrTask_entry_corrected_20261026.txt`
- Worker: `/tmp/OSOS_DiskMgrTask_worker_20261026.txt`
- Direkte Helfer: `/tmp/OSOS_diskmgr_direct_helpers_20261026.txt`
- Relokierter Dienst `0x220059d4`: `/tmp/OSOS_diskmgr_service_220059d4_20261026.txt`
- BootTask-Post-Init und Referenzen: `/tmp/OSOS_boot_task_postinit_services_20261026.txt`, `/tmp/OSOS_boot_task_postinit_refs_20261026.txt`
- Bootprefix: `/tmp/OSOS_bootprefix_3908_20261026.txt`

Verwendete vorhandene Skripte: `nano5g/ghidra-logs/AnalyzeThumbFunctionAt.java`, `AnalyzeFunctionAt.java`, `AnalyzeOSOSFunctions.java` und `InspectRefsAt.java`.

## Nächster sinnvoller Schritt

Weiter den automatischen Erzeuger des Music-Task-Kontexts und die statusgesteuerte Kette zu `FUN_081ac420` verfolgen. Dabei Runtime- und Full-Body-Adressen strikt getrennt halten. Der konkrete Hardwarezustand wurde nicht geprüft.

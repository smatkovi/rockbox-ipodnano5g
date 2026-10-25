# OSOS-Taskkontext und möglicher Rockbox-Handoff

Stand: 25.10.2026. Offline-Analyse des S5L8730-RTOS-Prefix und des gemappten
OSOS-Runtime-Abbilds. Keine Geräte-, USB-, DFU-, NAND- oder NOR-Aktion.

## Verifizierter Taskkontext

Der BootTask verarbeitet nach der Constructor-Initialisierung die Tabelle ab
`0x087600c0`. Der erste Taskcallback `FUN_0801e2b4` richtet einen Task ein;
der zweite `FUN_0801e2d6` macht ihn über den SVC-Dienst `0x15` lauffähig. Der
Task-Erzeugungspfad ruft davor SVC-Dienst `0x16` auf, um Entry und Kontext zu
setzen.

Im SVC-Dispatcher führt Dienst `0x15` ab `0x08001e1c` den initialen
Registerkontext aus. Er speichert den Task-Entry bei Kontextoffset `+0x3c`
und setzt das gespeicherte CPSR auf `0x13`, wenn der Entry ARM-Code ist, oder
`0x33`, wenn er Thumb-Code ist. In beiden Werten sind die CPSR-Modusbits
`0x13` (Supervisor); `0x33` ergänzt dazu das Thumb-Bit `0x20`. Der normale
OSOS-Taskpfad startet damit Tasks im privilegierten SVC-Modus, nicht im
unprivilegierten User-Modus.

## Bedeutung für einen Exploit-Handoff

Eine bestätigte Kontrollflussübernahme in einem solchen OSOS-Task hätte damit
grundsätzlich die CPU-Privilegien, um den Rockbox-Loader zu starten und dessen
frühe Initialisierung auszuführen. Der vorhandene Loader setzt in seinem
Startup selbst SVC-Modus, maskiert IRQ/FIQ und deaktiviert MMU und Caches,
bevor er Rockbox initialisiert. Der gelinkte Loader-Einstieg `0x09000000`
liegt im OSOS-Heap; die Übergabe müsste daher endgültig sein und OSOS dürfte
danach nicht weiterlaufen.

Das löst den fehlenden Exploittrigger nicht: Es gibt weiterhin keinen
persistenten, beim normalen Kaltstart automatisch verarbeiteten Datensatz,
der zu kontrollierter Codeausführung führt. Notes, ArtworkDB, eApp-Manifest
und Task-Argumentparser bleiben Kandidaten mit jeweils noch offener
Kaltstart-Erreichbarkeit oder Kontrollflussübernahme.

Der bestehende Bootloader prüft Hold vor dem FAT-Zugriff und lädt bei
gesperrtem Schalter das signierte Apple-OS. Für einen OSOS-Autostartpfad muss
die Hold-Abfrage vor dem Exploit-Handoff erfolgen, damit gesperrtes Hold nicht
eine erneute OSOS-Start-/Exploit-Schleife auslöst. Die Lock-Fallbacklogik ist
im Quellcode und Build vorhanden, aber auf dem Gerät noch nicht verifiziert.

## Belege und Grenzen

- `/tmp/OSOS_runtime_task_dispatch_callbacks_20261025.txt`
- `/tmp/OSOS_runtime_task_svc_slot_semantics_20261025.txt`
- `/tmp/OSOS_prefix_task_svc_wrappers_20261025.txt`
- `/tmp/OSOS_08000b70.txt` (Switch-Fall `0x15`, einschließlich CPSR- und
  Entry-Kontext)
- Bootloader-Hold-/Fehlerpfade: [`bootloader/ipodnano4g.c`](../../../bootloader/ipodnano4g.c)
- Loader-Startup: [`firmware/target/arm/s5l8702/crt0.S`](../../../firmware/target/arm/s5l8702/crt0.S)

Der Befund belegt den initialisierten Taskmodus im regulären SVC-Dispatcher.
Er belegt weder eine OSOS-RCE noch kontrollierbare Rücksprungdaten, den
Dateizugriff aus dem Exploitpfad, einen automatischen Kaltstarttrigger oder
den Hold-Fallback zur Laufzeit.

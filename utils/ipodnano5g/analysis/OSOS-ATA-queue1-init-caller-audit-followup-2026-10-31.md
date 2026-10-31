# Queue-1-Setup: Suche nach dem Aufrufer des Prefix-Imports

Stand: 31.10.2026. Read-only-Abgleich der OSOS-Body-, Runtime- und Prefix-
Abbilder sowie der lokal extrahierten Nano-5G-Codeimages. Ghidra lief mit
`-readOnly -noanalysis`; die temporäre Funktionsanlage wurde zurückgerollt.
Kein Geräte-, USB-, DFU-, Reboot-, Dateisystem- oder Flashzugriff.

## Ergebnis

Der ATA-IRQ-Pfad fordert sein Ressourcenhandle weiterhin über den Prefix-
Queue-Getter für Queueindex 1 an. Der Prefix enthält außerdem den Setupdienst
`FUN_22005248`, der SVC-Fall `0x2e` ausführt und einen Queueeintrag an
`0x2200975c + index * 0x2c` initialisiert. Der Queue-Setupcode prüft, dass
der Anfangsfüllstand nicht größer als die Kapazität ist.

Ein neuer Rohbildabgleich hat die dazugehörigen OSOS-Import-Stummel sichtbar
gemacht. Der Body enthält bei `0x0823b7a8` einen ARM-`ldr pc`-Veneer mit
Literal `0x22005248` bei `0x0823b7ac`; die Runtime enthält denselben Import
bei `0x0820d52c` mit Literal bei `0x0820d530`. Ghidra-dekompiliert der
Body-Veneer zu einem indirekten Sprung über dieses Literal. Die read-only
Ghidra-Abfrage findet keine eingehende Referenz zum Body-Veneer oder zum
Prefix-API-Ziel. Ein reproduzierbarer Little-Endian-32-Bit-Scan von 160
Codeabbildern und den beiden lokalen Prefix-/Runtime-Eingaben findet genau
die beiden Importliterale in Body und Runtime; keinen gespeicherten Zeiger
auf einen der beiden Veneers.

Das stützt die engere Aussage: **In den geprüften OSOS-Codeabbildern ist kein
statischer Aufrufer des Queue-Setupdienstes belegt.** Es beweist nicht, dass
Queue 1 beim Kaltstart uninitialisiert ist. Ein außerhalb dieser Abbilder
liegender Bootschritt, ein dynamischer Funktionsaufruf oder nicht erfasster
Laufzeitzustand bleibt möglich. Es ist kein neuer Speicherfehler und kein
neuer Exploitpfad.

## Bedeutung für `accessories.reg`

Die Scheduleranalyse macht den Slot-0-MBR-/Providerpfad vor `MainAppTask`
statisch erreichbar, wenn das ATA-Setup wie im Codepfad ausgeführt wird. Der
fehlende Queue-1-Ressourcenaufbau verhindert weiterhin den Schluss, dass der
ATA-IRQ-/Datenträgerpfad im echten Kaltstart rechtzeitig arbeitet. Damit sind
ein erfolgreicher Slot-0-Mount, der automatische Open/Read von
`accessories.reg`, die ROP-Ausführung auf dem iPod und der Rockbox-Handoff
unbestätigt.

Der jüngste ARM1176-System-Rehost bleibt ein reiner Offline-Kontrolllauf: Er
erreicht nach dem modellierten Datei-Open/Read den echten DSB-Helper, den
Loader-`bss_init` und den Loader-Alias-Einstieg. Parserobjekt, Volume-/Handle-
Zustand und Dateiread werden dabei teilweise im Harness gesetzt bzw.
modelliert; der Lauf ersetzt die hier fehlende Bootzeit-Queue-/Provider-
Beobachtung nicht.

## Belege

- `evidence/ata-queue1-init-lookup-2026-10-31/` enthält den Ghidra-Auszug
  des transient dekodierten Body-Veneers, die beiden Null-Xref-Abfragen, das
  reproduzierbare Suchskript, dessen Ergebnis und Prüfsummen.
- `evidence/rtos-task-order-2026-10-29/OSOS_prefix_svc_dispatch_queue1_semantics_20261031.application.log`
  zeigt SVC-Fall `0x2e`, die Queuebeschreibung und die Kapazitätsprüfung.
- `evidence/rtos-task-order-2026-10-29/OSOS_prefix_queue1_get_resource_dispatch_20261031.application.log`
  zeigt den Queue-1-Getter im ATA-Ressourcenpfad.
- `evidence/ata-mbr-followup-2026-10-31/OSOS_runtime_SVC_queue_init_refs_even_odd_20261031.application.log`
  dokumentiert die bereits geprüften Runtime-Xrefs auf den Importdienst.
- `evidence/ata-mbr-followup-2026-10-31/OSOS_runtime_SVC_queue_init_api_callers_20261031.application.log`
  zeigt den Runtime-Importstummel und seine aufgelösten Referenzen.
- `evidence/rtos-task-order-2026-10-29/OSOS_prefix_svc_queue_table_entry_words_20261031.application.log`
  dokumentiert die Nullbytes im statischen Prefix-Queue-Tabellenbereich;
  daraus folgt keine Aussage über eine spätere Laufzeitinitialisierung.
- `OSOS-Queue4-ATA-worker-initial-wait-followup-2026-10-31.md` fasst die
  Queue-4-Präemption und die offene Queue-1-Initialisierung zusammen.

## Nächster Schritt

Als Nächstes ist der Queue-1-Setupaufruf in den frühen BDS-/Bootpfad oder in
einer passenden Laufzeitaufnahme zu suchen. Falls dieser Setupaufruf nicht
außerhalb des Runtime-Abbilds liegt, ist eine lesende Beobachtung der Queue-
Tabelle vor dem ersten `FUN_081a5104` der entscheidende Test. Danach kann der
VFS-/FAT-Rehost ohne vorausgefüllten Stream und Handle weiter geschlossen
werden. Der Befund rechtfertigt noch keinen Gerätetest des Overflow-Kandidaten
und keinen Schreibversuch.

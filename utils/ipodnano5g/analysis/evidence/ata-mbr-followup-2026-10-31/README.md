# ATA-/MBR-Reachability-Belege, 31.10.2026

Die Dateien dokumentieren read-only Ghidra-Abfragen am Projekt
`/home/sebastian/ipod-re/local-analysis/ghidra-projects/N5G_OSOS_runtime_analysis/N5G_OSOS_runtime`
und rohe Hexdumps aus
`/home/sebastian/ipod-re/local-analysis/inputs/osos_runtime_dram_20261025.bin`.
Das Runtime-Abbild hat SHA-256
`1326c547b1a97ddf35bf0df53949833fa3b9ec8fabaa1733cb399df7b537ff03`.

| Beleg | Inhalt |
| --- | --- |
| `OSOS_runtime_partition_registration_dispatch_20261031.application.log` | MBR-Parsing, `FUN_0818e998`-Registrierung und Aufruf von `FUN_0819039e` |
| `OSOS_runtime_partition_callback_notify_20261031.application.log` | Manageränderung und Queue-Drain über `FUN_0819f508`; der damalige Callback-Name war eine vorläufige, später korrigierte Deutung |
| `OSOS_runtime_partition_manager_singleton_20261031.application.log` | Manager-Singleton, Slotbelegung, dynamischer Read-Dispatch |
| `OSOS_runtime_VFS_mount_first_sector_20261031.application.log` | VFS-Open, Mount-Einstieg und Laufwerkszugriff |
| `OSOS_runtime_volume_mount_state_machine_20261031.application.log` | Mountzustand und Übergang zum FAT/BPB-Parser |
| `OSOS_runtime_BPB_mount_read_chain_20261031.application.log` | BPB-Parser und Aufruf von `FUN_08158dd0` |
| `OSOS_runtime_BPB_sector_fetch_20261031.application.log` | Ein-Sektor-Read des BPB-Pfads und Folgeaufrufer |
| `OSOS_runtime_memory_DAT_0816a96c_20261031.log` | Ghidra-Wert der dynamischen Tabellenbasis |
| `OSOS_runtime_memory_candidate_table_0833503c_20261031.log` | Ghidra-Speicherbytes an der Rohbyte-Kandidatenadresse |
| `OSOS_runtime_memory_candidate_table_0883503c_20261031.log` | Nicht abgebildeter, von Ghidra interpretierter Tabellenbereich |
| `OSOS_runtime_memory_vtable_084fd570_20261031.log` | Ghidra-Speicherstatus der Provider-VTable |
| `OSOS_runtime_provider_vtable_084fd570_20261031.hex.txt` | Rohbytes der Provider-VTable aus dem Runtime-Abbild |
| `OSOS_runtime_partition_adapter_vtable_08536a78_20261031.hex.txt` | Rohbytes der MBR-Partitionsadapter-VTable |
| `OSOS_runtime_partition_adapter_getters_20261031.application.log` | Methoden der Partitionsadapter-VTable und Leseimplementierung |
| `OSOS_runtime_partition_adapter_slots_20261031.log` | Instruktionsfenster zu Adapter-VTable-Slots |
| `OSOS_runtime_partition_io_callers_20261031.application.log` | Decompilierung der Wrapper-/I/O-Einstiege |

## Ergänzung: gemeinsame I/O-Tabelle und Mountmethode

Die folgenden zusätzlichen read-only-Abfragen verifizieren die globale
Vierer-Tabelle, deren Registrier-/Freigabepfade und den Tabellenmethoden-Eintrag
für `FUN_0812a9ca`:

| Beleg | Inhalt |
| --- | --- |
| `OSOS_runtime_table_pointer_xrefs_20261031.application.log` | Raw-Wortreferenzen auf `0x0883503c`; drei Zeigerzellen `08110e2c`, `08135320`, `0816a96c` |
| `OSOS_runtime_shared_table_registration_20261031.application.log` | Registrierung `FUN_081352fc`, Freigabe `FUN_08110e14`; zeigt auch, dass `081353fc` ein anderes Codeobjekt ist |
| `OSOS_runtime_table_registration_xrefs_20261031.application.log` | Direkte Aufrufer von Registrierer, Freigabe, Mount- und Listenerfunktionen |
| `OSOS_runtime_device_slot_registration_origin_20261031.application.log` | `FUN_0812a9ca` trägt ein Objekt ein, ruft den Mountpfad auf und markiert Erfolg |
| `OSOS_runtime_table_slot_index_semantics_20261031.application.log` | Kleinbuchstaben-Normalisierung, BPB-Parser-Rückgabe und Open-Flag |
| `OSOS_runtime_slot_exhaustion_mount_path_20261031.application.log` | Voller Tabellenslot → Index `-65`; `FUN_08200c32` stoppt den BPB-State-Zugriff, Fehlerstatus 2 wird danach als Open-Erfolg behandelt |
| `OSOS_runtime_drive_vtable_slot_method_xrefs_20261031.application.log` | Referenzen auf die Methoden der Mount-VTable; die Treffer sind deren VTable-Wörter |
| `OSOS_runtime_mount_method_table_20261031.application.log` | VTable-Wörter um `0x085056d0`, Mountmethode `0x0812a9cb` bei `+0x28`, Cleanup `0x0811ee71` bei `+0x2c` |
| `OSOS_runtime_mount_callback_pointer_scan_20261031.application.log` | Wortscan findet den Methodenzeiger in der VTable |
| `OSOS_runtime_mount_registration_xrefs_20261031.application.log` | Kein direkter Codeaufrufer für `FUN_0812a9ca`; die Funktion wird als VTable-Wort referenziert |
| `OSOS_runtime_mount_vtable_incoming_refs_20261031.application.log` | Keine im Runtime-Abbild erkannten eingehenden Referenzen auf die VTable-Region |
| `OSOS_runtime_mount_class_vtable_xrefs_20261031.application.log` | Kein roher Wortverweis auf die VTable-Basis oder die benachbarten Slots |
| `OSOS_runtime_dispatch_callbacks_20261031.application.log` | Decompilierungen von Managerregistrierung, Queue-Verarbeitung und I/O-Dispatcher |
| `OSOS_runtime_dispatch_xrefs_20261031.application.log` | Direkte Xrefs für Manageränderung, Queue-Drain und Dispatch-Tabelle |
| `OSOS_runtime_listener_callback_abi_20261031.application.log` | Queue-Knotenfeld `+4` fließt unverändert durch `FUN_081933f8`; die Präfixzuordnung wird durch die Body-Abfrage unten ergänzt |
| `OSOS_runtime_listener_oscall_thunk_20261031.application.log` | Runtime-Veneer `0x08201220` lädt die Präfixadresse `0x22005934`; kein Beleg für externen Callback-Code |
| `OSOS_runtime_listener_callback_callers_20261031.application.log` | Xrefs und Argumentquellen weiterer Aufrufer des Präfix-SVC-Wrappers |
| `OSOS_runtime_listener_queue_wrapper_callers_20261031.application.log` | Direkte Aufrufer der Präfix-Listenfunktionen für Queue-Anfügen und -Entnahme |
| `OSOS_runtime_all_runtime_list_add_callers_20261031.application.log` | Decompilierung der 12 direkten Anfüge-Aufrufstellen; die höhere Zuordnung über `FUN_081ad3a8` ist separat belegt |
| `OSOS_runtime_partition_manager_constructor_20261031.application.log` | Aufbau des 7-Slot-Partitionsmanagers und Initialisierer `FUN_08020448` |
| `OSOS_runtime_partition_manager_queue_semantics_20261031.application.log` | Queueinitialisierung, Sperr-/Kopf-/Endfelder, Entnahme und Weitergabe von Knotenfeld `+4` |
| `OSOS_runtime_partition_manager_singleton_all_callers_20261031.application.log` | Decompilierung aller 12 eindeutigen direkten Aufrufer des Partitionsmanager-Singletons |
| `OSOS_runtime_partition_manager_init_stub_20261031.application.log` | Startup-Kette; `FUN_08029e80` ist ein `bx lr`-Stub, Queue-Drain und Manageraufrufer |
| `OSOS_runtime_partition_manager_startup_refs_20261031.application.log` | Xrefs: Startup ruft den Stub als einzigen Caller; `FUN_0819039e` hat zwei direkte Caller |
| `OSOS_body_oscall_22005934_dispatch_20261031.application.log` | Korrekt zugeordneter OSOS-Body: `0x08005934` baut SVC-Befehl 2; der Handler indiziert `0x2200980c` und ruft keinen Funktionszeiger auf |
| `OSOS_body_prefix_table_pointer_20261031.application.log` | Direkter Ghidra-Speicherwert von `DAT_08001640`: `0x2200980c` |
| `OSOS_body_list_helpers_20261031.disasm.txt` | Rohdisassemblierung des korrekt adressierten Body-Listenhelfers `0x080030bc` |
| `OSOS_runtime_partition_wrapper_entrypoints_20261031.application.log` | Wrapper `FUN_082154b8`, Registrierung `FUN_0818e998` und deren Aufrufer |
| `OSOS_runtime_partition_wrapper_upstream_callers_20261031.application.log` | Aufrufer und Argumentaufbau der Wrapperpfade über `FUN_080b4e00` und `FUN_080ce8b0` |
| `OSOS_runtime_partition_subclass_cache_adapter_20261031.application.log` | Cache-Untertypkonstruktor, VTable-Zuweisung und Startup-Aufrufer |
| `OSOS_runtime_subclass_vtable_constants_20261031.application.log` | Ghidra-Speicherwerte für Cache-Untertyp- und Basisadapter-VTable-Zeiger |
| `OSOS_runtime_cache_subclass_vtable_20261031.application.log` | Wörter der Cache-Untertyp-VTable bei `0x0850b254` |
| `OSOS_runtime_partition_manager_slot_guard_20261031.application.log` | unsigned Slotgrenze `< 7` und Leerplatzbedingung in `FUN_0826384c` |
| `OSOS_runtime_partition_slot_release_20261031.application.log` | `FUN_0821545a` ruft den Slotabbau auf; `FUN_080e7e70` nullt den Managerslot und zerstört das Objekt |
| `OSOS_runtime_partition_startup_reachability_20261031.application.log` | Direkte Runtime-Xrefs der Cache-Registrierungsaufrufer |
| `OSOS_body_signal_token_svc_helpers_20261031.application.log` | Body-Wrapper: SVC `0x0d` liest Ringindex 2, SVC `0x0c` schreibt Ringwerte |
| `OSOS_body_SVC_dispatch_all_wrapper_callers_20261031.application.log` | Decompilierung der 21 erkannten direkten Request-Wrapper für `FUN_08004f14`; `FUN_08005488` bildet SVC `0x0c` |
| `OSOS_body_SVC_queue_table_globals_20261031.application.log` | Ghidra-Werte der globalen Pointer: `0x2200975c` für die 0x2c-Byte-Ringdeskriptoren und `0x2200980c` für die SVC-2-Tabelle |
| `OSOS_runtime_signal_token_helpers_20261031.application.log` | Runtime-Helfer `FUN_081ad3a8`, `FUN_081a4508`, `FUN_08222424` und SVC-Aufrufstellen |
| `OSOS_runtime_signal_token_origins_20261031.application.log` | Direkte Aufrufer und Verwendung der über Ringindex 2 geholten Kennung |
| `OSOS_runtime_SVC_queue2_api_callers_20261031.application.log` | Runtime-Importveneer für SVC-`0x0c`/`0x0d` |
| `OSOS_runtime_SVC_queue2_api_thunk_callers_20261031.application.log` | Direkte Runtime-Aufrufer der Veneers: `FUN_081a4508`/`FUN_080219fc` lesen Index 2; `FUN_080740d4` und `FUN_08222424` schreiben Index 1 bzw. 2 |
| `OSOS_runtime_SVC_queue2_writer_paths_20261031.application.log` | `FUN_08222424` schreibt eine Kennung in Ringindex 2; Aufrufer behandeln sie als Synchronisationsressource und geben sie frei |
| `OSOS_runtime_FUN_081ad3a8_callers_20261031.application.log` | Direkte Aufrufer des Synchronisationshelfers; `FUN_08268cda` übergibt `Manager + 0x34` |

Die zunächst als Listener-Callback bezeichnete Kante ist korrigiert: Das
Queue-Knotenfeld `+4` wird als Indexargument an SVC-Befehl 2 weitergereicht.
Der SVC-Handler liest damit aus `0x2200980c`; er ruft den Wert nicht als
Callback auf. Der konkrete Queue-Produzent ist nun gefunden: `FUN_08268cda`
wartet bei leerem Änderungsbyte über `FUN_081ad3a8(Manager + 0x34)`.
`FUN_081ad3a8` hängt einen Zweifeld-Datensatz direkt an die Liste bei
`Manager + 0x38`; dessen zweites Wort ist die zuvor aus Ringindex 2 geholte
Synchronisationskennung. `FUN_0819f508` entnimmt diesen Knoten und reicht
`+4` an SVC-Befehl 2 weiter. `FUN_0818e998` registriert in demselben
Singleton und ruft `FUN_0819039e`, wodurch der Manager den wartenden Pfad
weckt. Die frühere Aussage, ein Produzent sei noch nicht identifiziert,
war unvollständig: Der direkte Listenhelfer-Audit sah nicht, dass
`FUN_081ad3a8` die Listenadresse aus `Manager + 0x34` berechnet.

Die Runtime liest diese Kennung mit SVC `0x0d`, Unterindex 2, und gibt sie
mit SVC `0x0c`, ebenfalls Unterindex 2, in den internen Ring zurück. Der
sichtbare Pfad bezieht das SVC-2-Argument somit aus dem Kennungspool und
nicht aus einem MBR-Sektor. Poolbelegung, Poolkapazität und die Größe der
Tabelle bei `0x2200980c` sind im Runtime-Snapshot nicht enthalten. Der
Startup-Aufruf nach dem Singletonzugriff erreicht nur den `bx lr`-Stub
`FUN_08029e80`; `FUN_0819039e` hat weiterhin genau zwei direkte Caller:
MBR-Registrierung und Fehlerpfad.

Diese Abfragen zeigen, dass `FUN_081352fc` und `FUN_0816a928` dieselbe
Vierer-Tabelle benutzen. Sie schließen nicht die Kante vom MBR-Partitionsadapter
zum Objekt, das `FUN_0812a9ca` registriert. Der Adapter und das Tabellenobjekt
verwenden `+0x10` für unterschiedliche Werte. Die MBR-Cache-Wrap-Auswirkung
bleibt deshalb bedingt.

Der wortweise Abgleich an `DAT_0816a96c` stimmt: `3c 50 83 08` ist
little-endian `0x0883503c`. `0x0833503c` ist eine andere Snapshot-Adresse und
war zuvor irrtümlich mit dem Tabellenzeiger verwechselt worden.

Die Dateien `OSOS_body_extended_*`, `OSOS_body_full_*`,
`OSOS_body_listener_list_producer_xrefs_*`,
`OSOS_body_listener_queue_service_wrappers_*` und
`OSOS_body_queue_list_helper_refs_*` sind verworfene Explorationsabfragen und
absichtlich nicht im SHA-256-Manifest. Frühere Body-Projektläufe verwendeten
teils eine falsche Startadresse oder fehlenden Thumb-Kontext. Die oben
aufgeführten `OSOS_body_oscall_*`- und `OSOS_body_list_helpers_*`-Belege sind
davon getrennt: Ersterer stammt aus dem korrekt geladenen
`N5G_OSOS_RTOS`-Projekt, Letzterer aus einer Rohdisassemblierung des
Body-Abbilds. Die neuen `OSOS_body_SVC_*`-Abfragen stammen ebenfalls aus dem
korrekt geladenen Body-Projekt. Die gültigen Runtime-Abfragen wurden mit dem
bestehenden Projekt und `-readOnly -noanalysis` ausgeführt.

`OSOS_runtime_vtable_slot28_calls_20261031.application.log` und
`OSOS_runtime_slot28_candidate_callers_20261031.application.log` sind nicht
Teil des Manifests: Der allgemeine `ldr [object,#0x28]`/`blx`-Suchlauf ergab
viele nicht klassifizierte Feldzugriffe und keinen belastbaren
VTable-Aufrufpfad. Die beiden Dateien bleiben als verworfene Suchprotokolle
im Verzeichnis, sind aber keine Belege für die Schlussfolgerungen.

Die beiden Ghidra-Abfragen, die beim Aufruf ohne Programmauswahl beziehungsweise
mit falscher Argumentzahl abbrachen, sind ebenfalls ausgeschlossen; die
danach korrekt mit `-process osos_runtime_dram_20261025.bin` ausgeführten
Abfragen sind in der Tabelle genannt.

Jede Ghidra-Abfrage wurde mit `-readOnly -noanalysis` ausgeführt. Das
SHA-256-Manifest für diese Belege liegt unter `SHA256SUMS`.

## Ergänzung: OSOS-Bootprefix SVC-Tabellen

Die Prefix-Abgleiche liegen bereits im read-only Evidence-Set
`evidence/rtos-task-order-2026-10-29/`:

| Beleg | Inhalt |
| --- | --- |
| `OSOS_prefix_svc_queue_table_entry_words_20261031.application.log` | Statische Wörter der SVC-Tabelle am Prefix-Einstieg |
| `OSOS_prefix_svc_queue_table_pointer_words_20261031.application.log` | Pointerzellen für die SVC-Tabelle und Ringdeskriptoren |
| `OSOS_prefix_queue_pool_data_words_20261031.application.log` | Rohwerte des Queue-/Kennungspools |
| `OSOS_prefix_queue_pool_global_xrefs_20261031.application.log` | Referenzen auf die Prefix-Poolpointer |
| `OSOS_prefix_queue1_get_resource_dispatch_20261031.application.log` | Getter-/Dispatchersemantik für den Prefix-Service |

Die dort dokumentierten Nullbytes beschreiben nur den statischen Prefix-
Ausschnitt und ergeben keine Laufzeitkapazität der Eventtabelle.

## Ergänzung: OSOS-SVC-Aufrufer und Kommando `0x22`

| Beleg | Inhalt |
| --- | --- |
| `OSOS_body_signal_token_svc_helpers_20261031.application.log` | Vollständige Dispatcher-Decompilierung, einschließlich Kommando `0x22`, des unaufgerufenen `0x2e`-Initialisierers und des indirekten Calls in `0x30` |
| `OSOS_body_SVC_dispatch_all_wrapper_callers_20261031.application.log` | 21 direkte Body-Wrapper und die von ihnen gebildeten Request-Operationen |
| `OSOS_runtime_SVC_all_wrapper_refs_20261031.application.log` | Runtime-Xrefs auf die 21 Importadressen; zeigt fehlende Referenzen für `0x22005248` |
| `OSOS_runtime_SVC_wrapper_thunk_callers_20261031.application.log` | Direkte Runtime-Aufrufstellen der importierten Wrapper-Veneers |
| `OSOS_runtime_SVC_callback_service_callers_20261031.application.log` | Die drei direkten Aufrufer von Kommando `0x30` und ihre festen Zieladressen |
| `OSOS_runtime_SVC_callback_registry_callers_20261031.application.log` | Registrierung und Freigabe der Callback-Kontextpaare |
| `OSOS_runtime_SVC_callback_registry_callsites_asm_20261031.application.log` | Callsite-Instruktionen, einschließlich des auf null gesetzten vierten Arguments in `FUN_0835e444` |
| `OSOS_runtime_SVC_callback_targets_transient_20261031.application.log` | Pseudocode der Getter-, Setter- und Listenprädikat-Ziele |
| `OSOS_runtime_callback_table_globals_20261031.application.log` | Pointerwerte für Callback-Tabellen und deren außerhalb des Runtime-Dumps liegender Speicherbereich |
| `OSOS_runtime_SVC_queue_init_refs_even_odd_20261031.application.log` und `OSOS_body_queue_init_refs_even_odd_20261031.application.log` | Keine erkannten direkten Referenzen auf die Queue-Initializer-Adresse im Runtime beziehungsweise Body |
| `OSOS_runtime_SVC_command22_callers_20261031.application.log` | Pseudocode der beiden Runtime-Aufrufer von Kommando `0x22` |
| `OSOS_runtime_command22_data_window_20261031.application.log` | Werte der Konstantenpointer für die Kommando-`0x22`-Aufrufer |
| `OSOS_runtime_command22_event_list_radio_task_20261031.application.log` und `OSOS_runtime_command22_event_list_alarm_task_20261031.application.log` | Rohwerte der Listen `[0x47, 0]` und `[9, 10, 11, 0x11, 0]`, die `RadioTask` beziehungsweise `AlarmTask` an Kommando `0x22` übergeben |
| `OSOS_runtime_command22_event_list_xrefs_20261031.application.log` | Ghidra-Referenzen auf die beiden Listenbasen; bestätigt die Reads durch `FUN_08010afc` und `FUN_08010be8` |
| `OSOS_runtime_command22_registry_table_20261031.application.log` | Runtime-Wörter bei den gefundenen Thumb-Zeigern; benachbarte Strings sind keine verlässlichen Entry-/Namenspaare |
| `OSOS_runtime_command22_raw_pointer_scan_20261031.log` | Thumb-Funktionszeiger-Treffer für beide Kommando-`0x22`-Aufrufer |
| `OSOS_runtime_command22_registry_root_scan_aligned_20261031.log` | Ausgerichteter Wortscan nach direkten Zeigern auf den vermuteten Tabellenanfang; keine Treffer |
| `OSOS_runtime_command22_roots_20261031.application.log` | Direkte Xrefs auf die Konstanten und Aufruferfunktionen; keine erkannten Code-Xrefs zu den Taskfunktionen |

Der Rohscan findet die Zeiger auf `FUN_08010afc` und `FUN_08010be8` bei
`0x08014034` und `0x080140d4`. Die vorhandene BootTask-Rekonstruktion ordnet
die Funktionen `RadioTask` beziehungsweise `AlarmTask` zu und warnt, dass
Namen im Metadatenblock bei `0x08014000` nicht direkt nebenstehende
Entry-/Namenspaare bilden (`OSOS-FAT-LFN-rehost-impact-followup-2026-10-28.md`).
Die Events sind anhand der konkreten Listenwerte bestimmt; die Kapazität der
indizierten Tabelle bleibt offen.

## Ergänzung: Medienmanager-MBR-Pfad, 31.10.2026

| Beleg | Inhalt |
| --- | --- |
| `OSOS_runtime_artwork_manager_startup_callers_20261031.application.log` | Direkte Runtime-Aufrufer von `FUN_081ac420`, einschließlich des `FUN_080253f4`-Callsite-Kontexts und des zweiten, feldabhängigen Aufrufers `FUN_080eb730` |
| `OSOS_runtime_artwork_parser_bounds_20261031.application.log` | MBR-Signatur-/Partitionseintrag-Parser `FUN_080e4efc` und Aufrufer `FUN_080b123c` |
| `OSOS_runtime_artwork_mbr_chain_20261031.application.log` | Fokussierte Decompilierung von `FUN_081ac420`, `FUN_080b123c`, dem MBR-Parser `FUN_080e4efc`, dem Folgeparser `FUN_080e3f74`, der Divisionsroutine und dem Cache-Leser `FUN_0833a7fa` |
| `OSOS_runtime_artwork_raw_provider_methods_20261031.application.log` | Konstruktor/VTable des Rohproviders und Cache-Read `FUN_0833a7fa` |
| `OSOS_runtime_artwork_root_callsite_20261031.application.log` | Direkter Callsite `0x08022b18` ohne erkannte umschließende Funktion sowie Decompilierung von `FUN_080eb730` |
| `OSOS_runtime_artwork_startup_pointer_scan_20261031.application.log` | Wortscan über initialisierte Runtime-Blöcke: keine direkten Datenzeiger auf `0x08022b08`, `0x08022b09`, `0x08022b18` oder `0x080253f4`; dynamische und externe Aufrufer bleiben möglich |
| `OSOS_runtime_artwork_task_reachability_20261031.application.log` | Task-/Event-Aufrufer um `FUN_080eb730`; der Aufruf bleibt an einen Status-/Eventpfad gebunden |

Der Wrapper `FUN_080cbae0` reicht die MBR-Länge nicht an den Folgeparser
weiter. Bei einem MBR-Start `0xffffffff` ergibt der erste Lesezugriff nach der
LBA-Wrap-Arithmetik im Cache einen Quellzeiger vor dem Cachepuffer. Der Parser
muss anschließend noch eine Magic-Prüfung bestehen; dieser Pfad belegt daher
einen bedingten Out-of-bounds-Read, keine Codeausführung. Die normale
Kaltstarterreichbarkeit von `FUN_081ac420` ist nicht geschlossen.

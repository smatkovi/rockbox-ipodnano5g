# OSOS-Voice-Audio: Callback über die Eintragsliste

Stand: 28.10.2026. Read-only-Auswertung des Ghidra-Projekts `N5G_OSOS_runtime`, Programm `osos_runtime_dram_20261025.bin`. Kein Gerätezugriff, kein USB-/DFU-Zugriff und keine Firmware- oder NAND-/NOR-Änderung.

## Ergebnis

Der zuerst angenommene Null-Zeiger-Gate war unvollständig: Slot `+0x0c` derselben VTable kann `+0x2d` setzen. Damit ist der Callback-Zweig von `FUN_0820ae50` auf Methodenebene erreichbar, wenn das Objekt mit nicht-null Callback initialisiert wurde und passende wiederholte End-of-buffer-Aufrufe erhält. Der Voice-Audiopfad speichert als Callback-Wert die Adresse seines Listen-Kopffelds. `FUN_0832ca08` interpretiert anschließend den `next`-Zeiger des ersten Listenknotens als Codeadresse.

Das ist ein bestätigter Kontrollflussfehler-Kandidat. Die Thumb-Instruktionen bestätigen das Sprungziel: Der Callback lädt den Kopfknoten und danach dessen `next`-Zeiger; bei mindestens zwei Einträgen springt `BLX` auf den zweiten Heap-Knoten. Die OSOS-Starttabelle bildet den SDRAM-Heap schreibbar und ausführbar ab. Für den generischen Heappfad landet der Sprung in ARM-State: Die ersten drei Datenwörter werden wegen der zuvor gesetzten Flags übersprungen, das vierte enthält drei vom Knotencode nicht initialisierte Bytes. Damit ist Heap-Instruktionsausführung statisch möglich; eine kontrollierte Codeausführung ist noch nicht belegt. Es fehlen die Zuordnung zu einer konkreten Voice-Instanz/einem erreichbaren Datei-/Benutzerpfad und die Kontrolle bzw. Herkunft der drei Bytes.

## Listenaufbau und Callback-Wert

- `FUN_083201ec` fordert einen 16-Byte-Listenknoten an. Es setzt dessen erstes, zweites und drittes 32-Bit-Wort zunächst auf null, schreibt aber bei `+0x0c` nur ein Nullbyte. Danach erhält `+4` den Iterator und `+8` den Audioeintrag; das erste Wort wird beim Verketten als `next`-Zeiger verwendet. Die oberen drei Bytes bei `+0x0d..+0x0f` werden hier nicht initialisiert. Ein zusätzlicher 0x64-Byte-Audioeintrag wird separat angelegt. Die Knoten werden über Kontextfelder `+0x64` (Kopf) und `+0x68` (Ende) verkettet. Beim Anhängen mehrerer Quellen enthält `first->next` die Adresse des zweiten Knotens.
- `FUN_08319004` iteriert über Quellen und ruft für normale Audioquellen `FUN_0831c5f4` auf. `FUN_0831c5f4` reicht `*(param1+4)` an `FUN_083201ec` weiter. `FUN_08314b8c` iteriert bei erfolgreicher Verarbeitung zusätzlich über verkettete Parserobjekte in `param3[1]`; für jedes Objekt durchläuft `FUN_08319004` dessen Quellen. Jede normale Audioquelle kann so einen weiteren Knoten anhängen, Phrase-Quellen können rekursiv weitere Quellen verarbeiten. Mehrere Einträge sind damit strukturell möglich, aber eine konkrete Voice-Eingabe mit mindestens zwei gültigen Audioquellen in derselben Liste ist nicht nachgewiesen.
- `FUN_083227c0` setzt die VTable `0x084ff3d8` und ruft `FUN_08273cc8` mit `param5 = param1+0x64` und `param6 = param1` auf. Der Setter bei `0x0832ca20` speichert diese Werte als Callback-Feld `+0x24` und Kontext `+0x28`; der Callback-Wert ist damit nicht null.
- Die Tabelle enthält `FUN_0820ae50` bei Slot `+8`, `FUN_0832ca2e` bei Slot `+0x0c`, den Konstruktor `FUN_08273cc8` bei `+0x14`, den Setter bei `+0x20` und `FUN_0832ca08` bei `+0x28`.

## Erreichbarer Zustandsübergang

`FUN_08273cc8` setzt die Bytes `+0x2d` und `+0x2e` zunächst auf null. `FUN_0820ae50` kann am Ende eines Bereichs in den Zustandszweig gelangen, wenn `param1[6] == 0`:

1. Bei nicht-null `+0x24` setzt der erste End-of-buffer-Aufruf `+0x2c` auf eins.
2. Weitere Aufrufe erhöhen den Zähler bei `+0x30` bis fünf.
3. Beim folgenden Aufruf wird VTable-Slot `+0x0c` aufgerufen. Das ist `FUN_0832ca2e`; es setzt `+0x2d = 1`, sofern `+0x2c != 0`.
4. Beim nächsten passenden End-of-buffer-Aufruf gilt `+0x2d == 1` und `+0x2e == 0`. `FUN_0820ae50` setzt `+0x2e = 1` und ruft Slot `+0x28` auf.

Der Call über Slot `+0x28` ist somit nicht durch den normalen Setter ausgeschlossen. Die Methodebene setzt mehrere wiederholte Abschluss-/Fortschrittsereignisse voraus; ob diese Folge im konkreten Audio-Backend eintritt, ist noch offen.

## Sprungziel und mögliche Wirkung

`FUN_0832ca08` lädt `puVar1 = *(this+0x24)`. Bei der Initialisierung aus `FUN_083227c0` ist `puVar1 = &context->head`. Der Thumb-Code bei `0x0832ca12..0x0832ca18` lautet sinngemäß `r2 = *puVar1; r2 = *r2; BLX r2`: Er lädt zuerst `context->head`, dann das erste Wort des ersten Knotens (`first->next`) und verwendet diesen Wert als Sprungziel. Damit gilt:

- Bei mindestens zwei Knoten ist das Sprungziel die Adresse des zweiten Knotens im dynamischen Heap.
- Bei einem Knoten ist `first->next == 0`; der Aufruf versucht dann einen Nullsprung.
- Bei leerer Liste ist bereits die zusätzliche Dereferenzierung ungültig.

Das schließt die zuvor erwogene Möglichkeit eines Sprungs auf den dritten Knoten aus. `BLX` verwendet den Wert von `first->next` unmittelbar; ein separates Callback-Feld im Knoten wird nicht geladen.

Ein zusätzlicher Abgleich präzisiert den Sprungmodus und die ersten Bytes am Ziel:

- `FUN_083201ec` fordert für den 16-Byte-Knoten Speicher über `FUN_0818eb44(0x10)` an. `FUN_0818eb44` geht über `FUN_081935bc`/`FUN_0819680c`; im generischen Fallback rundet `FUN_08020df4` die Blockgröße mit `(size + 0xb) & ~3` auf 4 Byte und gibt den Blockanfang `+8` zurück. Die Aufteilung erfolgt ebenfalls mit 4-Byte-Schritten. Im zuvor untersuchten OSOS-Startzustand sind die Klass-pools deaktiviert, daher ist der generische Pfad maßgeblich; eine spätere Aktivierung der Pools ist hier nicht neu ausgeschlossen.
- Der Knotenpointer ist auf diesem generischen Pfad damit gerade und `BLX r2` wechselt in ARM-State; bei `BLX` register wählt Bit 0 des Zielwerts den ARM-/Thumb-State ([Arm Architecture Team](https://developer.arm.com/community/arm-community-blogs/b/architectures-and-processors-blog/posts/branch-and-call-sequences-explained)).
- `FUN_0832ca08` erreicht `BLX` über `cmp r0,#0`, einen nicht genommenen `beq` und danach ausschließlich `ldr`-Instruktionen. `r0` ist der nicht-null Callback-Wert, sodass Z=0 bleibt. Die ersten drei Wörter des Ziels sind `second->next`, der Iteratorzeiger und der Audioeintragszeiger. Bei Heapadressen im SDRAM-Fenster `0x08000000..0x0bffffff` (oder bei `next == 0`) haben diese ARM-Wörter den Condition-Code EQ; mit Z=0 werden sie nicht ausgeführt.
- `FUN_083201ec` setzt beim Knotenwort `+0x0c` nur das niedrigste Byte auf null (`*(undefined1 *)(puVar2 + 3) = 0`); die oberen 24 Bits werden dort nicht geschrieben. Der generische Fallback löscht die Nutzdaten nicht. Dieses Wort wird nach den ersten drei übersprungenen Wörtern als ARM-Instruktion geholt; danach läuft die Ausführung, sofern keine Instruktion verzweigt oder ein Abort eintritt, über das Knotenende hinaus. Die Herkunft/Kontrollierbarkeit der drei Bytes und die Nachbarallokationen bleiben ungeklärt.

Der gezielte Store-Scan im Voice-Code bestätigt den Byte-Store bei `0x0832022c`. Der weitere Word-Store bei `0x08320266` schreibt dagegen `audioEntry+0x0c`, nicht `node+0x0c`. Im Node-Lebenszyklus liest `FUN_083287ac` nur das Flagbyte bei `+0x0c`; über `FUN_0832ebe4` kann beim Aufräumen ebenfalls nur dieses Byte geschrieben werden. Das klärt die semantische Rolle des Felds als Flag, aber nicht die Herkunft der übrigen drei Bytes, wenn der Knoten angelegt wird.

## Datei-Puffer und Knotenallokation

- `FUN_0832950c` fordert zunächst einen 0x14-Byte-Wrapper an und initialisiert seine Felder. `FUN_0832ccec` ermittelt die reale Dateilänge, fordert den Datei-Puffer über den Provider bei `wrapper+0x0c` an und speichert Länge/Puffer bei `wrapper+4` und `wrapper+0x10`; danach liest es die komplette Datei in diesen Puffer. Der Puffer wird beim erfolgreichen Laden nicht sofort freigegeben, sondern bleibt bis zur Freigabe des Wrappers referenziert.
- Der Knoten wird über einen separaten 0x10-Byte-Aufruf von `FUN_0818eb44` angefordert. Im generischen Fallback werden Nutzdaten nicht genullt; die Blockgröße wird einschließlich Verwaltungsraum ausgerichtet und der zurückgegebene Nutzdatenzeiger liegt hinter dem Blockkopf. Der Dateipuffer wird im Knoten nicht direkt als `+0x0c` eingetragen: dort liegt ein ein Byte breites Besitz-/Freigabeflag. Der Audioeintrag enthält den Dateidatenzeiger und die dekodierte Länge an eigenen Feldern.
- Damit ist ein direkter Alias vom Dateiinhalt auf die drei Instruktionsbytes des Knotens nicht belegt. Eine Wiederverwendung zuvor freigegebener Heapdaten bleibt möglich, aber es fehlt weiterhin der Pfad, der gezielt drei geeignete Bytes in genau einen später als Knoten wiederverwendeten 16-Byte-Block schreibt.

## Heap-Berechtigungen der OSOS-Startabbildung

- `FUN_08005d3c` ruft den Mapper für VA `0x08000000..0x0bffffff` mit derselben physischen Basis und Attributwort `DAT_08005e3c` auf. Der read-only-Ghidra-Dump bestätigt `DAT_08005e3c = 0x00007c0e` (`evidence/voice-audio-2026-10-28/voice_audio_heap_mmu_attr_20261028.log.gz`). Das ist ein L1-Abschnittsdeskriptor mit XN-Bit 4 = 0 und APX/AP[1:0] = `0b011`.
- `FUN_08004900` setzt SCTLR.XP (Bit 23), `FUN_08004a28` setzt SCTLR.M, und `FUN_080049b0(1)` setzt Domain 0 auf Client. Im ARM1176JZF-S bedeutet XN=0, dass Code aus dem Bereich ausgeführt werden kann; APX/AP[1:0]=`011` erlaubt Lesen/Schreiben für privilegierten und unprivilegierten Code ([ARM1176JZF-S Technical Reference Manual, MMU](https://documentation-service.arm.com/static/5e8e294efd977155116a6ca3)). Damit ist der statisch eingerichtete SDRAM-Heap RWX, nicht nur im Ghidra-Segment als ausführbar markiert.
- Die Aussage gilt für den untersuchten OSOS-Startpfad und dessen Mapper-/MMU-Konfiguration. Sie beweist nicht, dass der fragliche Voice-Parser/Callback kaltstart-erreichbar ist oder dass die uninitialisierten Instruktionsbytes kontrollierbar sind.

Das ist ein genauerer Kontrollfluss-/Datenbefund mit ausführbarem Heap, aber weiterhin kein Nachweis beliebiger Codeausführung. Der AIFC-Längenunterlauf ist nicht mit dem uninitialisierten Knotenwort oder einer Kontrolle über dessen `next`-Zeiger verbunden.

Der AIFC-Längenunterlauf bleibt ein separater Parserbefund. Bisher ist nicht gezeigt, dass er den `next`-Zeiger, den Callback-Zustand oder die Knotenbelegung überschreibt.

## Ende-zu-Ende-Erreichbarkeit: Typ-0-Pfad gefunden, Instanzpfad noch zu schließen

- `FUN_0831f852` ist der einzige gefundene direkte Aufrufer von `FUN_083227c0`. Der Handler wird in `FUN_0824ac50` bei Ereignistyp `0` aufgerufen und initialisiert den Audio-Output nur, wenn `context+0x40 == 0`.
- Der benötigte Ereignistyp `0` ist nicht auf einen theoretischen Pfad beschränkt: `FUN_08263ffc` ruft bei freiem Zustand (`param1+0x54 == 0`) `FUN_082622ec` auf. Dieser Wrapper ruft `FUN_08222340(param1, 0, key)` auf. Nach einer Zuordnung über `param1+0x38` und `FUN_0825afa0` hängt `FUN_08222340` einen Eintrag mit Typbyte `0` und dem gefundenen Objektzeiger an `stream+0x2c` an.
- `FUN_08247e58` ist der Schreiber dieser 8-Byte-Ringqueue. `FUN_0824ac50` liest dieselbe Queue bei `param2+0x2c`, nimmt das Typbyte aus dem Eintrag und ruft für Typ `0` `FUN_0831f852(payload)` auf. Damit ist der Typ-0-Übergang bis zum Voice-Audiostart-Handler auf Framework-Ebene belegt. Direkte Aufrufer von `FUN_08263ffc` sind unter anderem `FUN_081ab650`, `FUN_0822eb0c`, `FUN_0823f108` und weitere Stream-/Medienpfade. Noch nicht belegt ist, welcher konkrete erreichbare Voice-Datei-/Benutzerpfad den passenden registrierten Kontext auswählt.
- `FUN_083227c0` übergibt `*(byte *)(context+0x3f)` als Konstruktorargument. Der gemeinsame Konstruktor `FUN_083209ec` setzt das 32-Bit-Wort bei `+0x3c` auf null; damit sind `+0x3d..+0x3f` initial null. Er wird unter anderem von `FUN_0827f098`/`FUN_08329618` und `FUN_08265b3c`/`FUN_082ed1ac` verwendet. Der konkrete Fabrikpfad der fraglichen Voice-Instanz und mögliche spätere Alias-/Blockschreiber sind noch zu bestätigen; ein direkter Byte-Store auf `+0x3f` wurde im geladenen Abbild nicht gefunden.
- Der Parserpfad kann pro Quelle Knoten über `FUN_083201ec` an dieselbe Liste hängen; `FUN_08319004` iteriert über Quellen und `FUN_08314b8c` über verkettete Parserobjekte. Mehrere Einträge sind strukturell möglich, aber ein erreichbarer Voice-Eingabepfad, der tatsächlich mindestens zwei gültige Audioquellen in derselben Callback-Liste ablegt, ist noch nicht nachgewiesen.
- Der Sprung bei mindestens zwei Einträgen zielt auf den zweiten Heap-Knoten; die OSOS-Startabbildung markiert den SDRAM RWX. Die ersten Knotenwörter sind Link-/Iterator-/Audioeintragszeiger, das folgende Instruktionswort ist teilweise uninitialisiert. Kontrollierbare Instruktionsbytes oder beliebige Codeausführung sind weiterhin nicht belegt. Der AIFC-Längenunterlauf ist bislang nicht mit einer Beschädigung dieser Felder verbunden.

## Parser-Factory und VTable-Erreichbarkeit

- `FUN_0830bc00` hat im Ghidra-Xref-Sweep keinen direkten Aufrufer. Der ausgerichtete Pointer-Scan findet den Thumb-Zeiger `0x0830bc01` nur als VTable-Eintrag bei `0x08538f70`. Diese Tabelle liegt bei `0x08538f64` und wird über `DAT_08314c40` referenziert; der gefundene Code setzt sie in `FUN_08314bd8` während eines Aufräum-/Destruktorpfads. Damit ist eine virtuelle Methode belegt, aber noch keine Instanziierung oder ein Aufruf beim Systemstart.
- `FUN_083294ac` ist der Factory-Kandidat, der `iMAPhraseDict` anlegt und `FUN_0832cca8` aufruft. `FUN_083294ac` hat im analysierten Programm weder direkte Aufrufer noch einen gefundenen ausgerichteten oder byte-unaligned 32-Bit-Thumb-Funktionszeiger `0x083294ad`. `FUN_0832cca8` setzt die VTable `0x085378d4` und speichert den Typnamen `iMAPhraseDict`; die beiden statischen Referenzen auf diese VTable sind der Konstruktor und ein weiterer Datensatz, der bislang nicht bis zu einer Factory-Verknüpfung verfolgt ist.
- Das ist kein Beweis, dass die Klasse zur Laufzeit nie dynamisch registriert wird: berechnete Adressen, Overlay-/Rebinding-Code oder ein nicht identifiziertes Factory-Register bleiben möglich. Im statischen Abbild fehlt aber weiterhin die Verbindung von einer Start-/Voice-Quelle zur Factory, zum Parserobjekt und zum Typ-0-Event.

## Nächste statische Schritte

1. Die dynamische Factory-Registrierung für `iMAPhraseDict` und die `FUN_0830bc00`-VTable-Instanziierung finden oder als nicht referenziert eingrenzen; danach den Pfad zur konkreten Voice-Instanz, zum `FUN_08263ffc`-Event-Key und zum Payload-Kontext schließen.
2. Die zugängliche Voice-Quelle und die Mindestzahl von zwei Listeneinträgen nachweisen; insbesondere die Datei-/Verzeichniszuordnung des Parsers klären.
3. Den AIFC-Längenunterlauf gegen `next`-Zeiger, Callback-Felder und Nachbarknoten abgrenzen.
4. Die Herkunft und mögliche Kontrolle der drei uninitialisierten Bytes in `second->+0x0c` sowie die Nachbarallokationen abbilden. Insbesondere prüfen, ob ein erreichbarer Voice-Dateipfad einen freigegebenen 16-Byte-Heapblock mit Nutzdaten präparieren kann. Die OSOS-Startabbildung belegt RWX-SDRAM; offen sind kontrollierte Instruktionsbytes, erreichbare Voice-Instanz, stabiler Callback-Zustand und Bootwirkung.

## Rohbelege

- `evidence/voice-audio-2026-10-28/voice_audio_state_dispatch_20261028.log.gz` — Zustandsmaschine, Konstruktor und Callback.
- `evidence/voice-audio-2026-10-28/voice_audio_thumb_methods_20261028.log.gz` — Thumb-Code für Setter, Slot `+0x0c` und Destruktor/Wrapper.
- `evidence/voice-audio-2026-10-28/voice_audio_list_event_context_20261028.log.gz` — Parser-/Listenpfad und Objektinitialisierung.
- `evidence/voice-audio-2026-10-28/voice_audio_object_identity_20261028.log.gz` — Voice-Kontext und Event-Handler.
- `evidence/voice-audio-2026-10-28/voice_audio_parser_context_setup_20261028.log.gz` — Kontext- und Parser-Wrapper.
- `evidence/voice-audio-2026-10-28/voice_audio_child_object_setup_20261028.log.gz` — `FUN_08325784`, `FUN_083289aa` und Eventmethoden.
- `evidence/voice-audio-2026-10-28/voice_audio_event_queue_bridge_20261028.log.gz` — Audio-Callback-Kontext und Event-Dispatcher.
- `evidence/voice-audio-2026-10-28/voice_audio_event_ring_helpers_20261028.log.gz` und `evidence/voice-audio-2026-10-28/voice_audio_queue_ring_producer_20261028.log.gz` — Ringqueue-Pop, Queue-Schreiber und Layout.
- `evidence/voice-audio-2026-10-28/voice_audio_ring_event_callers_20261028.log.gz` — drei Aufrufer des Queue-Schreibers und ihre Payloads.
- `evidence/voice-audio-2026-10-28/voice_audio_event_type_dynamic_callers_20261028.log.gz` und `evidence/voice-audio-2026-10-28/voice_audio_event0_origin_20261028.log.gz` — dynamischer Ereignistyp und fester Typ-0-Wrapper.
- `evidence/voice-audio-2026-10-28/voice_audio_registered_context_event_path_20261028.log.gz` — Registrierung, Zuordnung und Typ-0-Weiterleitung bis zum Queue-Eintrag.
- `evidence/voice-audio-2026-10-28/voice_audio_context_constructor_refs_20261028.log.gz`, `evidence/voice-audio-2026-10-28/voice_audio_context_constructor_callers_20261028.log.gz` und `evidence/voice-audio-2026-10-28/voice_audio_mode_and_source_context_20261028.log.gz` — gemeinsame Objektinitialisierung und initialer Wert von `+0x3c..+0x3f`.
- `evidence/voice-audio-2026-10-28/voice_audio_mode_byte_stores_20261028.log.gz` — Scan nach direkten Stores auf die benachbarten Modebytes; keine vollständige Alias-/Memcpy-Analyse.
- `evidence/voice-audio-2026-10-28/voice_audio_factory_context_20261028.log.gz`, `evidence/voice-audio-2026-10-28/voice_audio_mode_factory_callers_20261028.log.gz` und `evidence/voice-audio-2026-10-28/voice_audio_stream_vtable_20261028.log.gz` — geprüfte Konstruktor- und VTable-Pfade.
- `evidence/voice-audio-2026-10-28/voice_audio_080b5ee8_dispatch_20261028.log.gz` und `evidence/voice-audio-2026-10-28/voice_audio_manager_queue_20261028.log.gz` — separater allgemeiner Managerqueue-Kandidat; nicht als Voice-Ringqueue-Erzeuger gewertet.
- `evidence/voice-audio-2026-10-28/voice_audio_event_queue_producers_20261028.log.gz` — direkte Erzeuger der Queue-Nachrichten.
- `evidence/voice-audio-2026-10-28/voice_audio_event_producer_callers_20261028.log.gz` — Referenzen auf Queue-Erzeuger.
- `evidence/voice-audio-2026-10-28/voice_audio_event_producer_tables_20261028.log.gz` und `evidence/voice-audio-2026-10-28/voice_audio_event_producer_methods_20261028.log.gz` — Queue-VTable-Einträge und Typmethoden.
- `evidence/voice-audio-2026-10-28/voice_audio_event_type_constants_20261028.log.gz` — geprüfte Konstanten `0x205..0x207` anderer Erzeuger.
- `evidence/voice-audio-2026-10-28/voice_audio_event_raw_pointer_refs_20261028.log.gz` — rohe Codezeiger-Referenzen für Event-Helfer und Handler.
- `evidence/voice-audio-2026-10-28/voice_audio_dispatch_owner_20261028.log.gz` — Besitzer/Dispatch-Aufrufstellen des Event-Loops.
- `evidence/voice-audio-2026-10-28/voice_audio_same_queue_event_calls_20261028.log.gz` — Parameter der Ereignis-IDs `0x205..0x207`.
- `evidence/voice-audio-2026-10-28/voice_audio_memory_map_20261028.log.gz` — Eigenschaften des geladenen Runtime-Abbilds; keine Aussage zu dynamischem Heap.
- `evidence/voice-audio-2026-10-28/voice_audio_callback_linkage_20261028.log.gz`
- `evidence/voice-audio-2026-10-28/voice_audio_context_and_vtable_20261028.log.gz`
- `evidence/voice-audio-2026-10-28/voice_audio_slot28_callers_20261028.log.gz`
- `evidence/voice-audio-2026-10-28/voice_audio_embedded_flag_writers_longwindow_20261028.log.gz`
- `evidence/voice-audio-2026-10-28/voice_audio_phrase_multi_source_check_20261028.log.gz` — erneuter Abgleich der Parser-/Quellenschleifen, `FUN_083201ec` und Factory-Referenzen.
- `evidence/voice-audio-2026-10-28/voice_audio_thumb_methods_20261028.log.gz` und `evidence/voice-audio-2026-10-28/voice_audio_state_dispatch_20261028.log.gz` — frühere Methoden-/Pseudocodeauszüge. Der gezielte temporäre Thumb-Disassemblybeleg zu `FUN_0832ca08` liegt in `evidence/voice-audio-2026-10-28/voice_audio_callback_target_thumb_20261028.log.gz`.
- `evidence/voice-audio-2026-10-28/voice_audio_parser_entrypoint_refs_20261028.log.gz`, `evidence/voice-audio-2026-10-28/voice_audio_parser_factory_raw_ptr_scan_20261028.log.gz`, `evidence/voice-audio-2026-10-28/voice_audio_phrase_class_registry_20261028.log.gz`, `evidence/voice-audio-2026-10-28/voice_audio_phrase_vtable_trace_20261028.log.gz`, `evidence/voice-audio-2026-10-28/voice_audio_phrase_vtable_refs_20261028.log.gz` und `evidence/voice-audio-2026-10-28/voice_audio_voice_parser_class_methods_20261028.log.gz` — direkte Xrefs, aligned Pointer-Scans, Tabelleninhalte und Parser-VTable-Methoden.
- `evidence/voice-audio-2026-10-28/voice_audio_node_allocator_alignment_20261028.log.gz`, `evidence/voice-audio-2026-10-28/voice_audio_allocator_core_20261028.log.gz`, `evidence/voice-audio-2026-10-28/voice_audio_allocator_core2_20261028.log.gz`, `evidence/voice-audio-2026-10-28/voice_audio_allocator_core3_20261028.log.gz`, `evidence/voice-audio-2026-10-28/voice_audio_allocator_alignment_impl_20261028.log.gz` und `evidence/voice-audio-2026-10-28/voice_audio_allocator_alignment_helpers_20261028.log.gz` — Knotenallokation, Fallbackpfad, 4-Byte-Rundung und Blocksplitter.
- `evidence/voice-audio-2026-10-28/voice_audio_heap_mmu_attr_20261028.log.gz`, `evidence/voice-audio-2026-10-28/voice_audio_mmu_control_bits_20261028.log.gz` und `evidence/voice-audio-2026-10-28/voice_audio_mmu_enable_sequence_20261028.log.gz` — SDRAM-Attributwort, XP-/MMU-Steuerbits, TLB- und Domain-Setup.
- `evidence/voice-audio-2026-10-28/voice_audio_file_buffer_allocators_20261028.log.gz`, `evidence/voice-audio-2026-10-28/voice_audio_file_loader_vtable_20261028.log.gz` und `evidence/voice-audio-2026-10-28/voice_audio_file_loader_vtable_methods_20261028.log.gz` — Voice-Dateipufferallokation, Datei-/Readerobjekt und dessen VTable.
- `evidence/voice-audio-2026-10-28/voice_audio_node_tail_write_sweep_20261028.log.gz`, `evidence/voice-audio-2026-10-28/voice_audio_node_list_lifecycle_20261028.log.gz`, `evidence/voice-audio-2026-10-28/voice_audio_alloc_free_semantics_20261028.log.gz`, `evidence/voice-audio-2026-10-28/voice_audio_node_lifecycle_refs_20261028.log.gz`, `evidence/voice-audio-2026-10-28/voice_audio_node_ctor_disasm_20261028.log.gz` und `evidence/voice-audio-2026-10-28/voice_audio_factory_unaligned_scan_20261028.log.gz` — Store-Scan, Knoten-/Aufräumfunktionen, Allokatorpfad, unaligned Pointer-Scan und Instruktionsabgleich.
- `evidence/voice-audio-2026-10-28/voice_audio_loader_call_abi_20261028.log.gz` — Disassemblierung der Argumentübergabe an den Phrase-Datei-Loader.

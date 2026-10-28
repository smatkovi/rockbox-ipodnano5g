# OSOS-Voice-Audio-Parser: Längenprüfung und Chunk-Überlauf

Stand: 28.10.2026. Read-only-Auswertung des Ghidra-Projekts `N5G_OSOS_runtime`, Programm `osos_runtime_dram_20261025.bin`. Verwendet wurden `analyzeHeadless` mit `-noanalysis -readOnly`. Kein Gerätezugriff, keine Firmwareänderung und kein NAND-/NOR-Schreib- oder Löschzugriff.

## Ergebnis

Im Voice-Audio-Ladepfad sind zwei statisch bestätigte Parserfehler sichtbar:

1. Der AIFC-Parser verwendet die im `FORM`-Header deklarierte Länge als Chunk-Suchgrenze, ohne sie gegen die reale Dateilänge abzugleichen. Der Dateipuffer und seine tatsächliche Länge werden zwar an den Parser übergeben, die tatsächliche Länge wird danach nur auf ungleich null geprüft.
2. Der RIFF/WAVE-Fallback kann bei einem unbekannten ersten Chunk mit Längenfeld `0xfffffff8` in einer Endlosschleife hängen bleiben: Der Chunk-Zeiger bewegt sich wegen 32-Bit-Wraparound nicht, und die Schleifenbedingung bleibt für eine mindestens 20 Byte lange Datei wahr.

Das belegt fehlerhafte Längenbehandlung und mögliche Speicherüberlesungen beziehungsweise einen Hänger im Parser. Es belegt weder beliebige Codeausführung noch einen Weg zum untethered Rockbox-Start. Die Laufzeit-Erreichbarkeit des Voice-Loaders und die Kontrolle über die gelesenen Dateien sind weiterhin offen.

## AIFC-Pfad

- `FUN_0832f3c0` ist `iMAAPAudioSource::LockForPlay`. Wenn noch kein Parserobjekt vorliegt, ruft `FUN_083294da` zuerst `FUN_0832ced2` und bei dessen Fehlschlag `FUN_0832cea2` auf.
- `FUN_0832ced2` erzeugt den ersten Codec-Parser und ruft `FUN_08330db0` auf. `FUN_08330db0` bekommt den Dateizeiger aus Objekt-Offset `+4` und die reale Dateilänge aus `+8`. Die Länge wird nur auf null geprüft; Chunk-Suche und Validierung verwenden sie nicht.
- `FUN_081e4c4c` prüft die Big-Endian-Magics `FORM` und `AIFC` bei Offset `0` und `8`. `FUN_08332502` liest anschließend die deklarierte `FORM`-Länge bei Offset `4` und berechnet daraus das Suchende. `FUN_0833259c` läuft ab Offset `12` bis zu diesem Ende, ohne das Ende mit dem tatsächlichen Pufferende zu vergleichen.
- `FUN_083321e4` sucht so einen `COMM`-Chunk; `FUN_08332234` sucht einen `SSND`-Chunk. Der `SSND`-Suchpfad prüft den Chunk-Tag, aber nicht, ob dessen deklarierter Inhalt in der realen Datei liegt. Die zugehörigen Getter `FUN_08332128` und `FUN_0833213e` liefern `SSND+16` und `Chunkgröße-8`; eine Untergrenze von 8 oder eine Begrenzung auf die reale Dateilänge ist in diesen Funktionen nicht sichtbar.
- Der Rückgabepfad ist teilweise verfolgt: `FUN_0831c420` erstellt einen Iterator mit VTable `0x08537ea0`. `FUN_083201ec` ruft über Iterator-Slot `+0x20` den Lock-Pfad `FUN_0832ce04` → `FUN_08329230` auf. Die Iterator-Slots `+8` und `+0x10` delegieren über `FUN_0832cddc` und `FUN_0832cdf0` an die Getter des aktuellen Audioquell-Objekts. Für AIFC gelangen dadurch der `SSND`-Datenzeiger und `Chunkgröße-8` in den bei `FUN_083201ec` angelegten 0x64-Byte-Eintrag, an die Offsets `+4` und `+0xc`.
- Damit ist ein `SSND`-Längenunterlauf bis in einen Audioeintrag belegt. Der konkrete Verbraucher dieses Eintrags im Wiedergabebackend ist noch nicht mit derselben Sicherheit verfolgt. Die nahe Funktion `FUN_08332354` ist dafür kein Beleg: Sie füttert über `FUN_08240ac8` den XML-Parser `FUN_082779c8`. Eine Schreiboperation, kontrollierte Heap-Überschreibung oder Ausführung eines manipulierten Funktionszeigers ist weiterhin nicht belegt.

## RIFF/WAVE-Fallback

- Die Konstanten bei `0x08330da0..0x08330dac` bestätigen `RIFF`, `WAVE`, `fmt ` und `data`. `FUN_08330d40` prüft zunächst `RIFF`/`WAVE` und sucht danach `fmt ` und `data` über `FUN_083320ce`.
- `FUN_081e4ad8` liest wie `FUN_081e4d98` einen 32-Bit-Wert little-endian. `FUN_083320ce` addiert den Chunk-Zeiger mit dem gelesenen Längenfeld und danach `8`, prüft aber nicht auf arithmetischen Überlauf.
- Bei einer mindestens 20 Byte langen RIFF/WAVE-Datei mit einem ersten Chunk-Tag ungleich `fmt ` und dem little-endian Chunk-Längenfeld `0xfffffff8` ist `Länge+8` modulo `2^32` gleich null. Der Zeiger bleibt daher auf demselben Chunk. Die Schleifenprüfung vergleicht danach erneut denselben Zeiger mit `Pufferanfang+Dateilänge`; bei einer Dateilänge über 12 Byte ist sie wahr. Die erste Suche nach `fmt ` terminiert dann nicht.
- Der Effekt ist ein synchroner Hänger in dieser Parserfunktion. Ein Watchdog-Reset, eine dauerhafte Gerätesperre oder weitere Folgen sind statisch nicht nachgewiesen.

## Erreichbarkeit und Auswirkung

- `FUN_0832950c` erzeugt den Datei-/Audioquell-Wrapper und lädt den gesamten ermittelten Dateiumfang; `FUN_0832ccec` prüft, dass der Dateileser genau diese Länge zurückgegeben hat. Eine Format-spezifische Obergrenze ist dort nicht sichtbar.
- Der einzige direkte Aufrufer von `FUN_0832950c` ist `FUN_08325be4`. Dieser baut Pfade unter `/iPod_Control/Device/voices/` oder `/Resources/Voices/` zusammen. `FUN_08325be4` wird direkt von `FUN_0832cc04` aufgerufen; dessen Wrapper ist `FUN_08320794` im `iMAPhraseDict`-Pfad.
- Wie bereits in `OSOS-accessories-remote-dispatch-followup-2026-10-28.md` festgehalten, ist der Factory-Pfad `FUN_083294ac` für `iMAPhraseDict` im Runtime-Abbild weiterhin nicht bis zu einer lebenden Instanz verfolgt. Ein vom Benutzer kontrollierbarer Dateieintrag und ein erreichbarer Audio-Play-Aufruf sind damit nicht bewiesen.
- Die problematische Länge wird in einen Audioeintrag übernommen; ob ein nachgelagerter Audiopfad sie nur liest, abstürzt oder in einer separaten Kopier-/Allokationsroutine eine Schreibprimitive erzeugt, ist offen. Kein Weg von diesen Befunden zu beliebigem Code, zum Ändern der Bootkette oder zu untethered Rockbox wurde bestätigt.

## Nächste Schritte

1. Die Instanziierung und den Dispatch von `iMAPhraseDict` weiter verfolgen; parallel klären, ob Benutzerdateien in den beiden Voice-Verzeichnissen tatsächlich vom OSOS verarbeitet werden.
2. Die Feldzugriffe auf den 0x64-Byte-Eintrag aus `FUN_083201ec` bis zum tatsächlichen Wiedergabe-Backend verfolgen. Besonders prüfen, ob `Chunkgröße-8` bei `SSND` in einer Allokation oder Kopie verwendet wird.
3. Falls statisch ein stabiler, nicht persistenter Testpfad belegt wird, zuerst mit einer isolierten Kopie oder einem geeigneten Emulator validieren. Ein Gerätetest wäre nur ein Parser-/Verfügbarkeitsnachweis, kein Nachweis für Codeausführung oder untethered Boot.

## Rohbelege

- `evidence/voice-audio-2026-10-28/voice_riif_consts_20261028.log.gz`
- `evidence/voice-audio-2026-10-28/voice_riif_consumers_20261028.log.gz`
- `evidence/voice-audio-2026-10-28/voice_riif_refs_20261028.log.gz`
- `evidence/voice-audio-2026-10-28/voice_riif_codecs_20261028.log.gz`
- `evidence/voice-audio-2026-10-28/voice_riif_vtables_20261028.log.gz`
- `evidence/voice-audio-2026-10-28/voice_riif_vmethods_20261028.log.gz`
- `evidence/voice-audio-2026-10-28/voice_riif_consumers2_20261028.log.gz`
- `evidence/voice-audio-2026-10-28/voice_riif_reach_20261028.log.gz`
- `evidence/voice-audio-2026-10-28/voice_riif_aiff_constants_20261028.log.gz`
- `evidence/voice-audio-2026-10-28/voice_riif_primary_parser_20261028.log.gz`
- `evidence/voice-audio-2026-10-28/voice_riif_primary_helpers_20261028.log.gz`
- `evidence/voice-audio-2026-10-28/voice_riif_pipeline_20261028.log.gz`
- `evidence/voice-audio-2026-10-28/voice_riif_source_wrappers_20261028.log.gz`
- `evidence/voice-audio-2026-10-28/voice_riif_wrapper_disasm_20261028.log.gz`
- `evidence/voice-audio-2026-10-28/voice_riif_entry_consumers_20261028.log.gz`
- `evidence/voice-audio-2026-10-28/voice_audio_descriptor_type_20261028.log.gz`
- `evidence/voice-audio-2026-10-28/voice_audio_iterator_methods_20261028.log.gz`
- `evidence/voice-audio-2026-10-28/voice_audio_backend_followup_20261028.log.gz`
- `evidence/voice-audio-2026-10-28/voice_audio_node_vtable_20261028.log.gz`
- `evidence/voice-audio-2026-10-28/voice_audio_node_methods_20261028.log.gz`
- `evidence/voice-audio-2026-10-28/voice_audio_backend_vtables_20261028.log.gz`
- `evidence/voice-audio-2026-10-28/voice_audio_stream_consumer_20261028.log.gz`

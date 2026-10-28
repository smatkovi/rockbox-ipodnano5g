# OSOS-Voice-Audio: Heapwiederverwendung am Callbackknoten

Stand: 28.10.2026. Ausschließlich read-only-Ghidra am persistenten Projekt
`N5G_OSOS_runtime_analysis`, Programm `osos_runtime_dram_20261025.bin`.
Kein Geräte-, USB-, DFU-, Boot-, Firmware- oder NAND-/NOR-Zugriff.

## Ergebnis

Die drei zuvor ungeklärten Bytes im Instruktionswort eines Voice-Callbackknotens
könnten aus einem zuvor freigegebenen Clip-Puffer stammen. Beim Zerstören des
Audioquellobjekts ruft `FUN_08332014` den Freigabecallback der Provider-VTable
bei `source+0x0c`, Slot `+0x10`, auf; `FUN_08329266` kann bei Ersetzung den
bisherigen Eintrag zerstören. Unabhängig davon ist die Knotenkonstruktion
unvollständig: Sie schreibt nur das erste Byte des Wortes bei `node+0x0c`.

Für den generischen OSOS-Heap ergibt sich eine konkrete, aber bedingte
Überlappung: Ein 36-Byte-Puffer belegt einen 44-Byte-Heapblock. Nur falls der
Clip-Provider denselben generischen Heap nutzt, der Provider beim Freigeben und
die Neubelegung die Nutzdaten nicht bereinigen und dieser Block anschließend
für den 12-Byte-Iterator und den 16-Byte-Knoten wiederverwendet wird, bleiben
die alten Bytes an `node+0x0d..0x0f` erhalten. Diese Bytes würden beim bereits
beschriebenen Callbackpfad als Teil einer ARM-Instruktion am zweiten Knoten
ausgeführt.

Das ist eine neue Heap-Reuse-Hypothese, keine bestätigte kontrollierte
Codeausführung. Der Clip-Puffer verwendet einen virtuellen Provider bei
`source+0x0c`; dessen Laufzeitimplementierung wurde nicht mit dem generischen
Knotenallocator gleichgesetzt. Außerdem sind die Ersetzungsreihenfolge, der
Benutzerzugriff auf den Dateipfad, der Factory-/Kaltstartpfad und die stabile
Callbackauslösung offen. Es gibt weiterhin keinen belegten Rockbox-Handoff.

## Freigabe des Clip-Puffers

`FUN_0832950c` legt einen Audioquellwrapper an und ruft `FUN_0832ccec` zum
Öffnen und vollständigen Lesen der Datei auf. `FUN_0832ccec` speichert die
ermittelte Dateilänge bei `source+4`, den Provider bei `source+0x0c` und den
Pufferzeiger bei `source+0x10`. Die Pufferanforderung läuft über Provider-Slot
`+0x0c`; ein Fehler beim vollständigen Read gibt ihn über Slot `+0x10` frei.
`FUN_0832950c` übernimmt diesen Provider als drittes Argument in
`source+0x0c`. Der Voice-Ladepfad reicht dort den von der `iMAPhraseDict`-
Instanz gehaltenen Handle aus `param+4` durch; dessen konkrete Laufzeit-VTable
ist im Runtimeabbild nicht identifiziert.

Der Destruktor im Audiowrapper ist `FUN_0832f488 -> FUN_08330d28 ->
FUN_08332014`. Die Cleanup-Routine gibt einen vorhandenen Parserkontext bei
`source+8` frei. Falls der Provider bei `source+0x0c` gesetzt ist, ruft sie
dessen Slot `+0x10` mit dem gespeicherten Puffer bei `source+0x10` auf und
setzt anschließend Puffer und Länge zurück. Damit ist der Aufruf zur Freigabe
des Puffers im Objektlebenszyklus belegt, nicht aber, welcher Allocator hinter
dem virtuellen Provider-Slot steckt oder ob dieser den Pufferinhalt vor der
Rückgabe löscht.

Die separat beobachtete `FUN_08191cdc` am Ende von `FUN_0832f488` gibt den
Audioquellwrapper selbst frei. Sie ist nicht der Freigabepfad des Clip-Puffers;
diesen bildet ausschließlich der Provider-Aufruf aus `FUN_08332014` ab.

Auch ein Ersetzungspfad existiert: `FUN_08329266` ruft bei Zustand 1 den
Destruktor des bisherigen Objekts auf, bevor es den neuen Clipzeiger speichert.
Eine Ersetzung kann somit einen zuvor geladenen Clip-Puffer freigeben. Nicht
gezeigt ist, dass ein extern kontrollierter Datensatz diesen Pfad mit einer
geeigneten Reihenfolge auslöst.

## Überlappungsrechnung für den generischen Heap

Der bereits verfolgte Knotenpfad lautet `FUN_08319004 -> FUN_0831c5f4 ->
FUN_083201ec`. `FUN_08319004` reserviert für den Iterator zunächst `0x0c` Byte.
`FUN_083201ec` reserviert danach `0x10` Byte für den Listenknoten. Der Knoten
schreibt seine drei ersten Wörter vollständig, setzt aber bei `+0x0c` nur ein
Nullbyte.

Im geprüften generischen Fallback rechnet `FUN_08020df4` die Blockgröße als
`(requested + 0x0b) & ~3`, mindestens `0x10`. Daher:

| Anforderung | Gesamtblock | Ergebnis |
|---|---:|---|
| 36-Byte-Clip-Puffer | 44 Byte (`0x2c`) | genug Platz für beide Folgeblöcke |
| 12-Byte-Iterator | 20 Byte (`0x14`) | oberer Teil des freien Blocks |
| 16-Byte-Knoten | 24 Byte (`0x18`) | verbleibender unterer Teil |

Wenn der 44-Byte-Block als erster passender freier Block gefunden wird, teilt
der Allocator für den Iterator die 20 Byte am oberen Ende ab und hängt den
24-Byte-Rest unten wieder in die Freiliste ein. Die folgende Knotenanforderung
passt genau in diesen Rest. Dessen Nutzdaten beginnen dann an der früheren
Pufferadresse. Der Knotenkonstruktor überschreibt die Bytes `0..12`; die
Bytes `13..15` des alten Puffers können stehen bleiben, falls der Provider
denselben generischen Heap verwendet und weder Freigabe noch Neubelegung diese
Bytes bereinigen.

Der vorherige Callbackbericht belegt, dass bei mindestens zwei Knoten
`FUN_0832ca08` über `head->next` auf den zweiten Heapknoten springt. Der
generische Heap liefert 4-Byte-ausgerichtete Nutzdaten, also ARM-State. Nach
den drei bedingungslos übersprungenen Zeigerwörtern erreicht die Ausführung
das nur teilweise initialisierte Wort bei `+0x0c`. Bei der berechneten
Überlappung stammen dessen obere drei Bytes aus den alten Pufferbytes 13–15.

Die Wirkung eines passenden Wortes wurde separat mit `arm-none-eabi-objdump`
dekodiert. Wenn die drei übernommenen Bytes `f0 92 e5` sind, ergibt das
zusammen mit dem vom Konstruktor gesetzten Nullbyte das ARM-Wort
`0xe592f000` (`ldr pc, [r2]`). Beim Eintritt aus `FUN_0832ca08` enthält `r2`
die Adresse des zweiten Knotens. Die Instruktion lädt daher dessen `next`-
Zeiger: Bei mindestens drei Listenknoten springt sie zum dritten Knoten; bei
genau zwei lädt sie null. Das belegt eine konkrete, bedingte Listen-Weiterleitung,
aber keinen Sprung in den Clippuffer oder beliebigen Code. Für den Folgeknoten
und eine Fortsetzung der Ausführung müssten dessen Instruktionswort und
Heapzustand separat passen.

## Ungeklärte Voraussetzungen

1. Der Clip-Puffer benutzt `source+0x0c` als Providerinterface. `FUN_08332014`
   ruft dessen Slot `+0x10` zum Freigeben auf. Provideridentität und
   Freigabeverhalten sind offen; die Freigabe des separaten Audioquellwrappers
   über `FUN_08191cdc` belegt sie nicht. Die Überlappungsrechnung gilt nur,
   falls der dynamische Provider denselben generischen Heap verwendet und die
   Bytes 13–15 weder beim Freigeben noch bei der Wiederbelegung bereinigt.
2. `FUN_08329266` belegt das Freigeben bei Ersetzung, aber nicht, dass eine
   vom Benutzer beeinflussbare Voice-Eingabe diesen Zustand oder die benötigte
   Folge erreicht.
3. Der statische Voice-Loader bildet Pfade unter `iPod_Control/Device/voices/`
   und `Resources/Voices/`. Der erste Pfad läuft durch den bereits bekannten
   FAT-LFN-Auflöser; dessen erfolgreiche Auflösung für den externen Pfad ist
   nicht bestätigt. Der zweite Pfad ist kein nachgewiesener benutzerbeschreib-
   barer Speicherbereich.
4. `FUN_083294ac`, der Kandidat für die `iMAPhraseDict`-Factory, hat im
   Runtimeprojekt weiterhin keine direkten Caller oder gefundenen absoluten
   Thumb-Zeiger. Die Voice-Instanz, der Type-0-Eventeingang und ein automatischer
   Startpfad sind nicht geschlossen.
5. Die mehrstufige End-of-buffer-Zustandsfolge und der Übergang des möglichen
   Instruktionsstroms in einen Rockbox-Lader wurden nicht nachgewiesen.

Bewertung: Der frühere Befund steigt von „uninitialisierte Bytes unbekannter
Herkunft“ auf „mögliche kontrollierte Teilinitialisierung nach Heap-Reuse“.
Provideridentität und Ende-zu-Ende-Erreichbarkeit verhindern weiterhin eine
belastbare RCE-Aussage.

## Belege

Die Rohlogs liegen rebootfest und komprimiert unter
`evidence/voice-audio-2026-10-28/`; die neuen Ghidra-Abfragen wurden direkt in
diesen persistenten Ordner geschrieben. Die zugehörigen Dateinamen sind:

- `OSOS_voice_file_node_lifetime_followup_20261028.log`
- `OSOS_voice_buffer_free_and_audio_parser_followup_20261028.log`
- `OSOS_voice_audio_source_lifecycle_followup_20261028.log`
- `OSOS_voice_parser_source_ownership_followup_20261028.log`
- `OSOS_voice_heap_reuse_primitives_followup_20261028.log`
- `OSOS_voice_file_provider_allocator_identity_20261028.log`
- `OSOS_voice_allocator_vtable_pointer_scan_20261028.log`
- `OSOS_voice_file_provider_constructor_refs_20261028.log`
- `OSOS_voice_resource_handle_construction_followup_20261028.log`
- `OSOS_voice_factory_call_abi_followup_20261028.log`
- `OSOS_voice_provider_constructor_and_release_chain_20261028.log`
- `voice_partial_instruction_decode_20261028.log` und
  `voice_partial_instruction_sample_20261028.bin` (synthetische
  Disassemblierung, kein Geräte-/Firmwaretest)
- `OSOS_voice_file_vtable_and_path_constants_20261028.log`
- `OSOS_voice_string_inventory_20261028.log`

Die früheren Voice-Berichte führen nun ebenfalls auf die persistenten,
verlustfrei komprimierten Kopien der 132 zugrunde liegenden `/tmp/voice_*`
Rohlogs. `SHA256SUMS` im Belegordner deckt die Belege und diesen Bericht ab.

## Nächste statische Schritte

1. Die konkrete Providerimplementierung für `iMAPhraseDict` bis zu ihrer
   Fabrik-/Handle-Quelle verfolgen und feststellen, ob Slot `+0x0c` denselben
   Heap wie `FUN_0818eb44` nutzt.
2. Den Wert und Lebenszyklus des Zustandsfelds in `FUN_08329266` bis zum
   dateigesteuerten Parser verfolgen; prüfen, ob ein erreichbarer doppelter
   Clip-/Phraseeintrag tatsächlich den alten Wrapper zerstört.
3. Für den Pfad `iPod_Control/Device/voices/` die LFN-Komponentenfolge und den
   möglichen alternativen 8.3-/Ressourcenpfad anhand der bereits erhobenen
   FAT-Belege abgrenzen.
4. Erst wenn Provider, Freigabereihenfolge und Voice-Starttrigger geschlossen
   sind, die Instruktionswirkung und einen möglichen Laderübergang bewerten.

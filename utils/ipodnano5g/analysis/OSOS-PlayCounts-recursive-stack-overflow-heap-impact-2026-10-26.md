# `Device/PlayCounts`: Rekursionsgrenze und Heap-Auswirkung

Stand: 26.10.2026. Statische Prüfung des OSOS-Runtime-Abbilds und isolierter
QEMU-Test der unveränderten Rekursionsfunktion. Das angeschlossene Gerät wurde
nur lesend abgefragt; es gab keine Dateiänderung, keinen Neustart und keine
NAND-/NOR-/Flashoperation.

## Verifizierte Kette

`TEAppShell::FUN_08028254` ruft während des MainApp-Kaltstarts
`FUN_081afbcc(..., 0)` auf. Dieser Modus öffnet
`iPod_Control/Device/PlayCounts` zum Lesen. Unbekannte Tags mit Oberbyte
`0x40` werden an `FUN_0826dca0` übergeben. Diese Funktion rekursiert bis zu
einem passenden Endtag mit Oberbyte `0xc0`; ein Rekursionstiefenzähler oder
Gesamtdateilimit ist in den untersuchten Funktionen nicht sichtbar.

Jeder Rekursionsrahmen führt `push {r2,r3,r4,r5,r6,lr}` aus und belegt
24 Byte. Die zwei Token-Reads schreiben in `sp` und `sp+4`; der gespeicherte
LR bei `sp+0x14` wird dadurch nicht direkt überschrieben. Der Stackgrößenwert
des MainApp-Tasks ist `0x20000` (128 KiB). Für eine vollständig ausgeglichene
verschachtelte Struktur benötigt die ideale Tokenfolge ungefähr acht Bytes je
Ebene: ein Start- und ein Endtoken. Etwa 5.461 Ebenen entsprechen somit
ungefähr 43,7 KiB an Tokens. Da der echte Taskstack vor dem Importer bereits
Caller-Frames enthält, kann die reale Grenze früher erreicht werden.

## Hosttest der unveränderten Funktion

Für den Test wurden die 0x86 Bytes der Funktion `FUN_0826dca0` direkt aus
`/tmp/osos_runtime_dram_20261025.bin` eingebunden. Nur der Stream-Read-Callback
`FUN_0826dd26` wurde durch einen kleinen Teststub ersetzt, der denselben
Tokenpuffer beschreibt und den zusätzlichen 8-Byte-Callbackframe abbildet.
Der Stack war synthetisch auf 128 KiB begrenzt; unterhalb lag eine
beschreibbare Testseite. Ein simuliertes Chunk-Headerwort bei `stack-8` wurde
vorher auf `0x00020008` gesetzt.

- Tiefe 5.461: kleinster Callback-SP liegt genau an der angenommenen
  Stackunterkante.
- Tiefe 5.462: der kleinste Callback-SP liegt 24 Byte unter der Unterkante;
  bei `stack-8` erscheint der parserabhängige Wert `0x00123456` statt des
  anfänglichen Chunkgrößenworts. Das Folgewort wird durch die feste
  Parser-Rücksprungadresse `0x0826dce5` ersetzt.
- Tiefe 5.462 benötigt in diesem Tokenmodell 43.696 Bytes einschließlich des
  äußeren Starttokens.

Damit zeigt die Emulation einen kontrollierten Schreibzugriff unterhalb des
synthetischen Stackblocks und eine Beschädigung des dort modellierten
Allocator-Headers. Sie beweist weder die konkrete Stackadresse oder
Nachbarallokation auf dem iPod noch eine PC/LR-Übernahme oder Codeausführung.
Der Readerstub ersetzt außerdem den echten Datei-/VFS-Pfad.

## Allocator und mögliche Folgewirkung

`FUN_081a5b80(0x20000)` führt über `FUN_081935bc` in den gemeinsamen
OSOS-Heap. Die sechs spezialisierten Größenklassen reichen laut
`FUN_0801e770` nur bis zu den eingetragenen Grenzwerten 1 bis 6; die
128-KiB-Anforderung landet daher im generischen Fallback `FUN_08020df4`.
Dieser rundet die Größe auf `0x20008` und gibt den Chunkanfang plus acht Byte
zurück. Das Wort bei `stack-8` ist das Größenfeld des Chunks.

Der generische Freigabepfad `FUN_0802502a` liest `userptr-8`, markiert den
Chunk frei und berechnet aus dem gespeicherten Größenwert den nächsten Block,
um benachbarte freie Chunks zusammenzuführen. Ein beschädigter Header wäre
daher relevant, falls der Taskstack später freigegeben wird. Der
`MainAppTask` läuft nach `FUN_080202d8` in einer Eventschleife
(`FUN_08025154`); dass der erfolgreiche Import den Task beendet oder seinen
Stack regulär freigibt, ist nicht belegt.

Der Task-Wrapper reserviert Stack und ein 0x44-Byte-Taskobjekt nacheinander
über denselben Heap. Der generische Allocator wählt jedoch den ersten passenden
freien Chunk aus einer nach Größe sortierten Liste. Ohne den konkreten
Laufzeit-Heapzustand ist deshalb nicht nachgewiesen, dass das Taskobjekt direkt
unter dem Stack liegt. Der QEMU-Test bildet diese mögliche Nachbarschaft nicht
ab.

## Gerät und Testgrenze

Aktuelle rein lesende Geräteabfrage: `05ac:1265` (iPod nano 5G), Partition
`/dev/sda1` unter `/tmp/ipod-current-ro` mit Mountoption `ro`. In
`iPod_Control/Device` ist keine `PlayCounts`-Datei vorhanden. Das Gerät stellt
Apples USB-Datenträgermodus bereit; der Zustand der normalen Displayoberfläche
ist über USB allein nicht feststellbar.

Ein Gerätetest müsste `PlayCounts` auf der Datenpartition anlegen und den
MainApp-Kaltstart auslösen. Das kann einen Absturz verursachen und dadurch
manuelle Wiederherstellung bis hin zu DFU nötig machen. Deshalb wurde dieser
Test nicht am Gerät ausgelöst. Für eine spätere Prüfung sind zuvor eine
Rücksetz-/Wiederherstellungsmöglichkeit, ein Backup und eine Bestätigung des
Kaltstart-Testfensters erforderlich.

## Bewertung und nächste Schritte

Bestätigt ist ein automatischer rekursiver Parser mit stackabhängiger
Speicherkorruption im isolierten Modell. Nicht bestätigt sind die reale
Stack-/Heap-Anordnung, ein durch die beschädigten Metadaten ausgelöster
Allocator-Aufruf, die erfolgreiche Öffnung des Pfads auf dem Gerät und jede
Kontrollflussübernahme. Derzeit ist das ein ernstzunehmender
Absturz-/Heapkorruptionskandidat, aber kein nachgewiesener RCE- oder
Rockbox-Bootpfad.

Sinnvolle Folgeprüfungen:

1. Externen Taskdienst und Task-Ende untersuchen, um zu klären, ob ein
   MainApp-Stack in einem erreichbaren Zustand freigegeben wird.
2. Den tatsächlichen Heap-/Taskobjekt-Nachbarn aus einem zulässigen
   Laufzeitabbild oder einer kontrollierten Gerätebeobachtung bestimmen.
3. Den Parser auf einer gesicherten Datenpartition nur dann am Gerät testen,
   wenn ein normaler Neustart und die Wiederherstellung des Geräts verfügbar
   sind.
4. Weiter nach ähnlich automatisch geladenen Dateien mit direkter
   Rücksprung- oder Funktionszeigerkontrolle suchen; der getrennte Kandidat
   `accessories.reg` ist in
   [OSOS-accessories-reg-stack-overflow-followup-2026-10-26.md](OSOS-accessories-reg-stack-overflow-followup-2026-10-26.md)
   dokumentiert.

Rohbelege: `/tmp/OSOS_function_0826dca0_20261026.txt`,
`/tmp/OSOS_task_create_MainAppTask_helper_20261026.txt`,
`/tmp/OSOS_task_create_0801de7c_20261026.txt`,
`/tmp/OSOS_heap_alloc_core_20261026.txt`,
`/tmp/OSOS_notes_allocator_init_20261025.txt`,
`/tmp/OSOS_heap_free_candidates_20261026.txt`,
`/tmp/OSOS_MainAppTask_entry_20261026.txt`,
`/tmp/OSOS_MainAppTask_tail_20261026.txt`,
`/tmp/n5g_playcounts_recurse_heapheader.S` und
`/tmp/n5g_playcounts_recurse_heapheader.out`. Die Ghidra-Läufe verwendeten
`-readOnly -noanalysis`. Der QEMU-Test lief ausschließlich auf dem Host.

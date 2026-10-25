# OSOS-Lücke als untethered Rockbox-Einstieg: aktueller Stand

Stand: 25.10.2026. Diese Arbeit war statisch und offline. Es gab keinen
USB-/DFU-Zugriff, keinen Neustart und keinen NAND-/NOR-Schreibzugriff.

## Kurzantwort

Ja, eine Schwachstelle in der laufenden Apple-Software könnte theoretisch
untethered Rockbox ermöglichen, ohne LLB, OSOS oder deren Signaturen zu ändern:
Das signierte OSOS müsste bei jedem Kaltstart eine persistente Eingabe erneut
verarbeiten, dabei wiederholbar Codeausführung erreichen und anschließend
Rockbox aus dem FAT-Dateisystem in RAM laden und starten. Für Hold-gesperrten
Start müsste dieser Pfad den Hold-Schalter erkennen und den Rockbox-Handoff
auslassen. Für diese vollständige Kette gibt es bislang keinen Nachweis.

## Neue statische Befunde

### Status-Gate vor dem untersuchten Music-Event

Der zuvor nicht aufgelöste Aufruf `FUN_081a3f2e` ist im Runtime-Abbild ein
Lookup mit anschließender virtueller Abfrage:

- `FUN_081a9af4(0xa500)` sucht einen Eintrag in einer Baumstruktur über
  `FUN_0827d69e`/`FUN_0825e0c6`.
- Falls der Lookup einen Wert liefert, ruft `FUN_081af6fe` den virtuellen
  VTable-Slot `+0x14` dieses Objekts auf. Dessen Rückgabewert wird vom Aufrufer
  als Boolesch behandelt.
- Der Lookup-Root liegt bei `0x087644fc`, außerhalb des 7.095.208 Byte langen
  Runtime-Abbilds. Der dynamische Eintrag für `0xa500`, sein Methodenrumpf und
  dessen Kaltstartzustand sind daher nicht aus diesem Dump bestimmbar.
- Der neu als Thumb-Funktion abgegrenzte Callback `0x0821765c` postet nur dann
  die Nachricht `0xa900000b`, wenn dieser Gate-Aufruf ungleich null zurückgibt.
  Damit ist die Eventfolge zustandsabhängig; sie ist kein belegter automatischer
  Datei- oder Boot-Trigger.

Die Event-Queue wird während der MainApp-Konstruktion initialisiert:
`FUN_08023670` ruft `FUN_0802daf4` auf, das den Manager an `0x08553cec`
registriert. `FUN_08220a68` verwendet diesen Manager für den Dispatch. Die
initialisierte Queue belegt jedoch nicht, dass gerade `0xa900000b` beim
Kaltstart einen ArtworkDB-Ladevorgang auslöst; Empfänger und dynamische
Handlerbindung bleiben offen.

### Music-Kontextslot im vollständigen Body gegengeprüft

Der fehlende statische Schreiber des Music-Kontextslots wurde zusätzlich im
Full-Body-Projekt geprüft. Die Mappingdifferenz beträgt `0x2e27c`:
Runtime-Adresse `0x08550acc` entspricht Full-Body-Adresse `0x0857ed48`, und
`0x08550ae0` entspricht `0x0857ed5c`. Die Bytes sind in beiden Abbildern
konsistent; der Slot `0x08550ae0` ist null. Ghidras Referenzprüfung findet für
beide Slotadressen im Full-Body-Projekt keine Referenzen.

Das stärkt den Befund, dass der untersuchte OSOS-Body keinen direkten statischen
Schreiber dieses Slots enthält. Es beweist wegen möglicher indirekter
Zeigerarithmetik, dynamischer Initialisierung, Overlays und fehlendem Live-RAM
nicht, dass der Slot auf dem Gerät stets null bleibt.

## Rockbox-Handoff und Hold-Fallback im lokalen Quellcode

Der vorhandene Rockbox-Bootloader zeigt, dass die gewünschte Verzweigung auf
Rockbox-Seite bereits implementiert ist:

- `firmware/export/config/ipodnano5g.h` setzt `BOOTFILE` auf `rockbox.ipod`.
- `bootloader/ipod-s5l87xx.c` prüft nach der Speicherinitialisierung
  `button_hold()`. Bei gesetztem Hold ruft er `kernel_launch_onb()` auf.
- Ohne Hold mountet er das Dateisystem, lädt `rockbox.ipod` mit
  `load_firmware()` nach `DRAM_ORIG` und springt zum Image-Einstieg.

Das belegt den Rockbox-seitigen Lade- und Fallbackpfad, **nicht** dass das
unveränderte OSOS diesen Bootloader starten kann. Ein OSOS-Exploit müsste einen
geeigneten Bootloader-/Firmware-Handoff oder eine äquivalente Initialisierung
erreichen; ein bloßer Schreibzugriff auf eine signierte OSOS-/LLB-Datei würde
die vorgelagerte Signaturprüfung nicht überwinden.

## Einordnung der bekannten Eingaben

- **Notes:** Der zuvor dokumentierte UTF-8-Pfadtrim kann bei einem
  unvollständigen Dreibytezeichen einen Größenunterlauf an den String-Resize-
  Pfad weiterreichen. Das ist ein ernstzunehmender Out-of-bounds-Schreib-
  kandidat. Seine Verarbeitung hängt bislang an einem UI-/Linkpfad; ein
  automatisches Öffnen beim Kaltstart, kontrollierte Kontrollflussübernahme und
  RCE sind nicht belegt.
- **ArtworkDB:** Der `mhia_count << 2`-Fehler bleibt ein bedingter
  Heapkorruptionskandidat. Die geprüften Dateipfade begrenzen Reads; ein
  reproduzierbarer PC/LR-Wert oder RCE fehlt. Der automatische Kaltstartaufruf
  ist weiterhin unbewiesen.
- **Play Counts:** Der feste Header-/Record-Leser bietet in der dekompilierten
  Routine keinen dateigesteuerten Puffer- oder Zeigerzugriff.

Damit lautet die verifizierte Antwort: Eine OSOS-Lücke wäre grundsätzlich ein
plausibler Weg zu untethered Boot, aber aktuell ist weder ein automatisch
erreichbarer und kontrollierbarer Datei-Exploit noch ein OSOS-zu-Rockbox-Handoff
gezeigt.

## Rohbelege und nächster Schritt

Neue Ghidra-Auszüge:

- `/tmp/OSOS_runtime_gate_81a3f2e_20261026.txt`
- `/tmp/OSOS_runtime_gate_helper_81a9af4_20261026.txt`
- `/tmp/OSOS_runtime_gate_helper_81af6fe_20261026.txt`
- `/tmp/OSOS_runtime_registry_lookup_825e0c6_20261026.txt`
- `/tmp/OSOS_runtime_gate_refs_20261026.txt`
- `/tmp/OSOS_runtime_state_821765c_recheck_20261026.txt`
- `/tmp/OSOS_runtime_event_manager_init_20261026.txt`
- `/tmp/OSOS_runtime_event_dispatch_deep_20261026.txt`
- `/tmp/OSOS_fullbody_music_context_refs_corrected_20261026.txt`

Die beiden Ghidra-Projekte wurden mit `-noanalysis -readOnly` geöffnet. Als
nächster Offline-Schritt sollte die externe Registrierung des Music-Kontexts
und des Empfängers von `0xa900000b` gegen die Full-Body-Relokationen/Overlays
abgeglichen werden. Danach bleibt für einen tatsächlichen Untethered-Nachweis
ein kontrollierter Kaltstarttest nötig, sobald das Gerät wieder erreichbar ist;
der aktuelle Status erlaubt keine Aussage über die Live-Werte.

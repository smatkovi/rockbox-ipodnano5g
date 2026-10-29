# Persistente LFN-Auflösungsbelege (28.10.2026)

Dieses Verzeichnis hält die read-only Ghidra-Ausgaben zur Registerherkunft des
FAT-LFN-Resolvers sowie den historischen VFAT-Verzeichnisdump dauerhaft im
Repository fest.

## Gesicherte Kernaussage

`FUN_081f7f9c` speichert den beim Aufruf aktuellen Wert von `r2` in
`state[1]`. Beim ersten LFN-Eintrag kann `r2` noch eine lokale Stackadresse
sein; `FUN_08159128` verwendet sie als Eintragsindex und liest dann aus
`cache + 0x18 + index * 0x20`. Das ist ein möglicher Out-of-bounds-Read.

Wenn vor dem LFN-Eintrag ein normaler 8.3-Eintrag erfolglos verglichen wurde,
lädt `FUN_08158b64` den Resolvermodus (0 oder 1) vor dem Vergleich erneut nach
`r2`. Der Vergleichshelper lässt `r2` unverändert. Nachfolgende LFN-Einträge
speichern daher diesen kleinen Moduswert statt der Stackadresse. Stimmen Wert
und cache-lokaler LFN-Slot überein, kann der LFN-Datensatz korrekt gelesen und
anschließend per Prüfsumme validiert werden. Ein typischer möglicher Fall ist
Modus 1 und genau ein vorheriger regulärer Eintrag.

Die bekannten automatischen Kandidaten benutzen unterschiedliche Modi: Der
iTunes-Verzeichnisiterator ruft den Resolver mit Modus 1 auf; der normale
Datei-Open-Pfad, etwa für `PlayCounts` oder `iPodSettings.xml`, mit Modus 0.
Der Mode-1-Fall belegt daher keine erfolgreiche Auflösung beim Datei-Open.

Der historische Linux-`READDIR_BOTH`-Dump enthält Lang- und Kurznamen, aber
keine physischen FAT-Verzeichnisslots. Er kann deshalb weder die Slotnummer des
LFN-Datensatzes noch die Anzahl der davor vom Firmwareloop verarbeiteten
Einträge belegen. Die aufgeführten `.`/`..`-Namen können VFS-Einträge sein.
Der Dump stammt aus dem read-only Snapshot vom 26.10.2026, nicht aus einer
Geräteabfrage dieser Runde.

Eine weitere read-only-Prüfung bestätigt den Kopierpfad über zwei Cacheblöcke:
`FUN_08159128` kann aus dem aktuellen Block und bei gesetztem `state[4]` aus
dem vorherigen Block ab Offset `0x1f8` (Record 15) lesen. Das rohe Thumb-
Listing bestätigt, dass `state[4]` vor dem zweiten `FUN_0821959c`-Aufruf nach
`r1` geladen wird und der Cache-Helper den vorherigen Blockschlüssel erhält.
Der Null-Sentinel ist am ersten gültigen Blockwechsel kein Hindernis, weil
`FUN_08159018` einen Iterator mit Startschlüssel null verwirft.

Beim Blockwechsel wird `r2` tatsächlich neu berechnet, aber der Wert ist nicht
beliebig. `FUN_0822641e` bildet für einen FAT-Cluster `c >= 2` dessen
Sektoradresse als `data_start + ((c - 2) << cluster_shift)`. Für solche
Verzeichnis-Sektoren nimmt `FUN_081608f8` den Datenbereichspfad und ruft
`FUN_0816a970` auf. Dieser prüft, ob der Folgesektor noch im selben Cluster
liegt. Der Divisionshelper `FUN_0818e65c` hält Quotientenbits in `r2`; das
letzte Bit geht in `r0`. Bei einem Quotienten von 1 bleibt `r2` deshalb 0.
`FUN_0821959c` erhält diesen Wert, und der nächste LFN-Record speichert ihn
mit `FUN_081f7f9c` erneut in `state[1]`.

Damit ist die Zweirecord-Anordnung an den Indizes 15/0 unter einer konkreten
Bedingung statisch plausibel: Die `Device`-Directory müsste in FAT-Cluster 3
liegen, alle benötigten Records müssten in diesem Cluster bleiben, und die
Clustergröße müsste mindestens vier 512-Byte-Sektoren betragen. Beim Übergang
zwischen diesen Sektoren ist der Quotient `((cluster - 2) * sectors_per_cluster
+ offset) / sectors_per_cluster` gleich 1; `r2` bleibt 0. Bei Startcluster 4
ist der Quotient 2 und der Divisionsrestzustand in `r2` bereits 1, sodass die
Modus-0-Anordnung so nicht funktioniert. Für das aktuelle Volume fehlen
Bootsektor, FAT-Clusterzuordnung und physische Directory-Sektoren; der
Cluster-3-Fall ist daher nur ein konstruktiver Kandidat, kein Nachweis für
das vorhandene Gerät.

## Offline-QEMU-Rehost

Zwei kleine Rehosts verwenden den Originalcode aus dem OSOS-Abbild und
synthetische RAM-/FAT-Zustände. Der Sektorfortschaltungs-Test bestätigte die
Rückgabe-LBAs und `r2`-Werte für die relativen Positionen 7 und 9.
Der Resolver-Test ließ zunächst `FUN_081f7f9c` mit den Schlüsseln `0x22` und
`0x11` sowie `r2=0` den Zweirecord-Zustand erzeugen. `FUN_081f8164` berechnete
für den Kurznamen das Prüfbyte `0x08`. Danach rekonstruierten `FUN_08159128`
und `FUN_08160828` eine 26-Zeichen-LFN über die Cachegrenze:
`0x42` an vorherigem Index 15, `0x01` an aktuellem Index 0, danach
`ROCKBO~1BIN` mit
VFAT-Prüfbyte `0x08`. Beide Programme meldeten `PASS` und endeten mit Status 0.

Das bestätigt den Zustandshelfer, die Kurzname-Prüfsummenroutine und den
Original-Resolver für genau diese synthetischen Eingaben. Cache-Lookup,
Freigabe und UTF-Konvertierung waren Stubs; der Test führt weder den echten
Verzeichnisiterator noch den vollständigen VFAT-Vergleich, einen OSOS-Datei-
Open oder das reale Volume aus. Die alten
OOB-Rehost-Dateien dokumentieren separat den Zustand, in dem ein
Stackzeigerwert als Slotindex einen unzugänglichen Quellzeiger erzeugt.

Quellcode, Linkerskripte, QEMU-Instruktionsspuren und Laufprotokolle sind unter
`rehost/cluster-mode0-20261029/` abgelegt. Die ELF-Dateien sind lokale
Build-Ausgaben und werden nicht versioniert; die konkreten Build- und
Startbefehle stehen in dessen `README.md`.

## Dateien und Reproduktion

- `OSOS_lfn_compare_decomp_20261028.log`: Resolver-, LFN-Index- und
  Vergleichs-Pseudocode.
- `OSOS_lfn_name_compare_callers_20261028.log` und
  `OSOS_lfn_all_callers_and_iterator_20261028.log`: direkte Caller und
  Iteratorpfade.
- `OSOS_lfn_register_clobber_audit_20261028.log` sowie
  `OSOS_lfn_component_call_context_20261028.log`: ARM-Instruktionen,
  Argumentübergaben, Moduswerte und Registerfolge.
- `OSOS_lfn_iterator_block_identifier_20261029.log` und
  `OSOS_lfn_directory_start_index_20261029.log`: Blockschlüssel, nichtnulliger
  Startblock und vorheriger Block beim LFN-Grenzfall.
- `OSOS_lfn_resolver_raw_listing_20261029.log`: Thumb-Instruktionen des
  Resolvers; belegt, dass der vorherige Blockschlüssel im zweiten Cache-Aufruf
  tatsächlich über `r1` übergeben wird.
- `OSOS_lfn_iterator_helpers_raw_20261029.log`: Thumb-Instruktionen für
  Iteratorfortschaltung, Cachezugriff und LFN-Zustand.
- `OSOS_lfn_blockkey_origin_decomp_20261029.log`: Abbildung von FAT-Cluster
  auf Datenbereich-Sektoradressen.
- `OSOS_lfn_block_advance_raw_20261029.log` und
  `OSOS_lfn_sector_advance_divmod_window_20261029.log`: Maschinen-Code der
  Sektorfortschaltung und des Divisionshelpers; belegen den bedingten
  Quotient-1-Fall mit `r2=0`.
- `OSOS_lfn_blockkey_origin_decomp_20261029.log`: Pseudocode zur Cluster-
  und Sektorabbildung.
- `OSOS_live_vfat_dir_ioctl_20261026.txt` und
  `ipod_vfat_dir_ioctl.py`: historischer Snapshot und der verwendete
  `FAT_IOCTL_READDIR_BOTH`-Leser. Das Skript ist hier nur dokumentiert; es wurde
  in dieser Runde nicht gegen ein Gerät ausgeführt.
- Die Ausgaben stammen aus dem vorhandenen Projekt
  `/home/sebastian/ipod-re/local-analysis/ghidra-projects/N5G_OSOS_runtime_analysis/`
  mit Eingabeabbild
  `/home/sebastian/ipod-re/local-analysis/inputs/osos_runtime_dram_20261025.bin`.
  Die Headless-Abfragen verwendeten `-noanalysis -readOnly`.

`SHA256SUMS` schützt die Ghidra-Belege, den Rehost-Manifest und die verlinkten
Analyseberichte. Die einzelne Rehost-Dateien sind zusätzlich dort aufgelistet.
Prüfen vom Repository-Verzeichnis aus:

```sh
sha256sum -c utils/ipodnano5g/analysis/evidence/lfn-resolution-2026-10-28/SHA256SUMS
```

Die einzelnen QEMU-ELFs, Quellen, Traces und Laufprotokolle lassen sich danach
aus dem Rehost-Unterverzeichnis prüfen:

```sh
cd utils/ipodnano5g/analysis/evidence/lfn-resolution-2026-10-28/rehost
sha256sum -c SHA256SUMS
```

Es gab in dieser Runde keine USB-/DFU-Abfrage, keinen Firmwareboot und keinen
NAND-/NOR-/Dateisystem-Schreibzugriff.

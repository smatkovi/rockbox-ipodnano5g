# Queue-1-Setup-Importprüfung

Read-only-Ghidra-Auszüge und eine reproduzierbare Suche nach dem Prefix-
Queue-Setupimport `0x22005248`. Keine Gerätedaten werden verändert.

## Inhalt

- `OSOS_body_queue1_init_veneer_20261031.application.log` — transient
  dekodierter ARM-Veneer bei `0x0823b7a8`; die Funktionsanlage wird nach der
  Abfrage verworfen.
- `OSOS_body_queue1_init_veneer_xrefs_20261031.application.log` — keine
  Ghidra-Xrefs in den Veneerbereich `0x0823b7a8..0x0823b7ac`.
- `OSOS_body_queue1_init_api_xrefs_20261031.application.log` — keine
  Ghidra-Xrefs auf das Prefix-API `0x22005248..0x2200524b` im Body-Projekt.
- `prefix_svc_dispatch_callers_20261031.application.log` — 32 direkte
  Aufrufstellen des Prefix-SVC-Dispatchers `0x22007008`; nur der
  Setupwrapper verwendet statisch den Servicecode `0x2e`.
- `prefix_svc_unassigned_callsite_windows_20261031.application.log` und
  `prefix_svc_last_unassigned_callsite_window_20261031.application.log` —
  Instruktionsfenster der neun nicht einer Funktion zugeordneten Aufrufstellen.
- `scan_queue1_setup_constants.py` und `queue1_setup_constant_scan_20261031.txt`
  — Little-Endian-32-Bit-Suche nach dem API-Wert und den beiden OSOS-Veneer-
  adressen. Durchsucht werden Dateien mit Endung `.pe32`, `.bin`, `.ibss`,
  `.ipod` und `.img` bis 16 MiB unter `/home/sebastian/ipod-re/nano5g`, plus
  die lokale Runtime- und Prefix-Eingabe. Ergebnis: 160 Dateien, zwei
  API-Literale (Body und Runtime), keine Veneerzeiger und kein direkter
  Import des generischen Prefix-SVC-Dispatchers.
- `SHA256SUMS` — Prüfsummen der Belege in diesem Verzeichnis.

Der Byte-Scan findet wörtliche 32-Bit-Werte. Er schließt berechnete Sprünge,
Laufzeitänderungen oder nicht durchsuchte Code-/Datenquellen nicht aus.

Reproduktion des Rohbildscans vom Repository-Root:

```sh
python3 utils/ipodnano5g/analysis/evidence/ata-queue1-init-lookup-2026-10-31/scan_queue1_setup_constants.py
```

Die Ghidra-Abfragen verwendeten die vorhandenen Projekte
`N5G_OSOS_body_full_20261031` mit `-readOnly -noanalysis`. Die verwendeten
Skripte sind bereits versioniert unter `evidence/lfn-resolution-2026-10-28/scripts/`
und `evidence/accessories-alias-startup-reach-2026-10-31/scripts/`.

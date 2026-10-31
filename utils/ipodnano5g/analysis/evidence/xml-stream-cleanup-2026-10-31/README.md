# iPodSettings Stream-Cleanup Audit

Stand: 31.10.2026. Ghidra lief mit `-noanalysis -readOnly` auf dem vorhandenen
Projekt `N5G_OSOS_runtime`. Die abgefragten Funktionen umfassen den
Streamkonstruktor, die Cleanup-Kette, Referenzzähler und das Registry-Remove.
Die beiden VTable-Dumps stammen von `DAT_081ada9c` und `DAT_082784c4`.

Hauptergebnis: Der bestehende QEMU-Harness testet den Hilfsvektor-Destruktor,
nicht den vollständigen Stream-Cleanup. Der vollständige Pfad hängt an einer
durch Originalkonstruktor und VFS-/Providerzustand angelegten Registryinstanz;
ein frei erfundener Objektbaum wäre kein aussagekräftiger Test.

Rohprotokolle:

- `ghidra-cleanup-context.application.log`: Cleanup, Stream-/Wrapper-VTables,
  Registry-Abbau, Konstruktor und Openstatus.
- `ghidra-wrapper-registration.application.log`: Wrapperregistrierung,
  Registryobjekt und Baumoperation.
- `ghidra-stream-object-vtable.application.log`: 16 Wörter ab `0x08535648`.
- `ghidra-wrapper-vtable.application.log`: 16 Wörter ab `0x0850174c`.

Die Logs enthalten den vollständigen Ghidra-Start und die Decompiler-Ausgabe.
Sie wurden als Dateien im Analyseverzeichnis abgelegt, nicht unter `/tmp`.

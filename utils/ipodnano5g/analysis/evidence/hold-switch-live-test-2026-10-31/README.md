# Live Hold switch check

`holdstat.rock` displays the value returned by Rockbox's `button_hold()` API.
It does not read the raw PMU register and does not change firmware or storage.
It was built with `build-n5g`, whose `rockbox.ipod` hash matches the installed
device image.

The plugin is copied to the writable 8-MiB USB RAM disk at
`/.rockbox/rocks/apps/holdstat.rock`. After disconnecting USB, open Rockbox's
Plugins → Applications → Hold switch status. Toggle the physical switch and
record whether the display changes between `LOCKED` and `UNLOCKED`. Unlock the
switch to exit with Select.

The internal iPod and FTL LUNs were reported read-only during this session;
only the temporary RAM disk is used for this diagnostic.

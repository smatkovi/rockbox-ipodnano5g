# iPod nano 5G untethered Rockbox

Experimental; tested on one iPod nano 5G. Linux only. Build Rockbox as
[described here](../README.md#build), then create and install its 8 MiB RAM
disk (replace `/mnt/ipod` with the mounted iPod data volume):

```sh
utils/ipodnano5g/n5g-mkdisk.sh build-n5g/rockbox.zip build-n5g/disk.img
unzip -o build-n5g/rockbox.zip -d /mnt/ipod
cp build-n5g/disk.img /mnt/ipod/.rockbox/n5g-ramdisk.img
```

The iPod must contain `.rockbox/rockbox.ipod` and the RAM disk before running
the installer. Back up an existing RAM disk before replacing it.

Mount the iPod data volume read-write, then run:

```sh
sudo utils/ipodnano5g/untethered/install.sh /mnt/ipod
```

Safely eject, unplug USB, and restart. The installer backs up the two files it
replaces in `.rockbox-n5g-backup/`. To undo:

```sh
sudo utils/ipodnano5g/untethered/install.sh --restore /mnt/ipod
```

The test wrote ordinary FAT files only; it did not write NAND or NOR. The
locked-Hold Apple OS fallback is included but has not been tested on hardware.

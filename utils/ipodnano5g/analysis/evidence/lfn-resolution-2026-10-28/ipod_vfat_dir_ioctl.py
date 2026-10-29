import ctypes, fcntl, os
class Dirent(ctypes.Structure):
    _fields_ = [('ino', ctypes.c_long), ('off', ctypes.c_long), ('reclen', ctypes.c_ushort), ('name', ctypes.c_char * 256)]
request = (2 << 30) | (ctypes.sizeof(Dirent) * 2 << 16) | (ord('r') << 8) | 1
for path in ['/tmp/ipod-sebipod-readonly', '/tmp/ipod-sebipod-readonly/iPod_Control', '/tmp/ipod-sebipod-readonly/iPod_Control/Device', '/tmp/ipod-sebipod-readonly/.rockbox']:
    print('DIR', path)
    fd = os.open(path, os.O_RDONLY | os.O_DIRECTORY)
    try:
        while True:
            buf = bytearray(ctypes.sizeof(Dirent) * 2)
            fcntl.ioctl(fd, request, buf, True)
            ents = [Dirent.from_buffer(buf, i * ctypes.sizeof(Dirent)) for i in range(2)]
            long = bytes(ents[0].name).split(b'\0', 1)[0].decode(errors='replace')
            short = bytes(ents[1].name).split(b'\0', 1)[0].decode(errors='replace')
            if not long and not short:
                break
            print(f'  {long!r}  short={short!r}')
    finally:
        os.close(fd)

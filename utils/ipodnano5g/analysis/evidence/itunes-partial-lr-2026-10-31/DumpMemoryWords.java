import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.Address;
import ghidra.program.model.listing.Function;

public class DumpMemoryWords extends GhidraScript {
  @Override
  public void run() throws Exception {
    String[] args = getScriptArgs();
    if (args.length == 0 || (args.length % 2) != 0)
      throw new IllegalArgumentException("usage: <address> <word-count> [<address> <word-count> ...]");
    for (int p = 0; p < args.length; p += 2) {
      Address base = toAddr(Long.parseUnsignedLong(args[p].replace("0x", ""), 16));
      int count = Integer.parseInt(args[p + 1]);
      for (int i = 0; i < count; i++) {
        Address at = base.add(i * 4L);
        int value = currentProgram.getMemory().getInt(at);
        Address target = toAddr(Integer.toUnsignedLong(value & ~1));
        Function f = getFunctionAt(target);
        println(String.format("WORD %s value=%08x target=%s function=%s",
          at, value, target, f == null ? "<none>" : f.getName()));
      }
    }
  }
}

import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.Address;
import ghidra.program.model.address.AddressSet;
import ghidra.program.model.listing.Instruction;
import ghidra.program.model.listing.InstructionIterator;
import java.util.ArrayList;
import java.util.List;

public class ScanAsciiThumbGadgets extends GhidraScript {
  private boolean printableSafe(int b) {
    if (b < 0x21 || b > 0x7e) return false;
    return b != '/' && b != '\\' && b != ':' && b != '*' && b != '?' &&
           b != '"' && b != '<' && b != '>' && b != '|';
  }

  @Override public void run() throws Exception {
    Address start = toAddr(0x08000000L);
    Address end = toAddr(0x08010000L);
    AddressSet range = new AddressSet(start, end);
    println("SCAN_RANGE " + start + ".." + end);
    println("TARGET_ENCODING: instruction address | 1; printable VFAT-safe low pointer bytes");
    InstructionIterator iter = currentProgram.getListing().getInstructions(range, true);
    int matches = 0;
    while (iter.hasNext() && !monitor.isCancelled()) {
      Instruction first = iter.next();
      Address at = first.getAddress();
      long pointer = at.getOffset() | 1L;
      int low = (int)(pointer & 0xff);
      int high = (int)((pointer >>> 8) & 0xff);
      if (!printableSafe(low) || !printableSafe(high)) continue;
      List<String> sequence = new ArrayList<>();
      Instruction current = first;
      boolean branch = false;
      boolean store = false;
      for (int i = 0; i < 6 && current != null; i++) {
        String mnemonic = current.getMnemonicString().toLowerCase();
        String rendered = current.getAddress() + ":" + current.toString();
        sequence.add(rendered);
        if (mnemonic.startsWith("str") || mnemonic.equals("stmia")) store = true;
        boolean control = mnemonic.equals("bx") || mnemonic.equals("blx") ||
            mnemonic.startsWith("b") || mnemonic.equals("pop") ||
            current.toString().contains("pc");
        if (control) branch = true;
        if (control) break;
        current = currentProgram.getListing().getInstructionAfter(current.getAddress());
      }
      String firstMnemonic = first.getMnemonicString().toLowerCase();
      boolean directControl = firstMnemonic.equals("bx") || firstMnemonic.equals("blx") ||
          firstMnemonic.equals("pop") || first.toString().contains("pc");
      if (!directControl && !(store && branch) && !firstMnemonic.equals("add") &&
          !firstMnemonic.equals("adds") && !firstMnemonic.equals("sub") &&
          !firstMnemonic.equals("subs")) continue;
      println(String.format("GADGET ptr=0x%08x at=%s chars='%c%c' %s",
          pointer, at, (char)low, (char)high, String.join(" | ", sequence)));
      matches++;
    }
    println("GADGET_COUNT " + matches);
  }
}

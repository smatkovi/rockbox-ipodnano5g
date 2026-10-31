import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.Address;
import ghidra.program.model.listing.Function;
import ghidra.program.model.listing.FunctionIterator;
import ghidra.program.model.listing.Instruction;
import ghidra.program.model.listing.InstructionIterator;
import java.util.ArrayList;
import java.util.List;

public class ScanAsciiThumbTargets extends GhidraScript {
  private boolean printableSafe(int b) {
    if (b < 0x21 || b > 0x7e) return false;
    return b != '/' && b != '\\' && b != ':' && b != '*' && b != '?' &&
           b != '"' && b != '<' && b != '>' && b != '|';
  }

  @Override public void run() throws Exception {
    Address start = toAddr(0x08000000L);
    Address end = toAddr(0x08010000L);
    println("SCAN_RANGE " + start + ".." + end);
    println("TARGET_ENCODING: Thumb pointer = normalized function entry | 1; " +
            "filter bytes must be printable VFAT-safe filename characters");
    FunctionIterator functions = currentProgram.getFunctionManager().getFunctions(true);
    int count = 0;
    while (functions.hasNext() && !monitor.isCancelled()) {
      Function function = functions.next();
      Address entry = function.getEntryPoint();
      if (entry.compareTo(start) < 0 || entry.compareTo(end) >= 0) continue;
      long pointer = entry.getOffset() | 1L;
      int low = (int)(pointer & 0xff);
      int high = (int)((pointer >>> 8) & 0xff);
      if (!printableSafe(low) || !printableSafe(high)) continue;
      List<String> instructions = new ArrayList<>();
      InstructionIterator iter = currentProgram.getListing().getInstructions(function.getBody(), true);
      while (iter.hasNext() && instructions.size() < 5) {
        Instruction instruction = iter.next();
        instructions.add(instruction.getAddress() + ":" + instruction.toString());
      }
      println(String.format("TARGET ptr=0x%08x entry=%s name=%s chars='%c%c' body=%s first=%s",
            pointer, entry, function.getName(), (char)low, (char)high,
            function.getBody(), String.join(" | ", instructions)));
      count++;
    }
    println("MATCH_COUNT " + count);
  }
}

import ghidra.app.decompiler.DecompInterface;
import ghidra.app.decompiler.DecompileResults;
import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.Address;
import ghidra.program.model.listing.Function;
import ghidra.program.model.listing.Instruction;
import ghidra.program.model.listing.InstructionIterator;
import ghidra.program.model.symbol.Reference;
import ghidra.program.model.symbol.ReferenceIterator;
import java.util.HashSet;
import java.util.Set;

public class DumpCallersAndData extends GhidraScript {
  @Override
  public void run() throws Exception {
    DecompInterface decomp = new DecompInterface();
    decomp.openProgram(currentProgram);
    Set<String> seenFunctions = new HashSet<>();
    for (String arg : getScriptArgs()) {
      Address target = toAddr(Long.parseUnsignedLong(arg.replace("0x", ""), 16));
      println("===== REFERENCES TO " + target + " =====");
      ReferenceIterator refs = currentProgram.getReferenceManager().getReferencesTo(target);
      while (refs.hasNext()) {
        Reference ref = refs.next();
        Function caller = currentProgram.getFunctionManager().getFunctionContaining(ref.getFromAddress());
        println("REF " + ref.getFromAddress() + " type=" + ref.getReferenceType() +
                " caller=" + (caller == null ? "<none>" : caller.getEntryPoint() + " " + caller.getName()));
        if (caller == null || !seenFunctions.add(caller.getEntryPoint().toString())) continue;
        Address start = caller.getBody().getMinAddress();
        Address end = caller.getBody().getMaxAddress();
        Address from = ref.getFromAddress().subtract(12);
        Address to = ref.getFromAddress().add(16);
        if (from.compareTo(start) < 0) from = start;
        if (to.compareTo(end) > 0) to = end;
        InstructionIterator it = currentProgram.getListing().getInstructions(from, true);
        while (it.hasNext()) {
          Instruction ins = it.next();
          if (ins.getAddress().compareTo(to) > 0) break;
          println("  " + ins.getAddress() + ": " + ins);
        }
        DecompileResults result = decomp.decompileFunction(caller, 30, monitor);
        if (result.decompileCompleted() && result.getDecompiledFunction() != null)
          println(result.getDecompiledFunction().getC());
        else println("DECOMPILE_FAILED " + result.getErrorMessage());
      }
    }
    decomp.dispose();
  }
}

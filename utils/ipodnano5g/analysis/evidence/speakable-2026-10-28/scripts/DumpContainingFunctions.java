import ghidra.app.script.GhidraScript;
import ghidra.app.decompiler.DecompInterface;
import ghidra.app.decompiler.DecompileResults;
import ghidra.program.model.address.Address;
import ghidra.program.model.listing.Function;
import ghidra.program.model.listing.Instruction;
import ghidra.program.model.listing.Listing;

public class DumpContainingFunctions extends GhidraScript {
  @Override public void run() throws Exception {
    DecompInterface decomp = new DecompInterface();
    decomp.openProgram(currentProgram);
    Listing listing = currentProgram.getListing();
    for (String arg : getScriptArgs()) {
      Address a = toAddr(Long.decode(arg));
      Function f = currentProgram.getFunctionManager().getFunctionAt(a);
      if (f == null) f = currentProgram.getFunctionManager().getFunctionContaining(a);
      println("===== ADDRESS " + a + " FUNCTION " + (f == null ? "<none>" : f.getName()+"@"+f.getEntryPoint()) + " =====");
      if (f == null) continue;
      DecompileResults r = decomp.decompileFunction(f, 30, monitor);
      if (r.decompileCompleted() && r.getDecompiledFunction() != null) println(r.getDecompiledFunction().getC());
      for (Instruction ins : listing.getInstructions(f.getBody(), true)) println(ins.getAddress()+" "+ins);
    }
    decomp.dispose();
  }
}

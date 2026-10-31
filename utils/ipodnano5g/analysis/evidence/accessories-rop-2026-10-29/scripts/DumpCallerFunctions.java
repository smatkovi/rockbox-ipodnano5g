import ghidra.app.decompiler.DecompInterface;
import ghidra.app.decompiler.DecompileResults;
import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.Address;
import ghidra.program.model.listing.Function;
import ghidra.program.model.listing.Instruction;
import ghidra.program.model.symbol.Reference;
import java.util.HashSet;
import java.util.Set;

public class DumpCallerFunctions extends GhidraScript {
  @Override public void run() throws Exception {
    DecompInterface decomp = new DecompInterface();
    decomp.openProgram(currentProgram);
    for (String s : getScriptArgs()) {
      Address target = toAddr(Long.decode(s));
      println("===== CALLERS OF " + target + " =====");
      Set<Address> seen = new HashSet<>();
      for (Reference r : getReferencesTo(target)) {
        Function f = getFunctionContaining(r.getFromAddress());
        Instruction i = getInstructionAt(r.getFromAddress());
        println("REF " + r.getReferenceType() + " at=" + r.getFromAddress() +
          " function=" + (f == null ? "<none>" : f.getName()+"@"+f.getEntryPoint()) +
          " instruction=" + (i == null ? "<none>" : i.toString()));
        if (f == null || !seen.add(f.getEntryPoint())) continue;
        println("----- FUNCTION " + f.getName() + " " + f.getEntryPoint() + " " + f.getBody() + " -----");
        DecompileResults result = decomp.decompileFunction(f, 60, monitor);
        if (result != null && result.getDecompiledFunction() != null)
          println(result.getDecompiledFunction().getC());
        else println("DECOMPILE_FAILED " + (result == null ? "null" : result.getErrorMessage()));
      }
    }
    decomp.dispose();
  }
}

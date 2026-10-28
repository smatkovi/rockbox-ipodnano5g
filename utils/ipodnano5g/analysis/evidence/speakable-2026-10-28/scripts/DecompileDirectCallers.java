import ghidra.app.script.GhidraScript;
import ghidra.app.decompiler.DecompInterface;
import ghidra.app.decompiler.DecompileResults;
import ghidra.program.model.address.Address;
import ghidra.program.model.listing.Function;
import ghidra.program.model.symbol.Reference;
import java.util.TreeMap;

public class DecompileDirectCallers extends GhidraScript {
  @Override public void run() throws Exception {
    DecompInterface decomp = new DecompInterface();
    decomp.openProgram(currentProgram);
    for (String s : getScriptArgs()) {
      Address target = toAddr(Long.decode(s));
      TreeMap<String, Function> callers = new TreeMap<>();
      for (Reference ref : getReferencesTo(target)) {
        Function caller = getFunctionContaining(ref.getFromAddress());
        if (caller != null) callers.put(caller.getEntryPoint().toString(), caller);
      }
      println("===== DIRECT CALLERS " + target + " COUNT=" + callers.size() + " =====");
      for (Function caller : callers.values()) {
        println("===== CALLER " + caller.getEntryPoint() + " " + caller.getName() + " =====");
        DecompileResults result = decomp.decompileFunction(caller, 30, monitor);
        if (result.decompileCompleted() && result.getDecompiledFunction() != null) {
          println(result.getDecompiledFunction().getC());
        } else {
          println("DECOMPILE_FAILED " + result.getErrorMessage());
        }
      }
    }
    decomp.dispose();
  }
}

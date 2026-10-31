import ghidra.app.script.GhidraScript;
import ghidra.app.decompiler.DecompInterface;
import ghidra.app.decompiler.DecompileResults;
import ghidra.program.model.address.Address;
import ghidra.program.model.listing.Function;
import ghidra.program.model.listing.Instruction;
import ghidra.program.model.symbol.Reference;
import ghidra.program.model.symbol.ReferenceIterator;
import java.util.LinkedHashMap;
import java.util.Map;

public class DumpFunctionXrefs extends GhidraScript {
  @Override
  public void run() throws Exception {
    for (String arg : getScriptArgs()) {
      Address targetAddress = toAddr(Long.parseUnsignedLong(arg.replace("0x", ""), 16));
      Function target = getFunctionAt(targetAddress);
      println("===== TARGET " + targetAddress + " " + (target == null ? "<none>" : target.getName()) + " =====");
      if (target == null) continue;

      Map<Address, Function> callers = new LinkedHashMap<>();
      ReferenceIterator refs = currentProgram.getReferenceManager().getReferencesTo(target.getEntryPoint());
      while (refs.hasNext()) {
        Reference ref = refs.next();
        Function caller = getFunctionContaining(ref.getFromAddress());
        Instruction ins = getInstructionAt(ref.getFromAddress());
        println("XREF " + ref.getFromAddress() + " caller=" +
                (caller == null ? "<none>" : caller.getEntryPoint() + " " + caller.getName()) +
                " ins=" + (ins == null ? "<none>" : ins.toString()));
        if (caller != null) callers.put(caller.getEntryPoint(), caller);
      }

      DecompInterface decomp = new DecompInterface();
      decomp.openProgram(currentProgram);
      for (Function caller : callers.values()) {
        println("===== CALLER " + caller.getEntryPoint() + " " + caller.getName() + " =====");
        DecompileResults result = decomp.decompileFunction(caller, 45, monitor);
        if (result.decompileCompleted() && result.getDecompiledFunction() != null) {
          println(result.getDecompiledFunction().getC());
        } else {
          println("DECOMPILE_FAILED " + result.getErrorMessage());
        }
      }
      decomp.dispose();
    }
  }
}

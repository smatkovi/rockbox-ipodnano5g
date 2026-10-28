import ghidra.app.script.GhidraScript;
import ghidra.app.decompiler.DecompInterface;
import ghidra.app.decompiler.DecompileResults;
import ghidra.program.model.address.Address;
import ghidra.program.model.listing.Function;

public class DecompileFunctions extends GhidraScript {
  @Override
  public void run() throws Exception {
    DecompInterface decomp = new DecompInterface();
    decomp.openProgram(currentProgram);
    for (String arg : getScriptArgs()) {
      Address entry = toAddr(Long.parseUnsignedLong(arg.replace("0x", ""), 16));
      Function f = getFunctionAt(entry);
      println("===== "+entry+" "+(f==null?"<none>":f.getName())+" =====");
      if (f == null) continue;
      DecompileResults result = decomp.decompileFunction(f, 30, monitor);
      if (result.decompileCompleted() && result.getDecompiledFunction()!=null) println(result.getDecompiledFunction().getC());
    }
    decomp.dispose();
  }
}

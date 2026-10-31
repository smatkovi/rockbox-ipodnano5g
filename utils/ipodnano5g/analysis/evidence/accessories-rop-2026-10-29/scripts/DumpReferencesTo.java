import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.Address;
import ghidra.program.model.listing.Function;
import ghidra.program.model.listing.Instruction;
import ghidra.program.model.symbol.Reference;

public class DumpReferencesTo extends GhidraScript {
  @Override public void run() throws Exception {
    for (String s : getScriptArgs()) {
      Address target = toAddr(Long.decode(s));
      println("===== TARGET " + target + " =====");
      int n = 0;
      for (Reference r : getReferencesTo(target)) {
        Function f = getFunctionContaining(r.getFromAddress());
        Instruction i = getInstructionAt(r.getFromAddress());
        println(r.getReferenceType() + " " + r.getFromAddress() +
          " -> " + r.getToAddress() + " function=" +
          (f == null ? "<none>" : f.getName()+"@"+f.getEntryPoint()) +
          " instruction=" + (i == null ? "<none>" : i.toString()));
        n++;
      }
      println("COUNT=" + n);
    }
  }
}

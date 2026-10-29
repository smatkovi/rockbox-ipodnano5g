import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.Address;
import ghidra.program.model.listing.Function;
import ghidra.program.model.listing.Instruction;
import ghidra.program.model.listing.Listing;
import ghidra.program.model.symbol.Reference;
import ghidra.program.model.symbol.ReferenceIterator;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

public class DumpCallsiteWindows extends GhidraScript {
  @Override public void run() throws Exception {
    Address target = toAddr(Long.decode(getScriptArgs()[0]));
    Listing listing = currentProgram.getListing();
    ReferenceIterator refs = currentProgram.getReferenceManager().getReferencesTo(target);
    while (refs.hasNext()) {
      Reference ref = refs.next();
      Function f = getFunctionContaining(ref.getFromAddress());
      println("===== CALLSITE " + ref.getFromAddress() + " FUNCTION " +
        (f == null ? "<none>" : f.getName()+"@"+f.getEntryPoint()) + " =====");
      Instruction call = listing.getInstructionAt(ref.getFromAddress());
      if (call == null) continue;
      List<Instruction> previous = new ArrayList<>();
      Instruction cur = call;
      for (int i = 0; i < 12 && cur != null; i++) {
        previous.add(cur);
        cur = listing.getInstructionBefore(cur.getAddress());
      }
      Collections.reverse(previous);
      for (Instruction ins : previous) println(ins.getAddress()+"  "+ins);
      cur = listing.getInstructionAfter(call.getAddress());
      for (int i = 0; i < 2 && cur != null; i++) {
        println(cur.getAddress()+"  "+cur);
        cur = listing.getInstructionAfter(cur.getAddress());
      }
    }
  }
}

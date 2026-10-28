import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.Address;
import ghidra.program.model.address.AddressSet;
import ghidra.program.model.listing.Function;
import ghidra.program.model.listing.Instruction;
import ghidra.program.model.symbol.Reference;
import ghidra.program.model.symbol.ReferenceIterator;
import java.util.HashSet;
import java.util.Set;

public class FindIncomingReferencesInRange extends GhidraScript {
  @Override public void run() throws Exception {
    Address start = toAddr(Long.decode(getScriptArgs()[0]));
    Address end = toAddr(Long.decode(getScriptArgs()[1]));
    AddressSet range = new AddressSet(start, end);
    Set<String> emitted = new HashSet<>();
    for (long off = start.getOffset(); off <= end.getOffset(); off++) {
      Address target = toAddr(off);
      ReferenceIterator refs = currentProgram.getReferenceManager().getReferencesTo(target);
      while (refs.hasNext()) {
        Reference ref = refs.next();
        if (range.contains(ref.getFromAddress())) continue;
        String key = target + "|" + ref.getFromAddress() + "|" + ref.getReferenceType();
        if (!emitted.add(key)) continue;
        Function f = getFunctionContaining(ref.getFromAddress());
        Instruction ins = getInstructionAt(ref.getFromAddress());
        println("TARGET " + target + " FROM " + ref.getFromAddress() +
          " TYPE " + ref.getReferenceType() + " FUNCTION " +
          (f == null ? "<none>" : f.getName()+"@"+f.getEntryPoint()) +
          " INSTRUCTION " + (ins == null ? "<none>" : ins.toString()));
      }
    }
    println("RANGE " + start + "-" + end + " INCOMING=" + emitted.size());
  }
}

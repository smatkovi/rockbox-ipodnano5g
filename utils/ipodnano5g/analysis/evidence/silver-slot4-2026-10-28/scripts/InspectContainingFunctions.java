import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.Address;
import ghidra.program.model.address.AddressSet;
import ghidra.program.model.listing.Function;
import ghidra.program.model.listing.Instruction;
import ghidra.program.model.symbol.Reference;
import ghidra.program.model.symbol.ReferenceIterator;

public class InspectContainingFunctions extends GhidraScript {
  @Override
  public void run() throws Exception {
    for (String arg : getScriptArgs()) {
      Address target = toAddr(Long.decode(arg));
      Function exact = getFunctionAt(target);
      Function containing = getFunctionContaining(target);
      println("===== " + target + " exact=" +
        (exact == null ? "<none>" : exact.getName()) + " containing=" +
        (containing == null ? "<none>" : containing.getName()+"@"+containing.getEntryPoint()) + " =====");
      if (containing != null) {
        println("body=" + containing.getBody() + " signature=" + containing.getSignature());
        Address start = target.subtract(0x20);
        Address end = target.add(0x40);
        if (start.compareTo(containing.getEntryPoint()) < 0) start = containing.getEntryPoint();
        if (end.compareTo(containing.getBody().getMaxAddress()) > 0) end = containing.getBody().getMaxAddress();
        for (Instruction ins : currentProgram.getListing().getInstructions(new AddressSet(start, end), true)) {
          println(ins.getAddress() + ": " + ins);
        }
      }
      ReferenceIterator refs = currentProgram.getReferenceManager().getReferencesTo(target);
      while (refs.hasNext()) {
        Reference ref = refs.next();
        Instruction ins = currentProgram.getListing().getInstructionAt(ref.getFromAddress());
        Function caller = getFunctionContaining(ref.getFromAddress());
        println("XREF " + ref.getFromAddress() + " caller=" +
          (caller == null ? "<none>" : caller.getName()+"@"+caller.getEntryPoint()) +
          " instruction=" + (ins == null ? "<none>" : ins.toString()));
      }
    }
  }
}

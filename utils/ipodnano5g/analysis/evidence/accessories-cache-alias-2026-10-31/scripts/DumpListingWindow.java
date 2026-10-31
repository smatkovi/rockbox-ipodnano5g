import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.Address;
import ghidra.program.model.address.AddressSet;
import ghidra.program.model.listing.Function;
import ghidra.program.model.listing.Instruction;
import ghidra.program.model.listing.InstructionIterator;
import ghidra.program.model.symbol.Reference;
import ghidra.program.model.symbol.ReferenceIterator;

public class DumpListingWindow extends GhidraScript {
  @Override public void run() throws Exception {
    if (getScriptArgs().length != 2) {
      println("Usage: DumpListingWindow.java <start> <end>");
      return;
    }
    Address start = toAddr(Long.decode(getScriptArgs()[0]));
    Address end = toAddr(Long.decode(getScriptArgs()[1]));
    println("WINDOW " + start + ".." + end);
    AddressSet set = new AddressSet(start, end);
    InstructionIterator instructions = currentProgram.getListing().getInstructions(set, true);
    while (instructions.hasNext() && !monitor.isCancelled()) {
      Instruction instruction = instructions.next();
      Function function = getFunctionContaining(instruction.getAddress());
      println(instruction.getAddress() + "  " + instruction + "  function=" +
              (function == null ? "<none>" : function.getName()+"@"+function.getEntryPoint()));
      for (Reference ref : instruction.getReferencesFrom()) {
        println("    REF " + ref.getReferenceType() + " -> " + ref.getToAddress());
      }
    }
    for (Address target : new Address[] {start, end}) {
      println("XREFS TO " + target);
      ReferenceIterator refs = currentProgram.getReferenceManager().getReferencesTo(target);
      while (refs.hasNext() && !monitor.isCancelled()) {
        Reference ref = refs.next();
        Function function = getFunctionContaining(ref.getFromAddress());
        println("    " + ref.getFromAddress() + " " + ref.getReferenceType() +
                " function=" + (function == null ? "<none>" : function.getName()+"@"+function.getEntryPoint()));
      }
    }
  }
}

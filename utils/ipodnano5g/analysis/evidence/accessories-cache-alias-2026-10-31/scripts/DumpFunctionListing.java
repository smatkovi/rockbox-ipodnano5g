import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.Address;
import ghidra.program.model.listing.Function;
import ghidra.program.model.listing.Instruction;
import ghidra.program.model.listing.InstructionIterator;
import ghidra.program.model.symbol.Reference;
import ghidra.program.model.symbol.ReferenceIterator;

public class DumpFunctionListing extends GhidraScript {
  @Override
  public void run() throws Exception {
    for (String arg : getScriptArgs()) {
      Address entry = toAddr(Long.parseUnsignedLong(arg.replace("0x", ""), 16));
      Function f = getFunctionAt(entry);
      println("===== " + entry + " " + (f == null ? "<none>" : f.getName()) + " =====");
      if (f != null) {
        println("body=" + f.getBody() + " signature=" + f.getSignature());
        InstructionIterator it = currentProgram.getListing().getInstructions(f.getBody(), true);
        while (it.hasNext()) {
          Instruction ins = it.next();
          println(ins.getAddress() + ": " + ins);
        }
      }
      ReferenceIterator refs = currentProgram.getReferenceManager().getReferencesTo(entry);
      while (refs.hasNext()) {
        Reference ref = refs.next();
        Instruction ins = currentProgram.getListing().getInstructionAt(ref.getFromAddress());
        println("XREF " + ref.getFromAddress() + " " + (ins == null ? "<no instruction>" : ins.toString()));
      }
    }
  }
}

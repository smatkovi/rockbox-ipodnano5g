import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.Address;
import ghidra.program.model.listing.Function;
import ghidra.program.model.mem.MemoryBlock;
import ghidra.program.model.symbol.Reference;

public class QueryOsosRefs extends GhidraScript {
  @Override
  public void run() throws Exception {
    for (String arg : getScriptArgs()) {
      long value = Long.parseUnsignedLong(arg.replace("0x", ""), 16);
      Address target = toAddr(value);
      Function f = getFunctionAt(target);
      println("TARGET " + target + " function=" + (f == null ? "<none>" : f.getName()));
      for (Reference ref : getReferencesTo(target)) {
        Function caller = getFunctionContaining(ref.getFromAddress());
        println("  ref=" + ref.getFromAddress() + " type=" + ref.getReferenceType() + " caller=" + (caller == null ? "<none>" : caller.getName()+"@"+caller.getEntryPoint()));
      }
    }
    println("MEMORY BLOCKS");
    for (MemoryBlock b : currentProgram.getMemory().getBlocks()) {
      println("  " + b.getName() + " " + b.getStart() + "-" + b.getEnd() + " read=" + b.isRead() + " write=" + b.isWrite() + " execute=" + b.isExecute());
    }
  }
}

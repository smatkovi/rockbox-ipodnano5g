import ghidra.app.decompiler.DecompInterface;
import ghidra.app.decompiler.DecompileResults;
import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.Address;
import ghidra.program.model.listing.Function;
import ghidra.program.model.listing.Instruction;
import ghidra.program.model.listing.InstructionIterator;

public class DumpContainingFunction extends GhidraScript {
  @Override
  public void run() throws Exception {
    DecompInterface decomp = new DecompInterface();
    decomp.openProgram(currentProgram);
    for (String arg : getScriptArgs()) {
      Address address = toAddr(Long.parseUnsignedLong(arg.replace("0x", ""), 16));
      Function function = currentProgram.getFunctionManager().getFunctionContaining(address);
      println("===== CONTAINING " + address + " " +
              (function == null ? "<none>" : function.getEntryPoint() + " " + function.getName()) + " =====");
      if (function == null) {
        Address from = address.subtract(0x40);
        Address to = address.add(0x40);
        InstructionIterator iterator = currentProgram.getListing().getInstructions(from, true);
        while (iterator.hasNext()) {
          Instruction instruction = iterator.next();
          if (instruction.getAddress().compareTo(to) > 0) break;
          println(instruction.getAddress() + ": " + instruction);
        }
      } else {
        InstructionIterator iterator = currentProgram.getListing().getInstructions(function.getBody(), true);
        while (iterator.hasNext()) println(iterator.next().toString());
        DecompileResults result = decomp.decompileFunction(function, 30, monitor);
        if (result.decompileCompleted() && result.getDecompiledFunction() != null)
          println(result.getDecompiledFunction().getC());
        else println("DECOMPILE_FAILED " + result.getErrorMessage());
      }
    }
    decomp.dispose();
  }
}

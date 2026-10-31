import ghidra.app.decompiler.DecompInterface;
import ghidra.app.decompiler.DecompileResults;
import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.Address;
import ghidra.program.model.lang.Register;
import ghidra.program.model.listing.Function;
import ghidra.program.model.listing.Instruction;
import java.math.BigInteger;

public class DumpThumbTransientFunctions extends GhidraScript {
  @Override
  public void run() throws Exception {
    Register tMode = currentProgram.getProgramContext().getRegister("TMode");
    DecompInterface decomp = new DecompInterface();
    decomp.openProgram(currentProgram);
    for (String arg : getScriptArgs()) {
      long raw = Long.decode(arg);
      Address start = toAddr(raw & ~1L);
      int tx = currentProgram.startTransaction("transient Thumb function decode");
      try {
        Function containing = currentProgram.getFunctionManager().getFunctionContaining(start);
        if (containing != null && !containing.getEntryPoint().equals(start)) {
          println("===== THUMB FUNCTION " + start + " skipped: inside " +
            containing.getEntryPoint() + " =====");
          continue;
        }
        Function old = currentProgram.getFunctionManager().getFunctionAt(start);
        if (old != null) currentProgram.getFunctionManager().removeFunction(start);
        clearListing(start, start.add(3));
        currentProgram.getProgramContext().setValue(tMode, start, start, BigInteger.ONE);
        disassemble(start);
        Function f = createFunction(start, "transient_thumb_" + start.toString());
        println("===== THUMB FUNCTION " + start + " created=" + (f != null) + " =====");
        if (f == null) {
          println("<function creation failed>");
          continue;
        }
        DecompileResults result = decomp.decompileFunction(f, 30, monitor);
        if (result.decompileCompleted() && result.getDecompiledFunction() != null)
          println(result.getDecompiledFunction().getC());
        else
          println("DECOMPILE_FAILED " + result.getErrorMessage());
        for (Instruction ins : currentProgram.getListing().getInstructions(f.getBody(), true))
          println(ins.getAddress() + " " + ins);
      } finally {
        currentProgram.endTransaction(tx, false);
      }
    }
    decomp.dispose();
  }
}

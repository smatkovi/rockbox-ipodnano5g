import ghidra.app.decompiler.DecompInterface;
import ghidra.app.decompiler.DecompileResults;
import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.Address;
import ghidra.program.model.address.AddressSet;
import ghidra.program.model.lang.Register;
import ghidra.program.model.listing.Function;
import ghidra.program.model.listing.Instruction;
import java.math.BigInteger;

public class DumpThumbRange extends GhidraScript {
  @Override
  public void run() throws Exception {
    Register tMode = currentProgram.getProgramContext().getRegister("TMode");
    DecompInterface decomp = new DecompInterface();
    decomp.openProgram(currentProgram);
    for (int pair = 0; pair + 1 < getScriptArgs().length; pair += 2) {
      Address start = toAddr(Long.decode(getScriptArgs()[pair]) & ~1L);
      Address end = toAddr(Long.decode(getScriptArgs()[pair + 1]) & ~1L);
      clearListing(start, end);
      currentProgram.getProgramContext().setValue(tMode, start, end, BigInteger.ONE);
      disassemble(start);
      Function old = currentProgram.getFunctionManager().getFunctionAt(start);
      if (old != null) currentProgram.getFunctionManager().removeFunction(start);
      Function f = createFunction(start, "thumb_range_" + start.toString());
      if (f != null) {
        println("===== DECOMPILE " + start + " " + f.getBody() + " =====");
        DecompileResults result = decomp.decompileFunction(f, 60, monitor);
        if (result != null && result.getDecompiledFunction() != null)
          println(result.getDecompiledFunction().getC());
      }
      println("===== LISTING " + start + ".." + end + " =====");
      for (Instruction i : currentProgram.getListing().getInstructions(new AddressSet(start, end), true))
        println(i.getAddress() + "  " + i);
    }
    decomp.dispose();
  }
}

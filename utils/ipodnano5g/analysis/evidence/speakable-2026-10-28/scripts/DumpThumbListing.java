import ghidra.app.decompiler.DecompInterface;
import ghidra.app.decompiler.DecompileResults;
import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.Address;
import ghidra.program.model.lang.Register;
import ghidra.program.model.listing.Function;
import ghidra.program.model.listing.Instruction;
import java.math.BigInteger;

public class DumpThumbListing extends GhidraScript {
  public void run() throws Exception {
    Register tMode = currentProgram.getProgramContext().getRegister("TMode");
    DecompInterface d = new DecompInterface();
    d.openProgram(currentProgram);
    for (String s : getScriptArgs()) {
      long raw = Long.decode(s);
      Address start = toAddr(raw & ~1L);
      Function old = currentProgram.getFunctionManager().getFunctionAt(start);
      if (old != null) currentProgram.getFunctionManager().removeFunction(start);
      clearListing(start, start.add(3));
      currentProgram.getProgramContext().setValue(tMode, start, start, BigInteger.ONE);
      disassemble(start);
      Function f = createFunction(start, "thumb_dump_" + Long.toHexString(raw & ~1L));
      println("===== " + start + " " + f + " =====");
      if (f == null) continue;
      DecompileResults result = d.decompileFunction(f, 30, monitor);
      if (result != null && result.getDecompiledFunction() != null) println(result.getDecompiledFunction().getC());
      for (Instruction i : currentProgram.getListing().getInstructions(f.getBody(), true)) {
        println(i.getAddress() + "  " + i);
      }
    }
    d.dispose();
  }
}

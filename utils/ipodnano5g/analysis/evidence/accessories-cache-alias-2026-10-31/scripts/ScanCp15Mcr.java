import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.AddressSet;
import ghidra.program.model.listing.Function;
import ghidra.program.model.listing.Instruction;
import ghidra.program.model.listing.InstructionIterator;

public class ScanCp15Mcr extends GhidraScript {
  @Override
  public void run() throws Exception {
    AddressSet all = new AddressSet(currentProgram.getMinAddress(), currentProgram.getMaxAddress());
    InstructionIterator it = currentProgram.getListing().getInstructions(all, true);
    while (it.hasNext() && !monitor.isCancelled()) {
      Instruction ins = it.next();
      String text = ins.toString().toLowerCase();
      if (ins.getMnemonicString().toLowerCase().startsWith("mcr") &&
          text.startsWith("mcr p15,")) {
        Function f = getFunctionContaining(ins.getAddress());
        println(ins.getAddress() + " " + ins + " function=" +
            (f == null ? "<none>" : f.getName() + "@" + f.getEntryPoint()));
      }
    }
  }
}

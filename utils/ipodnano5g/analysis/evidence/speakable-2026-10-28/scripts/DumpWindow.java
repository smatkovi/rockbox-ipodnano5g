import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.Address;
import ghidra.program.model.address.AddressSet;
import ghidra.program.model.listing.Instruction;
public class DumpWindow extends GhidraScript {
  @Override public void run() throws Exception {
    Address start=toAddr(Long.parseUnsignedLong(getScriptArgs()[0].replace("0x",""),16));
    Address end=toAddr(Long.parseUnsignedLong(getScriptArgs()[1].replace("0x",""),16));
    for(Instruction i: currentProgram.getListing().getInstructions(new AddressSet(start,end),true)) println(i.getAddress()+"  "+i);
  }
}

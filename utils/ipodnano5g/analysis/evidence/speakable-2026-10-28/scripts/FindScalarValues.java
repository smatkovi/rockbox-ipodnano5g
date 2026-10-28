import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.AddressSet;
import ghidra.program.model.listing.Function;
import ghidra.program.model.listing.Instruction;
import ghidra.program.model.listing.InstructionIterator;
import ghidra.program.model.scalar.Scalar;

public class FindScalarValues extends GhidraScript {
    @Override
    public void run() throws Exception {
        for (Instruction ins : currentProgram.getListing().getInstructions(
                new AddressSet(currentProgram.getMinAddress(), currentProgram.getMaxAddress()), true)) {
            StringBuilder hits = new StringBuilder();
            for (int op = 0; op < ins.getNumOperands(); op++) {
                for (Object obj : ins.getOpObjects(op)) {
                    if (obj instanceof Scalar) {
                        long v = ((Scalar)obj).getUnsignedValue();
                        for (String arg : getScriptArgs()) {
                            long target = Long.decode(arg);
                            if (v == target) hits.append(" op").append(op).append("=0x")
                                    .append(Long.toHexString(v));
                        }
                    }
                }
            }
            if (hits.length() != 0) {
                Function f = getFunctionContaining(ins.getAddress());
                println(ins.getAddress() + " " + ins + hits + " function=" +
                        (f == null ? "<none>" : f.getName()+"@"+f.getEntryPoint()));
            }
        }
    }
}

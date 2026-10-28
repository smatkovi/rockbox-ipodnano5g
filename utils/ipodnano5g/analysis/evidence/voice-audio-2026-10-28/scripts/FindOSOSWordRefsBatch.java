import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.Address;
import ghidra.program.model.listing.CodeUnit;
import ghidra.program.model.listing.Instruction;
import ghidra.program.model.listing.Function;
import ghidra.program.model.mem.MemoryBlock;
import ghidra.program.model.symbol.Reference;
import ghidra.program.model.symbol.ReferenceIterator;

public class FindOSOSWordRefsBatch extends GhidraScript {
    @Override public void run() throws Exception {
        for (String arg : getScriptArgs()) {
            int target = (int) Long.decode(arg).longValue();
            println(String.format("TARGET_WORD 0x%08x", target));
            for (MemoryBlock block : currentProgram.getMemory().getBlocks()) {
                if (!block.isInitialized()) continue;
                Address a = block.getStart();
                Address end = block.getEnd();
                while (a.compareTo(end.subtract(3)) <= 0) {
                    if (currentProgram.getMemory().getInt(a) == target) {
                        CodeUnit cu = currentProgram.getListing().getCodeUnitAt(a);
                        Function f = currentProgram.getFunctionManager().getFunctionContaining(a);
                        println("MATCH " + a + " block=" + block.getName() + " cu=" + cu +
                            " function=" + (f == null ? "<none>" : f.getName()));
                        ReferenceIterator refs = currentProgram.getReferenceManager().getReferencesTo(a);
                        while (refs.hasNext()) {
                            Reference ref = refs.next();
                            Instruction ins = currentProgram.getListing().getInstructionAt(ref.getFromAddress());
                            Function rf = currentProgram.getFunctionManager().getFunctionContaining(ref.getFromAddress());
                            println("  REF " + ref.getFromAddress() + " " + ref.getReferenceType() + " ins=" + ins +
                                " function=" + (rf == null ? "<none>" : rf.getName()));
                        }
                    }
                    a = a.add(4);
                }
            }
        }
    }
}

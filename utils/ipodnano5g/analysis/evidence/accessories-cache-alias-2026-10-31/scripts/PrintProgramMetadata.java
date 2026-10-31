import ghidra.app.script.GhidraScript;
import ghidra.program.model.mem.MemoryBlock;

public class PrintProgramMetadata extends GhidraScript {
  @Override public void run() throws Exception {
    println("PROGRAM=" + currentProgram.getName());
    println("LANGUAGE=" + currentProgram.getLanguage().getLanguageID());
    println("COMPILER=" + currentProgram.getCompilerSpec().getCompilerSpecID());
    for (MemoryBlock block : currentProgram.getMemory().getBlocks()) {
      println("BLOCK=" + block.getName() + " " + block.getStart() + "-" +
          block.getEnd() + " initialized=" + block.isInitialized());
    }
  }
}

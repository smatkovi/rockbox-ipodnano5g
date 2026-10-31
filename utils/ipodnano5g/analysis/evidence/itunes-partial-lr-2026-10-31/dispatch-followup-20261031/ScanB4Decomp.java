import ghidra.app.decompiler.DecompInterface;
import ghidra.app.decompiler.DecompileResults;
import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.Address;
import ghidra.program.model.listing.Function;
import ghidra.program.model.listing.Instruction;
import ghidra.program.model.listing.InstructionIterator;
import java.util.LinkedHashMap;
import java.util.Locale;
import java.util.Map;
import java.util.regex.Pattern;

public class ScanB4Decomp extends GhidraScript {
  private static final Pattern B4 = Pattern.compile("#(?:0x0*b4|180)\\s*\\]", Pattern.CASE_INSENSITIVE);

  @Override
  public void run() throws Exception {
    Map<String, Function> candidates = new LinkedHashMap<>();
    Map<String, Integer> loadCounts = new LinkedHashMap<>();
    int loads = 0;
    InstructionIterator it = currentProgram.getListing().getInstructions(true);
    while (it.hasNext()) {
      monitor.checkCancelled();
      Instruction ins = it.next();
      if (!ins.getMnemonicString().toLowerCase(Locale.ROOT).startsWith("ldr") ||
          !B4.matcher(ins.toString()).find()) continue;
      loads++;
      Function f = getFunctionContaining(ins.getAddress());
      if (f == null) continue;
      String key = f.getEntryPoint().toString();
      candidates.put(key, f);
      loadCounts.put(key, loadCounts.getOrDefault(key, 0) + 1);
    }
    println("SUMMARY ldr_b4=" + loads + " unique_functions=" + candidates.size());
    DecompInterface decomp = new DecompInterface();
    decomp.openProgram(currentProgram);
    int matchingFunctions = 0;
    for (Map.Entry<String, Function> entry : candidates.entrySet()) {
      monitor.checkCancelled();
      Function f = entry.getValue();
      DecompileResults result = decomp.decompileFunction(f, 8, monitor);
      if (!result.decompileCompleted() || result.getDecompiledFunction() == null) {
        println("DECOMPILE_FAILED " + f.getEntryPoint() + " " + f.getName() + " " + result.getErrorMessage());
        continue;
      }
      String[] lines = result.getDecompiledFunction().getC().split("\\R");
      boolean found = false;
      for (String line : lines) {
        String lower = line.toLowerCase(Locale.ROOT);
        if (lower.contains("+ 0xb4") || lower.contains("+0xb4") || lower.contains("+ 180")) {
          if (!found) {
            println("FUNCTION " + f.getEntryPoint() + " " + f.getName() +
                    " b4_loads=" + loadCounts.get(entry.getKey()));
            matchingFunctions++;
            found = true;
          }
          println("  " + line.trim());
        }
      }
    }
    println("SUMMARY decompiled_functions=" + candidates.size() +
            " functions_with_decomp_b4=" + matchingFunctions);
    decomp.dispose();
  }
}

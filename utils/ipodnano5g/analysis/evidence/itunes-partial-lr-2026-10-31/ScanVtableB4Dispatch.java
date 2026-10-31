import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.Address;
import ghidra.program.model.listing.Function;
import ghidra.program.model.listing.Instruction;
import ghidra.program.model.listing.InstructionIterator;
import java.util.Locale;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

public class ScanVtableB4Dispatch extends GhidraScript {
  private static final Pattern OFFSET_B4 = Pattern.compile("#(?:0x0*B4|180)\\]", Pattern.CASE_INSENSITIVE);
  private static final Pattern REGISTER = Pattern.compile("^\\s*\\w+(?:\\.\\w+)?\\s+(r(?:1[0-5]|[0-9])|ip|lr)\\s*,", Pattern.CASE_INSENSITIVE);

  @Override
  public void run() throws Exception {
    int loadsAtB4 = 0;
    int indirectDispatches = 0;
    InstructionIterator it = currentProgram.getListing().getInstructions(true);
    while (it.hasNext()) {
      monitor.checkCancelled();
      Instruction ins = it.next();
      String mnemonic = ins.getMnemonicString().toLowerCase(Locale.ROOT);
      String text = ins.toString();
      if (!mnemonic.startsWith("ldr") || !OFFSET_B4.matcher(text).find()) continue;
      loadsAtB4++;
      Matcher regMatcher = REGISTER.matcher(text);
      if (!regMatcher.find()) continue;
      String reg = regMatcher.group(1).toLowerCase(Locale.ROOT);
      Instruction next = ins;
      boolean dispatch = false;
      StringBuilder window = new StringBuilder();
      for (int n = 0; n < 8; n++) {
        next = currentProgram.getListing().getInstructionAfter(next.getAddress());
        if (next == null) break;
        String nextText = next.toString();
        if (window.length() > 0) window.append(" | ");
        window.append(next.getAddress()).append(":").append(nextText);
        String lower = nextText.toLowerCase(Locale.ROOT).trim();
        if ((lower.startsWith("blx ") || lower.startsWith("bx ")) &&
            lower.matches("(?:blx|bx)\\s+" + Pattern.quote(reg) + "(?:\\s|$).*")) {
          dispatch = true;
          break;
        }
        if (lower.matches("(?:mov|movs)\\s+" + Pattern.quote(reg) + ",.*")) break;
      }
      if (dispatch) {
        indirectDispatches++;
        Function f = getFunctionContaining(ins.getAddress());
        println("B4_DISPATCH at=" + ins.getAddress() + " function=" +
          (f == null ? "<none>" : f.getEntryPoint() + " " + f.getName()) +
          " load=" + text + " window=" + window);
      }
    }
    println("SUMMARY ldr_offset_0xb4=" + loadsAtB4 + " direct_register_dispatches=" + indirectDispatches);
  }
}

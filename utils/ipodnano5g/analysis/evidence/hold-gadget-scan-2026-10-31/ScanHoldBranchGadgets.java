// Read-only scan for conditional return paths after an r0-zero test.
// Run with analyzeHeadless -readOnly -noanalysis against the OSOS runtime.

import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.Address;
import ghidra.program.model.lang.Register;
import ghidra.program.model.listing.Function;
import ghidra.program.model.listing.FunctionIterator;
import ghidra.program.model.listing.Instruction;
import ghidra.program.model.listing.InstructionIterator;
import ghidra.program.model.listing.Listing;
import ghidra.program.model.scalar.Scalar;
import ghidra.program.model.symbol.FlowType;

import java.util.ArrayList;
import java.util.HashSet;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import java.util.List;
import java.util.Set;

public class ScanHoldBranchGadgets extends GhidraScript {
    private static boolean hasR0(Object[] objects) {
        for (Object object : objects) {
            if (object instanceof Register && "r0".equalsIgnoreCase(((Register)object).getName())) {
                return true;
            }
        }
        return false;
    }

    private static boolean hasImmediateZero(Object[] objects) {
        for (Object object : objects) {
            if (object instanceof Scalar && ((Scalar)object).getUnsignedValue() == 0) {
                return true;
            }
        }
        return false;
    }

    private static boolean isR0ZeroCompare(Instruction instruction) {
        return instruction != null
            && "CMP".equalsIgnoreCase(instruction.getMnemonicString())
            && hasR0(instruction.getOpObjects(0))
            && hasImmediateZero(instruction.getOpObjects(1));
    }

    private static boolean isR0ZeroTest(Instruction instruction) {
        if (instruction == null) {
            return false;
        }
        String mnemonic = instruction.getMnemonicString();
        return ("CBZ".equalsIgnoreCase(mnemonic) || "CBNZ".equalsIgnoreCase(mnemonic))
            && hasR0(instruction.getOpObjects(0));
    }

    private static boolean isStackReturn(Instruction instruction) {
        if (instruction == null) {
            return false;
        }
        String mnemonic = instruction.getMnemonicString().toUpperCase();
        String text = instruction.toString().toUpperCase();
        return (mnemonic.equals("POP") || mnemonic.equals("POP.W"))
                && (text.contains("PC") || text.contains("R15"))
            || (mnemonic.equals("LDMIA") || mnemonic.equals("LDMFD"))
                && (text.contains("PC") || text.contains("R15"));
    }

    private static String describe(Instruction instruction) {
        return instruction == null
            ? "<no instruction>"
            : instruction.getAddress() + ": " + instruction;
    }

    private List<Instruction> findStackReturn(Address start, Function function, Listing listing) {
        List<Instruction> path = new ArrayList<>();
        Address cursor = start;
        for (int i = 0; i < 5 && cursor != null && function.getBody().contains(cursor); i++) {
            Instruction instruction = listing.getInstructionAt(cursor);
            if (instruction == null) {
                return null;
            }
            path.add(instruction);
            if (isStackReturn(instruction)) {
                return path;
            }
            FlowType flow = instruction.getFlowType();
            if (flow.isJump() || flow.isTerminal()) {
                return null;
            }
            cursor = instruction.getMaxAddress().next();
        }
        return null;
    }

    private static Integer instructionStackDelta(Instruction instruction) {
        String mnemonic = instruction.getMnemonicString().toUpperCase();
        String text = instruction.toString().toLowerCase();
        if (mnemonic.startsWith("BL")) {
            return null;
        }
        if ((mnemonic.startsWith("POP") && !mnemonic.equals("POP") && !mnemonic.equals("POP.W"))
                || (mnemonic.startsWith("PUSH") && !mnemonic.equals("PUSH") && !mnemonic.equals("PUSH.W"))) {
            return null;
        }
        if (mnemonic.equals("PUSH") || mnemonic.equals("PUSH.W")
                || mnemonic.equals("POP") || mnemonic.equals("POP.W")) {
            int count = registerCount(text);
            if (count < 0) return null;
            return (mnemonic.startsWith("POP") ? 4 : -4) * count;
        }
        if (mnemonic.equals("LDMIA") || mnemonic.equals("LDMFD")
                || mnemonic.equals("STMDB") || mnemonic.equals("STMFD")) {
            if (!text.contains("sp!,")) return 0;
            int count = registerCount(text);
            if (count < 0) return null;
            return (mnemonic.startsWith("LDM") ? 4 : -4) * count;
        }
        if (mnemonic.equals("ADD") || mnemonic.equals("ADDS")
                || mnemonic.equals("SUB") || mnemonic.equals("SUBS")) {
            Matcher matcher = Pattern.compile("(?:add|adds|sub|subs)\\s+sp(?:,sp)?,#(0x[0-9a-f]+|[0-9]+)")
                .matcher(text);
            if (matcher.find()) {
                int value = (int)Long.decode(matcher.group(1)).longValue();
                return (mnemonic.startsWith("ADD") ? value : -value);
            }
            if (text.matches(".*\\bsp\\b.*")) return null;
        }
        if ((mnemonic.startsWith("ADD") || mnemonic.startsWith("SUB"))
                && text.matches(".*\\bsp\\b.*")) {
            return null;
        }
        if ((mnemonic.startsWith("LDM") || mnemonic.startsWith("STM"))
                && text.contains("sp!")) {
            return null;
        }
        return 0;
    }

    private static int registerCount(String instructionText) {
        int start = instructionText.indexOf('{');
        int end = instructionText.indexOf('}', start + 1);
        if (start < 0 || end < 0) return -1;
        String registers = instructionText.substring(start + 1, end).trim();
        if (registers.isEmpty()) return -1;
        return registers.split(",").length;
    }

    private static Integer stackDelta(List<Instruction> path) {
        int total = 0;
        for (Instruction instruction : path) {
            Integer delta = instructionStackDelta(instruction);
            if (delta == null) return null;
            total += delta;
        }
        return total;
    }

    private void inspect(Instruction test, Instruction branch, Function function, Listing listing) {
        if (!branch.getFlowType().isConditional() || !branch.getFlowType().isJump()) {
            return;
        }
        Address[] targets = branch.getFlows();
        if (targets.length == 0) {
            return;
        }
        Address takenAddress = targets[0];
        Address fallthroughAddress = branch.getMaxAddress().next();
        List<Instruction> taken = findStackReturn(takenAddress, function, listing);
        List<Instruction> fallthrough = findStackReturn(fallthroughAddress, function, listing);
        if (taken == null || fallthrough == null) {
            return;
        }
        Integer takenDelta = stackDelta(taken);
        Integer fallthroughDelta = stackDelta(fallthrough);
        if (takenDelta == null || fallthroughDelta == null || takenDelta.equals(fallthroughDelta)) {
            return;
        }
        println(String.format("TEST %s | FUNCTION %s %s | BRANCH %s",
            describe(test), function.getEntryPoint(), function.getName(), describe(branch)));
        println("  TAKEN net-sp=" + takenDelta + ": " + join(taken));
        println("  FALL net-sp=" + fallthroughDelta + ": " + join(fallthrough));
    }

    private static String join(List<Instruction> instructions) {
        List<String> parts = new ArrayList<>();
        for (Instruction instruction : instructions) {
            parts.add(describe(instruction));
        }
        return String.join(" | ", parts);
    }

    @Override
    public void run() throws Exception {
        Listing listing = currentProgram.getListing();
        Set<Address> seen = new HashSet<>();
        int comparisons = 0;
        int zeroTests = 0;
        int pairedReturns = 0;
        int comparableReturns = 0;
        int divergentReturns = 0;
        FunctionIterator functions = currentProgram.getFunctionManager().getFunctions(true);
        while (functions.hasNext() && !monitor.isCancelled()) {
            Function function = functions.next();
            InstructionIterator instructions = listing.getInstructions(function.getBody(), true);
            while (instructions.hasNext() && !monitor.isCancelled()) {
                Instruction instruction = instructions.next();
                if (!seen.add(instruction.getAddress())) {
                    continue;
                }
                boolean isTest = isR0ZeroTest(instruction);
                boolean isCompare = isR0ZeroCompare(instruction);
                if (isTest) zeroTests++;
                if (isCompare) comparisons++;
                if (!isTest && !isCompare) continue;
                Instruction next = listing.getInstructionAfter(instruction.getAddress());
                if (next == null || !next.getFlowType().isConditional()) continue;
                Address[] targets = next.getFlows();
                if (targets.length == 0) continue;
                boolean paired = findStackReturn(targets[0], function, listing) != null
                    && findStackReturn(next.getMaxAddress().next(), function, listing) != null;
                if (paired) {
                    pairedReturns++;
                    List<Instruction> taken = findStackReturn(targets[0], function, listing);
                    List<Instruction> fallthrough = findStackReturn(next.getMaxAddress().next(), function, listing);
                    Integer takenDelta = stackDelta(taken);
                    Integer fallthroughDelta = stackDelta(fallthrough);
                    if (takenDelta != null && fallthroughDelta != null) comparableReturns++;
                    if (takenDelta != null && fallthroughDelta != null && !takenDelta.equals(fallthroughDelta))
                        divergentReturns++;
                    inspect(instruction, next, function, listing);
                }
            }
        }
        println(String.format("SUMMARY defined-instructions=%d cmp-r0-zero=%d cbz-cbnz-r0=%d paired-stack-returns=%d comparable-no-call-returns=%d different-net-sp=%d",
            seen.size(), comparisons, zeroTests, pairedReturns, comparableReturns, divergentReturns));
    }
}

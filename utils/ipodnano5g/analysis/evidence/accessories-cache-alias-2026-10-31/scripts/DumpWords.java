import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.Address;
import ghidra.program.model.listing.Function;
import ghidra.program.model.listing.Data;

public class DumpWords extends GhidraScript {
    @Override public void run() throws Exception {
        if (getScriptArgs().length < 2) throw new Exception("start and word count required");
        Address a = toAddr(Long.decode(getScriptArgs()[0]));
        int count = Integer.decode(getScriptArgs()[1]);
        for (int i=0; i<count; i++,a=a.add(4)) {
            int v = currentProgram.getMemory().getInt(a);
            Address p = toAddr(Integer.toUnsignedLong(v));
            Function f = currentProgram.getFunctionManager().getFunctionAt(p);
            if (f==null) f=currentProgram.getFunctionManager().getFunctionContaining(p);
            Data d = currentProgram.getListing().getDataAt(p);
            println(String.format("%s  %08x  function=%s data=%s", a, v,
                f==null?"-":f.getName()+"@"+f.getEntryPoint(), d));
        }
    }
}

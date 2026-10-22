# Assemble sequencer programs into static arrays for nand-nano4g.c.

FMSS_DIR := $(FIRMDIR)/target/arm/s5l8702/ipodnano4g/fmss
ifeq ($(MODELNAME),ipodnano5g)
# 8 KiB pages: the looped READ program, no PROGRAM / ERASE yet (read-only)
FMSS_SRC := $(FMSS_DIR)/reset.s $(FMSS_DIR)/readid.s \
            $(FIRMDIR)/target/arm/s5l8702/ipodnano5g/fmss/read.s
else
FMSS_SRC := $(FMSS_DIR)/reset.s $(FMSS_DIR)/readid.s $(FMSS_DIR)/read.s
ifeq (,$(findstring -DBOOTLOADER,$(EXTRA_DEFINES)))
FMSS_SRC += $(FMSS_DIR)/program.s $(FMSS_DIR)/erase.s
endif
endif

$(BUILDDIR)/fmss-nano4g.h: $(FMSS_SRC) $(TOOLSDIR)/fmssasm
	$(call PRINTS,FMSSASM $(@F))$(TOOLSDIR)/fmssasm -s $@ $(FMSS_SRC)

CLEANOBJS += $(BUILDDIR)/fmss-nano4g.*

# the driver includes the generated header
$(BUILDDIR)/firmware/target/arm/s5l8702/ipodnano4g/nand-nano4g.o: $(BUILDDIR)/fmss-nano4g.h

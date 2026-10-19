# Assemble sequencer programs into static arrays for nand-nano4g.c.

FMSS_DIR := $(FIRMDIR)/target/arm/s5l8702/ipodnano4g/fmss
FMSS_SRC := $(FMSS_DIR)/reset.s $(FMSS_DIR)/readid.s $(FMSS_DIR)/read.s

$(BUILDDIR)/fmss-nano4g.h: $(FMSS_SRC) $(TOOLSDIR)/fmssasm
	$(call PRINTS,FMSSASM $(@F))$(TOOLSDIR)/fmssasm -s $@ $(FMSS_SRC)

CLEANOBJS += $(BUILDDIR)/fmss-nano4g.*

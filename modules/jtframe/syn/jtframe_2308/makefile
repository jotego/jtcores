PROJECT=adc_test
SOURCE_FILES= \
	../../hdl/mister/jtframe_2308.v \
	adc_test.v set_pins.tcl

ASSIGNMENT_FILES = adc_test.qpf adc_test.qsf

all: smart.log $(PROJECT).asm.rpt $(PROJECT).sta.rpt

clean:
	rm -rf *.rpt *.chg smart.log *.htm *.eqn *.pin *.sof *.pof db qdb
	rm -rf hc_output incremental_db *jdi *fit.* *summary
	rm -f $(PROJECT).qsf *.qws *.qpf *.smsg

prog: $(PROJECT).sof
	quartus_pgm -c "DE-SoC [1-1.2.1.1]" $(PROJECT).sof

map: smart.log $(PROJECT).map.rpt
fit: smart.log $(PROJECT).fit.rpt
asm: smart.log $(PROJECT).asm.rpt
sta: smart.log $(PROJECT).sta.rpt
smart: smart.log

MAP_ARGS = --family="Cyclone V"
# MAP_ARGS = --part=5CSEBA6U23I7DK
FIT_ARGS = --part=5CSEBA6U23I7
ASM_ARGS =
STA_ARGS =

STAMP = echo done >

$(PROJECT).map.rpt: map.chg $(SOURCE_FILES)
	quartus_map $(MAP_ARGS) $(PROJECT)
	$(STAMP) asm.chg
	$(STAMP) sta.chg

$(PROJECT).fit.rpt: fit.chg $(PROJECT).map.rpt
	quartus_fit $(FIT_ARGS) $(PROJECT)
	$(STAMP) asm.chg
	# $(STAMP) sta.chg

$(PROJECT).asm.rpt: asm.chg $(PROJECT).fit.rpt
	quartus_asm $(ASM_ARGS) $(PROJECT)

$(PROJECT).sta.rpt: sta.chg $(PROJECT).fit.rpt
	quartus_sta $(STA_ARGS) $(PROJECT)

smart.log: $(ASSIGNMENT_FILES)
	quartus_sh --determine_smart_action $(PROJECT) > smart.log

$(ASSIGNMENT_FILES): set_pins.tcl
	quartus_sh --prepare $(PROJECT)
	quartus_sh -t set_pins.tcl

map.chg:
	$(STAMP) map.chg
fit.chg:
	$(STAMP) fit.chg
sta.chg:
	$(STAMP) sta.chg
asm.chg:
	$(STAMP) asm.chg


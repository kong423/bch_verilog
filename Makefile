SIM_DIR=$(HOME)/opt/Xilinx/current/ISE_DS/ISE/verilog/src
IVERILOG=~/src/iverilog/_install/bin/iverilog

BINS=tb_bch_encode tb_bch_syndrome tb_test
VFLAGS=-y$(SIM_DIR)/unisims -g2005-sv -Wall

ifdef N
ON = -Ptb_sim.N=$(N)
endif

ifdef K
OK = -Ptb_sim.K=$(K)
endif

ifdef T
OT = -Ptb_sim.T=$(T)
endif

ifdef SEED
OSEED = -Ptb_sim.SEED=$(SEED)
endif

ifdef OPTION
OOPTION = -Ptb_sim.OPTION=\"$(OPTION)\"
endif

all: $(BINS)

tb_bch_encode: tb_bch_encode.v bch_encode.v
	$(IVERILOG) $(VFLAGS) $^ -o $@

tb_bch_decode: tb_bch_decode.v bch_decode.v bch_math.v bch_decode_control.v bch_syndrome.v chien.v
	$(IVERILOG) $(VFLAGS) $^ -o $@

tb_sim: tb_sim.v sim.v bch_encode.v bch_decode.v bch_math.v bch_decode_control.v bch_syndrome.v chien.v
	$(IVERILOG) $(VFLAGS) $^ -o $@ $(ON) $(OK) $(OT) $(OSEED) $(OOPTION)

tb_bch_syndrome: tb_bch_syndrome.v bch_syndrome.v
	$(IVERILOG) $(VFLAGS) $^ -o $@

tb_test: tb_test.v
	$(IVERILOG) $(VFLAGS) $^ -o $@

clean:
	-rm -f $(BINS)
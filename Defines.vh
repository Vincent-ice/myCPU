`define FpD_BUS_Wid     32+32+1+1+8+1
`define pDD_BUS_Wid     32+32+1+1+8+1+64+9+1+1+32
`define DE_BUS_Wid      32+1+32+1+32+6+32+32+`alu_op_Wid+32+32+32+1+4+5+4+1+8+1+14+1+32+32+32+1
`define EM_BUS_Wid      `WpD_BUS_Wid+32+32+1+5+4+32+1+8+1+14+1+32+32
`define MW_BUS_Wid      `WpD_BUS_Wid+32+32+1+5+32+1+8+1+14+1+32+32
`define predict_BUS_Wid 1+32
`define Branch_BUS_Wid  32+1
`define Wrf_BUS_Wid     1+5+32
`define Wcsr_BUS_Wid    1+8+1+1+14+32+32+32+32
`define WpD_BUS_Wid     32+1+1+1+32
`define PB_BUS_Wid      `WpD_BUS_Wid+32
`define ED_for_BUS_Wid  4+5+32+1+14+32+32
`define MD_for_BUS_Wid  5+32+1+14+32+32

`define alu_op_Wid      19

`define TLBNUM          16
`define CSR2TLB_BUS_Wid    1+$clog2(`TLBNUM)+1+19+6+10+1+20+2+2+1+1+20+2+2+1+1+$clog2(`TLBNUM)
`define CSR2TLB_BUS_DE_Wid 5+5+1+$clog2(`TLBNUM)+1+19+6+10+1+20+2+2+1+1+20+2+2+1+1+$clog2(`TLBNUM)
`define CSR2TLB_BUS_EM_Wid `CSR2TLB_BUS_DE_Wid
`define CSR2TLB_BUS_MW_Wid 1+5+1+$clog2(`TLBNUM)+1+19+6+10+1+20+2+2+1+1+20+2+2+1+1
`define TLB2CSR_BUS_Wid    4+1+$clog2(`TLBNUM)+1+19+6+10+1+20+2+2+1+1+20+2+2+1+1
`define TLB2CSR_BUS_EM_Wid 1+$clog2(`TLBNUM)
`define TLB2CSR_BUS_MW_Wid 4+`TLB2CSR_BUS_EM_Wid+1+19+6+10+1+20+2+2+1+1+20+2+2+1+1
`define TLB2CSR_BUS_WD_Wid `TLB2CSR_BUS_MW_Wid

`define CSR2FE_BUS_Wid  10+1+1+2+1+1+3+3+1+1+3+3

`define ECODE_PIL       8'h01
`define ECODE_PIS       8'h02
`define ECODE_PIF       8'h03
`define ECODE_PME       8'h04
`define ECODE_PNR       8'h05
`define ECODE_PNX       8'h06
`define ECODE_PPI       8'h07
`define ECODE_ADEF      8'h08
`define ESUBCODE_ADEF   1'b0
`define ECODE_ADEM      8'h08
`define ESUBCODE_ADEM   1'b1
`define ECODE_ALE       8'h09
`define ECODE_BCE       8'h0a
`define ECODE_SYS       8'h0b
`define ECODE_BRK       8'h0c
`define ECODE_INE       8'h0d
`define ECODE_IPE       8'h0e
`define ECODE_FPD       8'h0f
`define ECODE_SXD       8'h10
`define ECODE_ASXD      8'h11
`define ECODE_FPE       8'h12
`define ESUBCODE_FPE    1'b0
`define ECODE_VFPE      8'h12
`define ESUBCODE_VFPE   1'b1
`define ECODE_WPEF      8'h13
`define ESUBCODE_WPEF   1'b0
`define ECODE_WPEM      8'h13
`define ESUBCODE_WPEM   1'b1
`define ECODE_ERTN      8'h14
`define ECODE_INT       8'h0
`define ECODE_TLBR      8'h3f

`define BTB_NUM         16
`define BHR_Wid         4
`define BHT_INDEX_Wid   5
`define TC_NUM          2**`BHR_Wid

`ifdef DIFFTEST_EN
    `define DIFFTEST_RAM_BUS_Wid 8+8+32+32+32
`endif
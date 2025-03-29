`define CSR_CRMD            14'h00
`define CSR_CRMD_PLV        csr_CRMD[1:0]    //RW
`define CSR_CRMD_IE         csr_CRMD[2]      //RW
`define CSR_CRMD_DA         csr_CRMD[3]      //RW
`define CSR_CRMD_PG         csr_CRMD[4]      //RW
`define CSR_CRMD_DATF       csr_CRMD[6:5]    //RW
`define CSR_CRMD_DATM       csr_CRMD[8:7]    //RW
//                          csr_CRMD[31:9]   = 0

`define CSR_PRMD            14'h01
`define CSR_PRMD_PPLV       csr_PRMD[1:0]    //RW
`define CSR_PRMD_PIE        csr_PRMD[2]      //RW
//                          csr_PRMD[31:3]   = 0

`define CSR_EUEN            14'h02
`define CSR_EUEN_FPE        csr_EUEN[0]      //RW
//                          csr_EUEN[31:1]   = 0

`define CSR_ECFG            14'h04
`define CSR_ECFG_LIE_9_0    csr_ECFG[9:0]    //RW
//                          csr_ECFG[10]     = 0
`define CSR_ECFG_LIE_12_11  csr_ECFG[12:11]  //RW
//                          csr_ECFG[31:13]  = 0

`define CSR_ESTAT           14'h05
`define CSR_ESTAT_IS_1_0    csr_ESTAT[1:0]   //RW
`define CSR_ESTAT_IS_9_2    csr_ESTAT[9:2]   //R
//                          csr_ESTAT[10]    = 0
`define CSR_ESTAT_IS_11     csr_ESTAT[11]    //R
`define CSR_ESTAT_IS_12     csr_ESTAT[12]    //R
//                          csr_ESTAT[15:13] = 0
`define CSR_ESTAT_ECODE     csr_ESTAT[21:16] //R
`define CSR_ESTAT_ESUBCODE  csr_ESTAT[30:22] //R
//                          csr_ESTAT[31]    = 0

`define CSR_ERA             14'h06
`define CSR_ERA_PC          csr_ERA[31:0]    //RW

`define CSR_BADV            14'h07
`define CSR_BADV_VADDR      csr_BADV[31:0]   //RW

`define CSR_EENTRY          14'h0c
//                          csr_EENTRY[ 5:0] = 0
`define CSR_EENTRY_VA       csr_EENTRY[31:6] //RW

`define CSR_TLBIDX          14'h10
`define CSR_TLBIDX_INDEX    csr_TLBIDX[$clog2(`TLBNUM)-1:0] //RW
//                          csr_TLBIDX[23:$clog2(TLBNUM)]= 0
`define CSR_TLBIDX_PS       csr_TLBIDX[29:24]//RW
//                          csr_TLBIDX[30]   = 0
`define CSR_TLBIDX_NE       csr_TLBIDX[31]   //RW

`define CSR_TLBEHI          14'h11
//                          csr_TLBEHI[12:0] = 0
`define CSR_TLBEHI_VPPN     csr_TLBEHI[31:13]//RW

`define CSR_TLBELO0         14'h12
`define CSR_TLBELO0_V       csr_TLBELO0[0]   //RW
`define CSR_TLBELO0_D       csr_TLBELO0[1]   //RW
`define CSR_TLBELO0_PLV     csr_TLBELO0[3:2] //RW
`define CSR_TLBELO0_MAT     csr_TLBELO0[5:4] //RW
`define CSR_TLBELO0_G       csr_TLBELO0[6]   //RW
//                          csr_TLBELO0[7]   = 0
`define CSR_TLBELO0_PPN     csr_TLBELO0[27:8]//RW   [PALEN-5:8]
//                          csr_TLBELO0[31:28]= 0   [31:PALEN-4]
`define CSR_TLBELO1         14'h13
`define CSR_TLBELO1_V       csr_TLBELO1[0]   //RW
`define CSR_TLBELO1_D       csr_TLBELO1[1]   //RW
`define CSR_TLBELO1_PLV     csr_TLBELO1[3:2] //RW
`define CSR_TLBELO1_MAT     csr_TLBELO1[5:4] //RW
`define CSR_TLBELO1_G       csr_TLBELO1[6]   //RW
//                          csr_TLBELO1[7]   = 0
`define CSR_TLBELO1_PPN     csr_TLBELO1[27:8]//RW   [PALEN-5:8]
//                          csr_TLBELO1[31:28]= 0   [31:PALEN-4]

`define CSR_ASID            14'h18
`define CSR_ASID_ASID       csr_ASID[9:0]    //RW
//                          csr_ASID[15:10]  = 0
`define CSR_ASID_ASIDBITS   csr_ASID[23:16]  //R
//                          csr_ASID[31:24]  = 0

`define CSR_PGDL            14'h19
//                          csr_PGDL[11:0]   = 0
`define CSR_PGDL_BASE       csr_PGDL[31:12]  //RW

`define CSR_PGDH            14'h1a
//                          csr_PGDH[11:0]   = 0
`define CSR_PGDH_BASE       csr_PGDH[31:12]  //RW

`define CSR_PGD             14'h1b
//                          csr_PGD[11:0]    = 0
`define CSR_PGD_BASE        csr_PGD[31:12]   //RW

`define CSR_CPUID           14'h20
`define CSR_CPUID_COREID    csr_CPUID[8:0]   //R
//                          csr_CPUID[31:9]  = 0

`define CSR_SAVE0           14'h30
`define CSR_SAVE0_DATA      csr_SAVE0[31:0]  //RW
`define CSR_SAVE1           14'h31
`define CSR_SAVE1_DATA      csr_SAVE1[31:0]  //RW
`define CSR_SAVE2           14'h32
`define CSR_SAVE2_DATA      csr_SAVE2[31:0]  //RW
`define CSR_SAVE3           14'h33
`define CSR_SAVE3_DATA      csr_SAVE3[31:0]  //RW

`define CSR_TID             14'h40
`define CSR_TID_TID         csr_TID[31:0]    //RW

`define CSR_TCFG            14'h41
`define CSR_TCFG_EN         csr_TCFG[0]      //RW
`define CSR_TCFG_PERIODIC   csr_TCFG[1]      //RW
`define CSR_TCFG_INITVAL    csr_TCFG[31:2]   //RW

`define CSR_TVAL            14'h42
`define CSR_TVAL_TIMEVAL    csr_TVAL[31:0]   //RW

`define CSR_CNTC            14'h43
`define CSR_CNTC_CNTC       csr_CNTC[31:0]   //RW

`define CSR_TICLR           14'h44
`define CSR_TICLR_CLR       csr_TICLR[0]     //W1  read 0
//                          csr_TICLR[31:1]  = 0

`define CSR_LLBCTL          14'h60
`define CSR_LLBCTL_ROLLB    csr_LLBCTL[0]    //R
`define CSR_LLBCTL_WCLLB    csr_LLBCTL[1]    //W1
`define CSR_LLBCTL_KLO      csr_LLBCTL[2]    //RW
//                          csr_LLBCTL[31:3] = 0

`define CSR_TLBRENTRY       14'h88
//                          csr_TLBRENTRY[5:0]  = 0
`define CSR_TLBRENTRY_PA    csr_TLBRENTRY[31:6] //RW

`define CSR_CTAG            14'h98
`define CSR_CTAG_CTAG       csr_CTAG[31:0]   //RW

`define CSR_DMW0            14'h180
`define CSR_DMW0_PLV0       csr_DMW0[0]      //RW
//                          csr_DMW0[2:1]    = 0
`define CSR_DMW0_PLV3       csr_DMW0[3]      //RW
`define CSR_DMW0_MAT        csr_DMW0[5:4]    //RW
//                          csr_DMW0[24:6]   = 0
`define CSR_DMW0_PSEG       csr_DMW0[27:25]  //RW
//                          csr_DMW0[28]     = 0
`define CSR_DMW0_VSEG       csr_DMW0[31:29]  //RW
`define CSR_DMW1            14'h181
`define CSR_DMW1_PLV0       csr_DMW1[0]      //RW
//                          csr_DMW1[2:1]    = 0
`define CSR_DMW1_PLV3       csr_DMW1[3]      //RW
`define CSR_DMW1_MAT        csr_DMW1[5:4]    //RW
//                          csr_DMW1[24:6]   = 0
`define CSR_DMW1_PSEG       csr_DMW1[27:25]  //RW
//                          csr_DMW1[28]     = 0
`define CSR_DMW1_VSEG       csr_DMW1[31:29]  //RW
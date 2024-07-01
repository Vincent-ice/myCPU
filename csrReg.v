`include "Defines.vh"
module csrReg (
    input                       clk,
    input                       rstn,

    input  [13:0]               csr_addr,
    input                       csr_re,
    input                       csr_we,
    input  [31:0]               csr_wmask, 
    input  [31:0]               csr_wdata,
    output [31:0]               csr_rdata,

    input                       ex_en,
    input  [ 5:0]               ecode,
    input                       esubcode,
    input  [31:0]               pc,
    input  [31:0]               vaddr,

    output [31:0]               new_pc,
    output [31:0]               ex_entryPC
);
    
//csr register
reg [31:0] csr_CRMD;    //0x00
reg [31:0] csr_PRMD;    //0x01
reg [31:0] csr_EUEN;    //0x02
reg [31:0] csr_ECFG;    //0x04
reg [31:0] csr_ESTAT;   //0x05
reg [31:0] csr_ERA;     //0x06
reg [31:0] csr_BADV;    //0x07
reg [31:0] csr_EENTRY;  //0x0c
reg [31:0] csr_TLBIDX;  //0x10
reg [31:0] csr_TLBEHI;  //0x11
reg [31:0] csr_TLBELO0; //0x12
reg [31:0] csr_TLBELO1; //0x13
reg [31:0] csr_ASID;    //0x18
reg [31:0] csr_PGDL;    //0x19
reg [31:0] csr_PGDH;    //0x1a
reg [31:0] csr_PGD;     //0x1b
reg [31:0] csr_CPUID;   //0x20
reg [31:0] csr_SAVE0;   //0x30
reg [31:0] csr_SAVE1;   //0x31
reg [31:0] csr_SAVE2;   //0x32
reg [31:0] csr_SAVE3;   //0x33
reg [31:0] csr_TID;     //0x40
reg [31:0] csr_TCFG;    //0x41
reg [31:0] csr_TVAL;    //0x42
reg [31:0] csr_TICLR;   //0x44
reg [31:0] csr_LLBCTL;  //0x60
reg [31:0] csr_TLBRENTRY;//0x88
reg [31:0] csr_CTAG;    //0x98
reg [31:0] csr_DMW0;    //0x180
reg [31:0] csr_DMW1;    //0x181

`define CSR_CRMD_PLV        csr_CRMD[1:0]    //RW
`define CSR_CRMD_IE         csr_CRMD[2]      //RW
`define CSR_CRMD_DA         csr_CRMD[3]      //RW
`define CSR_CRMD_PG         csr_CRMD[4]      //RW
`define CSR_CRMD_DATF       csr_CRMD[6:5]    //RW
`define CSR_CRMD_DATM       csr_CRMD[8:7]    //RW
//                          csr_CRMD[31:9]   = 0

`define CSR_PRMD_PPLV       csr_PRMD[1:0]    //RW
`define CSR_PRMD_PIE        csr_PRMD[2]      //RW
//                          csr_PRMD[31:3]   = 0

`define CSR_EUEN_FPE        csr_EUEN[0]      //RW
//                          csr_EUEN[31:1]   = 0

`define CSR_ECFG_LIE_9_0    csr_ECFG[9:0]    //RW
//                          csr_ECFG[10]     = 0
`define CSR_ECFG_LIE_12_11  csr_ECFG[12:11]  //RW
//                          csr_ECFG[31:13]  = 0

`define CSR_ESTAT_IS_1_0    csr_ESTAT[1:0]   //RW
`define CSR_ESTAT_IS_9_2    csr_ESTAT[9:2]   //R
//                          csr_ESTAT[10]    = 0
`define CSR_ESTAT_IS_11     csr_ESTAT[11]    //R
`define CSR_ESTAT_IS_12     csr_ESTAT[12]    //R
//                          csr_ESTAT[15:13] = 0
`define CSR_ESTAT_ECODE     csr_ESTAT[21:16] //R
`define CSR_ESTAT_ESUBCODE  csr_ESTAT[30:22] //R
//                          csr_ESTAT[31]    = 0

`define CSR_ERA_PC          csr_ERA[31:0]    //RW

`define CSR_BADV_VADDR      csr_BADV[31:0]   //RW

//                          csr_EENTRY[ 5:0] = 0
`define CSR_EENTRY_VA       csr_EENTRY[31:6] //RW

`define CSR_TLBIDX_INDEX    csr_TLBIDX[15:0] //RW
//                          csr_TLBIDX[23:16]= 0
`define CSR_TLBIDX_PS       csr_TLBIDX[29:24]//RW
//                          csr_TLBIDX[30]   = 0
`define CSR_TLBIDX_NE       csr_TLBIDX[31]   //RW

//                          csr_TLBEHI[12:0] = 0
`define CSR_TLBEHI_VPPN     csr_TLBEHI[31:13]//RW

`define CSR_TLBELO0_V       csr_TLBELO0[0]   //RW
`define CSR_TLBELO0_D       csr_TLBELO0[1]   //RW
`define CSR_TLBELO0_PLV     csr_TLBELO0[3:2] //RW
`define CSR_TLBELO0_MAT     csr_TLBELO0[5:4] //RW
`define CSR_TLBELO0_G       csr_TLBELO0[6]   //RW
//                          csr_TLBELO0[7]   = 0
`define CSR_TLBELO0_PPN     csr_TLBELO0[27:8]//RW   [PALEN-5:8]
//                          csr_TLBELO0[31:28]= 0   [31:PALEN-4]
`define CSR_TLBELO1_V       csr_TLBELO1[0]   //RW
`define CSR_TLBELO1_D       csr_TLBELO1[1]   //RW
`define CSR_TLBELO1_PLV     csr_TLBELO1[3:2] //RW
`define CSR_TLBELO1_MAT     csr_TLBELO1[5:4] //RW
`define CSR_TLBELO1_G       csr_TLBELO1[6]   //RW
//                          csr_TLBELO1[7]   = 0
`define CSR_TLBELO1_PPN     csr_TLBELO1[27:8]//RW   [PALEN-5:8]
//                          csr_TLBELO1[31:28]= 0   [31:PALEN-4]

`define CSR_ASID_ASID       csr_ASID[9:0]    //RW
//                          csr_ASID[15:10]  = 0
`define CSR_ASID_ASIDBITS   csr_ASID[23:16]  //RW
//                          csr_ASID[31:24]  = 0

//                          csr_PGDL[11:0]   = 0
`define CSR_PGDL_BASE       csr_PGDL[31:12]  //RW

//                          csr_PGDH[11:0]   = 0
`define CSR_PGDH_BASE       csr_PGDH[31:12]  //RW

//                          csr_PGD[11:0]    = 0
`define CSR_PGD_BASE        csr_PGD[31:12]   //RW

`define CSR_CPUID_COREID    csr_CPUID[8:0]   //R
//                          csr_CPUID[31:9]  = 0

`define CSR_SAVE0_DATA      csr_SAVE0[31:0]  //RW
`define CSR_SAVE1_DATA      csr_SAVE1[31:0]  //RW
`define CSR_SAVE2_DATA      csr_SAVE2[31:0]  //RW
`define CSR_SAVE3_DATA      csr_SAVE3[31:0]  //RW

`define CSR_TID_TID         csr_TID[31:0]    //RW

`define CSR_TCFG_EN         csr_TCFG[0]      //RW
`define CSR_TCFG_PERIODIC   csr_TCFG[1]      //RW
`define CSR_TCFG_INITVAL    csr_TCFG[31:2]   //RW

`define CSR_TVAL_TIMEVAL    csr_TVAL[31:0]   //RW

`define CSR_TICLR_CLR       csr_TICLR[0]     //W1  read 0
//                          csr_TICLR[31:1]  = 0

`define CSR_LLBCTL_ROLLB    csr_LLBCTL[0]    //R
`define CSR_LLBCTL_WCLLB    csr_LLBCTL[1]    //W1
`define CSR_LLBCTL_KLO      csr_LLBCTL[2]    //RW
//                          csr_LLBCTL[31:3] = 0

//                          csr_TLBRENTRY[5:0]  = 0
`define CSR_TLBRENTRY_PA    csr_TLBRENTRY[31:6] //RW

`define CSR_CTAG            csr_CTAG[31:0]   //RW

`define CSR_DMW0_PLV0       csr_DMW0[0]      //RW
//                          csr_DMW0[2:1]    = 0
`define CSR_DMW0_PLV3       csr_DMW0[3]      //RW
`define CSR_DMW0_MAT        csr_DMW0[5:4]    //RW
//                          csr_DMW0[24:6]   = 0
`define CSR_DMW0_PSEG       csr_DMW0[27:25]  //RW
//                          csr_DMW0[28]     = 0
`define CSR_DMW0_VSEG       csr_DMW0[31:29]  //RW

`define CSR_DMW1_PLV0       csr_DMW1[0]      //RW
//                          csr_DMW1[2:1]    = 0
`define CSR_DMW1_PLV3       csr_DMW1[3]      //RW
`define CSR_DMW1_MAT        csr_DMW1[5:4]    //RW
//                          csr_DMW1[24:6]   = 0
`define CSR_DMW1_PSEG       csr_DMW1[27:25]  //RW
//                          csr_DMW1[28]     = 0
`define CSR_DMW1_VSEG       csr_DMW1[31:29]  //RW

//initial
always @(posedge clk ) begin
    if (!rstn) begin
        csr_CRMD     <= 32'h0000_0004;
        csr_PRMD     <= 32'h0;
        csr_EUEN     <= 32'h0;
        csr_ECFG     <= 32'h0;
        csr_ESTAT    <= 32'h0;
        csr_ERA      <= 32'h0;
        csr_BADV     <= 32'h0;
        csr_EENTRY   <= 32'h0;
        csr_TLBIDX   <= 32'h0;
        csr_TLBEHI   <= 32'h0;
        csr_TLBELO0  <= 32'h0;
        csr_TLBELO1  <= 32'h0;
        csr_ASID     <= 32'h0;
        csr_PGDL     <= 32'h0;
        csr_PGDH     <= 32'h0;
        csr_PGD      <= 32'h0;
        csr_CPUID    <= 32'h0;
        csr_SAVE0    <= 32'h0;
        csr_SAVE1    <= 32'h0;
        csr_SAVE2    <= 32'h0;
        csr_SAVE3    <= 32'h0;
        csr_TID      <= 32'h0;
        csr_TCFG     <= 32'h0;
        csr_TVAL     <= 32'h0;
        csr_TICLR    <= 32'h0;
        csr_LLBCTL   <= 32'h0;
        csr_TLBRENTRY<= 32'h0;
        csr_CTAG     <= 32'h0;
        csr_DMW0     <= 32'h0;
        csr_DMW1     <= 32'h0;
    end
end

//csrrd, csrwr, csrxchg
assign csr_rdata = csr_addr == 14'h0  ? csr_CRMD      :
                   csr_addr == 14'h1  ? csr_PRMD      :
                   csr_addr == 14'h2  ? csr_EUEN      :
                   csr_addr == 14'h4  ? csr_ECFG      :
                   csr_addr == 14'h5  ? csr_ESTAT     :
                   csr_addr == 14'h6  ? csr_ERA       :
                   csr_addr == 14'h7  ? csr_BADV      :
                   csr_addr == 14'hC  ? csr_EENTRY    :
                   csr_addr == 14'h10 ? csr_TLBIDX    :
                   csr_addr == 14'h11 ? csr_TLBEHI    :
                   csr_addr == 14'h12 ? csr_TLBELO0   :
                   csr_addr == 14'h13 ? csr_TLBELO1   :
                   csr_addr == 14'h18 ? csr_ASID      :
                   csr_addr == 14'h19 ? csr_PGDL      :
                   csr_addr == 14'h1A ? csr_PGDH      :
                   csr_addr == 14'h1B ? csr_PGD       :
                   csr_addr == 14'h20 ? csr_CPUID     :
                   csr_addr == 14'h30 ? csr_SAVE0     :
                   csr_addr == 14'h31 ? csr_SAVE1     :
                   csr_addr == 14'h32 ? csr_SAVE2     :
                   csr_addr == 14'h33 ? csr_SAVE3     :
                   csr_addr == 14'h40 ? csr_TID       :
                   csr_addr == 14'h41 ? csr_TCFG      :
                   csr_addr == 14'h42 ? csr_TVAL      :
                   csr_addr == 14'h44 ? csr_TICLR     :
                   csr_addr == 14'h60 ? csr_LLBCTL    :
                   csr_addr == 14'h88 ? csr_TLBRENTRY :
                   csr_addr == 14'h98 ? csr_CTAG      :
                   csr_addr == 14'h180 ? csr_DMW0     :
                   csr_addr == 14'h181 ? csr_DMW1     : 32'h0;

always @(posedge clk) begin
    if (csr_we) begin
        case (csr_addr)
            14'h0  : csr_CRMD     <= csr_wdata & csr_wmask & 32'h0000_01ff;
            14'h1  : csr_PRMD     <= csr_wdata & csr_wmask & 32'h0000_0007;
            14'h2  : csr_EUEN     <= csr_wdata & csr_wmask & 32'h0000_0001;
            14'h4  : csr_ECFG     <= csr_wdata & csr_wmask & 32'h0000_1bff;
            14'h5  : csr_ESTAT    <= csr_wdata & csr_wmask & 32'h0000_0003;
            14'h6  : csr_ERA      <= csr_wdata & csr_wmask ;
            14'h7  : csr_BADV     <= csr_wdata & csr_wmask ;
            14'hC  : csr_EENTRY   <= csr_wdata & csr_wmask & 32'hffff_ffe0;
            14'h10 : csr_TLBIDX   <= csr_wdata & csr_wmask & 32'hbf00_ffff;
            14'h11 : csr_TLBEHI   <= csr_wdata & csr_wmask & 32'hffff_1fff;
            14'h12 : csr_TLBELO0  <= csr_wdata & csr_wmask & 32'h0fff_ff7f;
            14'h13 : csr_TLBELO1  <= csr_wdata & csr_wmask & 32'h0fff_ff7f;
            14'h18 : csr_ASID     <= csr_wdata & csr_wmask & 32'h00ff_03ff;
            14'h19 : csr_PGDL     <= csr_wdata & csr_wmask & 32'hffff_f000;
            14'h1A : csr_PGDH     <= csr_wdata & csr_wmask & 32'hffff_f000;
            14'h1B : csr_PGD      <= csr_wdata & csr_wmask & 32'hffff_f000;
            14'h30 : csr_SAVE0    <= csr_wdata & csr_wmask ;
            14'h31 : csr_SAVE1    <= csr_wdata & csr_wmask ;
            14'h32 : csr_SAVE2    <= csr_wdata & csr_wmask ;
            14'h33 : csr_SAVE3    <= csr_wdata & csr_wmask ;
            14'h40 : csr_TID      <= csr_wdata & csr_wmask ;
            14'h41 : csr_TCFG     <= csr_wdata & csr_wmask ;
            14'h44 : csr_TICLR    <= csr_wdata & csr_wmask & 32'h0000_0001;
            14'h60 : csr_LLBCTL   <= csr_wdata & csr_wmask & 32'h0000_0004;
            14'h88 : csr_TLBRENTRY<= csr_wdata & csr_wmask & 32'hffff_ffe0;
            14'h98 : csr_CTAG     <= csr_wdata & csr_wmask ;
            14'h180: csr_DMW0     <= csr_wdata & csr_wmask & 32'hee00_0039;
            14'h181: csr_DMW1     <= csr_wdata & csr_wmask & 32'hee00_0039;
            default: ;          
        endcase
    end
end

//CRMD
always @(posedge clk ) begin
    if (ex_en) begin
        `CSR_CRMD_PLV <= 2'b0;
        `CSR_CRMD_IE  <= 1'b0;
    end
end

always @(posedge clk ) begin
    if (ecode == `ECODE_ERTN) begin
        `CSR_CRMD_PLV <= `CSR_PRMD_PPLV;
        `CSR_CRMD_IE  <= `CSR_PRMD_PIE;
        `CSR_CRMD_DA  <= `CSR_ESTAT_ECODE != 6'h3f;
        `CSR_CRMD_PG  <= `CSR_ESTAT_ECODE == 6'h3f;
    end
end

//PRMD
always @(posedge clk ) begin
    if (ex_en) begin
        `CSR_PRMD_PPLV <= `CSR_CRMD_PLV;
        `CSR_PRMD_PIE  <= `CSR_CRMD_IE;
    end
end

//ESTAT
always @(posedge clk ) begin
    if (ex_en) begin
        `CSR_ESTAT_ECODE    <= ecode;
        `CSR_ESTAT_ESUBCODE <= {8'b0,esubcode};
    end
end

//ERA
always @(posedge clk ) begin
    if (ex_en) begin
        `CSR_ERA_PC <= pc;
    end
end

//BADV
always @(posedge clk ) begin
    if (ex_en) begin
        `CSR_BADV_VADDR <= (ecode == `ECODE_ADEF) && (esubcode == `ESUBCODE_ADEF) ? pc : vaddr;
    end
end

//EENTRY
assign ex_entryPC = csr_EENTRY;

//LLBCTL
reg LLbit;
always @(posedge clk ) begin
    if (csr_addr == 14'h60 && csr_wmask[1] && csr_wdata[1] && csr_we) begin
        LLbit <= 1'b0;
    end
    `CSR_LLBCTL_ROLLB <= LLbit;
    if (!`CSR_LLBCTL_KLO) begin
        LLbit <= 1'b0;
    end
end
endmodule
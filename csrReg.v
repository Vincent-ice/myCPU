`include "Defines.vh"
`include "csrReg.vh"
module csrReg (
    input                       clk,
    input                       rstn,

    input  [13:0]               csr_raddr,
    input                       csr_re,
    input                       csr_we,
    input  [13:0]               csr_waddr,
    input  [31:0]               csr_wmask, 
    input  [31:0]               csr_wdata,
    output [31:0]               csr_rdata,

    input  [13:0]               csr_raddr_forward,
    output [31:0]               csr_rdata_forward,

    input                       ex_en,
    input  [ 7:0]               ecode,
    input                       esubcode,
    input  [31:0]               pc,
    input  [31:0]               vaddr,

    input  [ 7:0]               hardware_interrupt,
    output                      has_int,
    output [ 7:0]               int_ecode,

    output [31:0]               new_pc,
    output [31:0]               ex_entryPC,

    output [63:0]               counter,
    output [31:0]               counterID
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
reg [31:0] csr_CNTC;    //0x43
reg [31:0] csr_TICLR;   //0x44
reg [31:0] csr_LLBCTL;  //0x60
reg [31:0] csr_TLBRENTRY;//0x88
reg [31:0] csr_CTAG;    //0x98
reg [31:0] csr_DMW0;    //0x180
reg [31:0] csr_DMW1;    //0x181

wire CRMD_we   = csr_we & (csr_waddr == `CSR_CRMD);
wire PRMD_we   = csr_we & (csr_waddr == `CSR_PRMD);
wire EUEN_we   = csr_we & (csr_waddr == `CSR_EUEN);
wire ECFG_we   = csr_we & (csr_waddr == `CSR_ECFG);
wire ESTAT_we  = csr_we & (csr_waddr == `CSR_ESTAT);
wire ERA_we    = csr_we & (csr_waddr == `CSR_ERA);
wire BADV_we   = csr_we & (csr_waddr == `CSR_BADV);
wire EENTRY_we = csr_we & (csr_waddr == `CSR_EENTRY);
wire TLBIDX_we = csr_we & (csr_waddr == `CSR_TLBIDX);
wire TLBEHI_we = csr_we & (csr_waddr == `CSR_TLBEHI);
wire TLBELO0_we= csr_we & (csr_waddr == `CSR_TLBELO0);
wire TLBELO1_we= csr_we & (csr_waddr == `CSR_TLBELO1);
wire ASID_we   = csr_we & (csr_waddr == `CSR_ASID);
wire pGDL_we   = csr_we & (csr_waddr == `CSR_PGDL);
wire PGDH_we   = csr_we & (csr_waddr == `CSR_PGDH);
wire PGD_we    = csr_we & (csr_waddr == `CSR_PGD);
wire CPUID_we  = csr_we & (csr_waddr == `CSR_CPUID);
wire SAVE0_we  = csr_we & (csr_waddr == `CSR_SAVE0);
wire SAVE1_we  = csr_we & (csr_waddr == `CSR_SAVE1);
wire SAVE2_we  = csr_we & (csr_waddr == `CSR_SAVE2);
wire SAVE3_we  = csr_we & (csr_waddr == `CSR_SAVE3);
wire TID_we    = csr_we & (csr_waddr == `CSR_TID);
wire TCFG_we   = csr_we & (csr_waddr == `CSR_TCFG);
wire TVAL_we   = csr_we & (csr_waddr == `CSR_TVAL);
wire CNTC_we   = csr_we & (csr_waddr == `CSR_CNTC);
wire TICLR_we  = csr_we & (csr_waddr == `CSR_TICLR);
wire LLBCTL_we = csr_we & (csr_waddr == `CSR_LLBCTL);
wire TLBRENTRY_we = csr_we & (csr_waddr == `CSR_TLBRENTRY);
wire CTAG_we   = csr_we & (csr_waddr == `CSR_CTAG);
wire DMW0_we   = csr_we & (csr_waddr == `CSR_DMW0);
wire DMW1_we   = csr_we & (csr_waddr == `CSR_DMW1);

reg  timer_en;

reg  LLbit;

//inturrupt
wire [12:0] int = csr_ECFG[12:0] & csr_ESTAT[12:0] & {13{`CSR_CRMD_IE}};
assign has_int = |int;
assign int_ecode = int[12] ? 8'd76 :
                   int[11] ? 8'd75 :
                   int[10] ? 8'd74 :
                   int[ 9] ? 8'd73 :
                   int[ 8] ? 8'd72 :
                   int[ 7] ? 8'd71 :
                   int[ 6] ? 8'd70 :
                   int[ 5] ? 8'd69 :
                   int[ 4] ? 8'd68 :
                   int[ 3] ? 8'd67 :
                   int[ 2] ? 8'd66 :
                   int[ 1] ? 8'd65 :
                   int[ 0] ? 8'd64 : 8'd0;

//CSR rdata
assign csr_rdata = csr_raddr == `CSR_CRMD      ? csr_CRMD      :
                   csr_raddr == `CSR_PRMD      ? csr_PRMD      :
                   csr_raddr == `CSR_EUEN      ? csr_EUEN      :
                   csr_raddr == `CSR_ECFG      ? csr_ECFG      :
                   csr_raddr == `CSR_ESTAT     ? csr_ESTAT     :
                   csr_raddr == `CSR_ERA       ? csr_ERA       :
                   csr_raddr == `CSR_BADV      ? csr_BADV      :
                   csr_raddr == `CSR_EENTRY    ? csr_EENTRY    :
                   csr_raddr == `CSR_TLBIDX    ? csr_TLBIDX    :
                   csr_raddr == `CSR_TLBEHI    ? csr_TLBEHI    :
                   csr_raddr == `CSR_TLBELO0   ? csr_TLBELO0   :
                   csr_raddr == `CSR_TLBELO1   ? csr_TLBELO1   :
                   csr_raddr == `CSR_ASID      ? csr_ASID      :
                   csr_raddr == `CSR_PGDL      ? csr_PGDL      :
                   csr_raddr == `CSR_PGDH      ? csr_PGDH      :
                   csr_raddr == `CSR_PGD       ? csr_PGD       :
                   csr_raddr == `CSR_CPUID     ? csr_CPUID     :
                   csr_raddr == `CSR_SAVE0     ? csr_SAVE0     :
                   csr_raddr == `CSR_SAVE1     ? csr_SAVE1     :
                   csr_raddr == `CSR_SAVE2     ? csr_SAVE2     :
                   csr_raddr == `CSR_SAVE3     ? csr_SAVE3     :
                   csr_raddr == `CSR_TID       ? csr_TID       :
                   csr_raddr == `CSR_TCFG      ? csr_TCFG      :
                   csr_raddr == `CSR_TVAL      ? csr_TVAL      :
                   csr_raddr == `CSR_TICLR     ? 32'h0     :
                   csr_raddr == `CSR_LLBCTL    ? {csr_LLBCTL[31:1],LLbit} :
                   csr_raddr == `CSR_TLBRENTRY ? csr_TLBRENTRY :
                   csr_raddr == `CSR_CTAG      ? csr_CTAG      :
                   csr_raddr == `CSR_DMW0      ? csr_DMW0      :
                   csr_raddr == `CSR_DMW1      ? csr_DMW1      : 32'b0;

assign csr_rdata_forward = csr_raddr_forward == `CSR_CRMD      ? csr_CRMD      :
                           csr_raddr_forward == `CSR_PRMD      ? csr_PRMD      :
                           csr_raddr_forward == `CSR_EUEN      ? csr_EUEN      :
                           csr_raddr_forward == `CSR_ECFG      ? csr_ECFG      :
                           csr_raddr_forward == `CSR_ESTAT     ? csr_ESTAT     :
                           csr_raddr_forward == `CSR_ERA       ? csr_ERA       :
                           csr_raddr_forward == `CSR_BADV      ? csr_BADV      :
                           csr_raddr_forward == `CSR_EENTRY    ? csr_EENTRY    :
                           csr_raddr_forward == `CSR_TLBIDX    ? csr_TLBIDX    :
                           csr_raddr_forward == `CSR_TLBEHI    ? csr_TLBEHI    :
                           csr_raddr_forward == `CSR_TLBELO0   ? csr_TLBELO0   :
                           csr_raddr_forward == `CSR_TLBELO1   ? csr_TLBELO1   :
                           csr_raddr_forward == `CSR_ASID      ? csr_ASID      :
                           csr_raddr_forward == `CSR_PGDL      ? csr_PGDL      :
                           csr_raddr_forward == `CSR_PGDH      ? csr_PGDH      :
                           csr_raddr_forward == `CSR_PGD       ? csr_PGD       :
                           csr_raddr_forward == `CSR_CPUID     ? csr_CPUID     :
                           csr_raddr_forward == `CSR_SAVE0     ? csr_SAVE0     :
                           csr_raddr_forward == `CSR_SAVE1     ? csr_SAVE1     :
                           csr_raddr_forward == `CSR_SAVE2     ? csr_SAVE2     :
                           csr_raddr_forward == `CSR_SAVE3     ? csr_SAVE3     :
                           csr_raddr_forward == `CSR_TID       ? csr_TID       :
                           csr_raddr_forward == `CSR_TCFG      ? csr_TCFG      :
                           csr_raddr_forward == `CSR_TVAL      ? csr_TVAL      :
                           csr_raddr_forward == `CSR_TICLR     ? 32'h0     :
                           csr_raddr_forward == `CSR_LLBCTL    ? {csr_LLBCTL[31:1],LLbit} :
                           csr_raddr_forward == `CSR_TLBRENTRY ? csr_TLBRENTRY :
                           csr_raddr_forward == `CSR_CTAG      ? csr_CTAG      :
                           csr_raddr_forward == `CSR_DMW0      ? csr_DMW0      :
                           csr_raddr_forward == `CSR_DMW1      ? csr_DMW1      : 32'b0;

//CRMD
always @(posedge clk ) begin
    if (!rstn) begin
        csr_CRMD     <= 32'h0000_0008;  //DA=1
    end
    else if (ex_en) begin
        `CSR_CRMD_PLV <=  2'b0;
        `CSR_CRMD_IE  <=  1'b0;
    end
    else if (ecode == `ECODE_ERTN) begin
        `CSR_CRMD_PLV <= `CSR_PRMD_PPLV;
        `CSR_CRMD_IE  <= `CSR_PRMD_PIE ;
    end 
    else if (CRMD_we) begin
        csr_CRMD[8:0] <= csr_wdata[8:0] & csr_wmask[8:0] | ~csr_wmask[8:0] & csr_CRMD[8:0];
    end
end

//PRMD
always @(posedge clk ) begin
    if (!rstn) begin
        csr_PRMD <= 32'b0;
    end
    else if (ex_en) begin
        `CSR_PRMD_PPLV <= `CSR_CRMD_PLV;
        `CSR_PRMD_PIE  <= `CSR_CRMD_IE ;
    end
    else if (PRMD_we) begin
        csr_PRMD[2:0] <= csr_wdata[2:0] & csr_wmask[2:0] | ~csr_wmask[2:0] & csr_PRMD[2:0];
    end
end

//EUEN
always @(posedge clk ) begin
    if (!rstn) begin
        csr_EUEN <= 32'b0;
    end
    else if (EUEN_we) begin
        csr_EUEN[0] <= csr_wdata[0] & csr_wmask[0] | ~csr_wmask[0] & csr_EUEN[0];
    end
end

//ECFG
always @(posedge clk ) begin
    if (!rstn) begin
        csr_ECFG <= 32'b0;
    end
    else if (ECFG_we) begin
        csr_ECFG[12:0] <= csr_wdata[12:0] & csr_wmask[12:0] | ~csr_wmask[12:0] & csr_ECFG[12:0];
    end
end

//ESTAT
always @(posedge clk ) begin
    if (!rstn) begin
        csr_ESTAT <= 32'b0;
        timer_en  <= 1'b0;
    end
    else begin
        //timer interrupt
        if (TICLR_we && csr_wdata[0]) begin
            csr_ESTAT[11] <= 1'b0;
        end
        else if (TCFG_we) begin
            timer_en <= csr_wdata[0];
        end
        else if (timer_en && !(|csr_TVAL)) begin
            csr_ESTAT[11] <= 1'b1;
            timer_en      <= `CSR_TCFG_PERIODIC;
        end

        if (ex_en) begin
            `CSR_ESTAT_ECODE    <= ecode   ;
            `CSR_ESTAT_ESUBCODE <= esubcode;
        end
        else if (ESTAT_we) begin
            csr_ESTAT[1:0] <= csr_wdata[1:0] & csr_wmask[1:0] | ~csr_wmask[1:0] & csr_ESTAT[1:0];
        end

        `CSR_ESTAT_IS_9_2 <= hardware_interrupt;
    end
end

//ERA
always @(posedge clk ) begin
    if (ex_en) begin
        csr_ERA <= pc;
    end
    else if (ERA_we) begin
        csr_ERA <= csr_wdata;
    end
end
assign new_pc = (`CSR_ESTAT_ECODE == `ECODE_SYS ||
                 `CSR_ESTAT_ECODE == `ECODE_BRK ||
                 `CSR_ESTAT_ECODE == `ECODE_INE)    ? csr_ERA + 32'd4 : csr_ERA;

//BADV
wire va_error = (ecode == `ECODE_ADEM) || (ecode == `ECODE_ALE) ||
                (ecode == `ECODE_PIL ) || (ecode == `ECODE_PIS) ||
                (ecode == `ECODE_PIF ) || (ecode == `ECODE_PME) ||
                (ecode == `ECODE_PPI );
always @(posedge clk ) begin
    if (BADV_we) begin
        csr_BADV <= csr_wdata;
    end
    else if ((ecode == `ECODE_ADEF) && (esubcode == `ESUBCODE_ADEF)) begin
        csr_BADV <= pc;
    end
    else if (va_error) begin
        csr_BADV <= vaddr;
    end
end

//EENTRY
always @(posedge clk ) begin
    if (!rstn) begin
        csr_EENTRY <= 32'b0;
    end
    else if (EENTRY_we) begin
        csr_EENTRY[31:6] <= csr_wdata[31:6] & csr_wmask[31:6] | ~csr_wmask[31:6] & csr_EENTRY[31:6];
    end
end
assign ex_entryPC = csr_EENTRY;

//CPUID
always @(posedge clk) begin
    if (!rstn) begin
        csr_CPUID <= 32'b0;
    end 
end

//SAVE0
always @(posedge clk ) begin
    if (SAVE0_we) begin
        csr_SAVE0 <= csr_wdata;
    end 
end

//SAVE1
always @(posedge clk ) begin
    if (SAVE1_we) begin
        csr_SAVE1 <= csr_wdata;
    end 
end

//SAVE2
always @(posedge clk ) begin
    if (SAVE2_we) begin
        csr_SAVE2 <= csr_wdata;
    end 
end

//SAVE3
always @(posedge clk ) begin
    if (SAVE3_we) begin
        csr_SAVE3 <= csr_wdata;
    end 
end

//TID
always @(posedge clk ) begin
    if (!rstn) begin
        csr_TID <= csr_CPUID;
    end
    else if (TID_we) begin
        csr_TID <= csr_wdata;
    end
end

//TCFG
always @(posedge clk ) begin
    if (!rstn) begin
        csr_TCFG <= 32'b0;
    end
    else if (TCFG_we) begin
        csr_TCFG <= csr_wdata & csr_wmask | ~csr_wmask & csr_TCFG;
    end
end

//CTAG
always @(posedge clk ) begin
    if (!rstn) begin
        csr_CTAG <= 32'b0;
    end
    else if (CTAG_we) begin
        csr_CTAG <= csr_wdata;
    end
end

//TVAL
always @(posedge clk ) begin
    if (TCFG_we) begin
        csr_TVAL <= {csr_wdata[31:2], 2'b0};
    end
    else if (timer_en) begin
        if (|csr_TVAL) begin
            csr_TVAL <= csr_TVAL - 32'b1;
        end
        else if (!(|csr_TVAL)) begin
            csr_TVAL <= `CSR_TCFG_PERIODIC ? {`CSR_TCFG_INITVAL, 2'b0} : 32'hffffffff;
        end
    end
end

//TICLR
always @(posedge clk ) begin
    if (!rstn) begin
        csr_TICLR <= 32'b0;
    end
end

//LLBCTL
always @(posedge clk ) begin
    if (!rstn) begin
        csr_LLBCTL[31:1] <= 31'b0;
        LLbit <= 1'b0;
    end 
    else if (ecode == `ECODE_ERTN) begin
        if (`CSR_LLBCTL_KLO) begin
            `CSR_LLBCTL_KLO <= 1'b0;
        end
        else begin
            LLbit <= 1'b0;
        end
    end
    else if (LLBCTL_we) begin 
        csr_LLBCTL[2] <= csr_wdata[2] & csr_wmask[2] | ~csr_wmask[2] & csr_LLBCTL[2];
        if (csr_wdata[1] == 1'b1) begin
            LLbit <= 1'b0;
        end
    end
end

//counter
reg [31:0] timerID;
reg [63:0] timer_64;
always @(posedge clk ) begin
    if (!rstn) begin
        timer_64 <= 64'b0;
        timerID  <= 32'b0;
    end
    else begin
        timer_64 <= timer_64 + 1'b1;
    end
end
assign counter = timer_64 + {{32{csr_CNTC[31]}}, csr_CNTC};
assign counterID = timerID;

//CNTC
always @(posedge clk) begin
    if (!rstn) begin
        csr_CNTC <= 32'b0;
    end
    else if (CNTC_we) begin
        csr_CNTC <= csr_wdata & csr_wmask | ~csr_wmask & csr_CNTC;
    end
end

endmodule
`include "Defines.vh"
module Fetch (
    input                           clk,
    input                           rstn,

    input    [`Branch_BUS_Wid-1:0]  Branch_BUS,
    input                           ex_en,
    input    [31:0]                 ex_entryPC,
    input                           ertn_flush,
    input    [31:0]                 new_pc,

    input                           D_allowin,  

    output                          FD_valid,
    output   [`FD_BUS_Wid-1:0]      FD_BUS,

    output                          inst_sram_en,
    output   [3:0]                  inst_sram_we,
    output   [31:0]                 inst_sram_addr,inst_sram_wdata,

    input  [`CSR2F_BUS_Wid-1:0] CSR2F_BUS,
    output [              18:0] s0_vppn,
    output                      s0_va_bit12,
    output [               9:0] s0_asid,
    input                       s0_found,
    input  [$clog2(`TLBNUM)-1:0]s0_index,
    input  [              19:0] s0_ppn,
    input  [               5:0] s0_ps,
    input  [               1:0] s0_plv,
    input  [               1:0] s0_mat,
    input                       s0_d,
    input                       s0_v
);

//Branch bus
wire br_taken;
wire [31:0] br_target;
assign {br_taken,br_target} = Branch_BUS;

//pipeline handshake
wire ex_F;
reg  F_valid;
reg  ex_flag;
wire F_valid_next   = rstn;//next cycle valid
wire F_ready_go     = 1'b1;//ready send to next stage
wire F_allowin      = !F_valid || ex_en || F_ready_go && D_allowin && !ex_F;//allow input data
assign FD_valid     = F_valid_next && F_ready_go;//validity of D stage
always @(posedge clk) begin
    if (!rstn) begin
        F_valid <= 1'b0;
    end
    else if (F_allowin) begin
        F_valid <= F_valid_next;
    end
end

always @(posedge clk) begin
    if (!rstn) begin
        ex_flag <= 1'b0;
    end 
    else if (ex_F) begin
        ex_flag <= 1'b1;
    end
    else if (ex_en) begin
        ex_flag <= 1'b0;
    end
end

//PC
reg  [31:0] pc_reg;
wire [31:0] pc_next;
wire        pc_en;
wire [31:0] pc_plus4 = pc_reg + 32'd4;

assign pc_en = F_valid_next && F_allowin;
assign pc_next = br_taken   ? (F_valid ? br_target : pc_plus4) : 
                 ex_en      ? ex_entryPC                       :
                 ertn_flush ? new_pc                           : pc_plus4;

always @(posedge clk) begin
    if(!rstn)begin
        pc_reg <= 32'h1bff_fffc;
    end else if (F_valid_next && F_allowin) begin
        pc_reg <= pc_next;
    end
end

//address translation
wire [ 9:0] csr_ASID_ASID;
wire        csr_CRMD_DA;
wire        csr_CRMD_PG;
wire [ 1:0] csr_CRMD_PLV;
wire        csr_DMW0_PLV0;
wire        csr_DMW0_PLV3;
wire [ 2:0] csr_DMW0_VSEG;
wire        csr_DMW1_PLV0;
wire        csr_DMW1_PLV3;
wire [ 2:0] csr_DMW1_VSEG;
assign {csr_ASID_ASID,csr_CRMD_DA,csr_CRMD_PG,csr_CRMD_PLV,
        csr_DMW0_PLV0,csr_DMW0_PLV3,csr_DMW0_VSEG,
        csr_DMW1_PLV0,csr_DMW1_PLV3,csr_DMW1_VSEG} = CSR2F_BUS;

wire        da_hit;
wire        dmw0_hit;
wire        dmw1_hit;
wire        dmw_hit = dmw0_hit || dmw1_hit;
//TLB
wire [31:0] vaddr = pc_next;
wire [31:0] paddr;

wire [19:0] vpn = vaddr[31:12];
wire [21:0] offset = vaddr[21:0];

assign s0_vppn = vpn[19:1];
assign s0_va_bit12 = vpn[0];
assign s0_asid = csr_ASID_ASID;

assign tlb_addr = (s0_ps == 6'd12) ? {s0_ppn[19:0], offset[11:0]} :
                                     {s0_ppn[19:10], offset[21:0]};


assign da_hit = (csr_CRMD_DA == 1) && (csr_CRMD_PG == 0);

// DMW
assign dmw0_hit = (csr_CRMD_PLV == 2'b00 && csr_DMW0_PLV0   ||
                   csr_CRMD_PLV == 2'b11 && csr_DMW0_PLV3 ) && (vaddr[31:29] == csr_DMW0_VSEG); 
assign dmw1_hit = (csr_CRMD_PLV == 2'b00 && csr_DMW1_PLV0   ||
                   csr_CRMD_PLV == 2'b11 && csr_DMW1_PLV3 ) && (vaddr[31:29] == csr_DMW1_VSEG); 

assign dmw_addr = {32{dmw0_hit}} & {csr_DMW0_VSEG, vaddr[28:0]} |
                  {32{dmw1_hit}} & {csr_DMW1_VSEG, vaddr[28:0]};

// PADDR
assign paddr = da_hit  ? vaddr    :
               dmw_hit ? dmw_addr :
                         tlb_addr;

//exception manage
wire        ex_ADEF    = |pc_next[1:0] && F_valid_next;
wire        ex_TLBR    = ~da_hit & ~dmw_hit & ~s0_found;
wire        ex_PIF     = ~da_hit & ~dmw_hit & s0_found & ~s0_v;
wire        ex_PPI     = ~da_hit & ~dmw_hit & (csr_CRMD_PLV > s0_plv);

assign      ex_F       = ex_ADEF || ex_TLBR || ex_PIF || ex_PPI;
wire [ 7:0] ecode_F    = ex_ADEF ? `ECODE_ADEF :
                         ex_TLBR ? `ECODE_TLBR :
                         ex_PIF  ? `ECODE_PIF  :
                         ex_PPI  ? `ECODE_PPI  : 8'h00;
wire        esubcode_F = `ESUBCODE_ADEF;

//inst sram manage
assign inst_sram_en    = pc_en ; 
assign inst_sram_addr  = paddr ;
assign inst_sram_we    = 4'b0  ;
assign inst_sram_wdata = 32'b0 ;

//FD BUS
assign FD_BUS = {inst_sram_addr,pc_en,ex_F,ecode_F,esubcode_F};
endmodule
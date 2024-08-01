`include "Defines.vh"
module Fetch (
    input                           clk,
    input                           rstn,

    input    [`predict_BUS_Wid-1:0] predict_BUS,
    input                           predict_error,
    input    [`Branch_BUS_Wid-1:0]  Branch_BUS,

    input                           ex_D,
    input                           ex_E, 
    input                           ex_en_i,
    input    [31:0]                 ex_entryPC,
    input                           ertn_flush_i,
    input    [31:0]                 new_pc,
    input                           TLBR_en_i,
    input    [31:0]                 TLBR_entryPC,

    input                           pD_allowin,

    output                          FpD_valid,
    output   [`FpD_BUS_Wid-1:0]     FpD_BUS,

    output                          inst_sram_req,
    output                          inst_sram_wr,
    output   [1:0]                  inst_sram_size,
    output   [3:0]                  inst_sram_wstrb,
    output   [31:0]                 inst_sram_addr,
    input                           inst_sram_addr_ok,
    input                           inst_sram_data_ok,
    output   [31:0]                 inst_sram_wdata,
    input    [31:0]                 inst_sram_rdata,

    input  [`CSR2FE_BUS_Wid-1:0] CSR2FE_BUS,
    output [               18:0] s0_vppn,
    output                       s0_va_bit12,
    output [                9:0] s0_asid,
    input                        s0_found,
    input  [$clog2(`TLBNUM)-1:0] s0_index,
    input  [               19:0] s0_ppn,
    input  [                5:0] s0_ps,
    input  [                1:0] s0_plv,
    input  [                1:0] s0_mat,
    input                        s0_d,
    input                        s0_v
);

//Branch bus
wire br_taken_i;
wire [31:0] br_target_i;
assign {br_taken_i,br_target_i} = Branch_BUS;

wire        predict_taken  = predict_BUS[32];
wire [31:0] predict_target = predict_BUS[31:0];

//pipeline handshake
reg  [31:0] pc_reg;
reg  [31:0] pc_next;
wire        pc_en;
wire [31:0] pc_plus4 = pc_reg + 32'd4;
reg  ex_F;
reg  has_ex;
reg  ex_en;
reg  ertn_flush;
reg  TLBR_en;
wire br_taken = br_taken_i | predict_taken;
reg  [31:0] br_target;
reg  br_taken_buff;
reg  [31:0] br_target_buff;
reg  send_handshake;
reg  F_valid;
wire F_valid_next   = rstn & inst_sram_req & inst_sram_addr_ok;//next cycle valid
wire F_ready_go;//ready send to next stage
reg  F_ready_go_buff;
always @(posedge clk) begin
    if (!rstn) begin
        F_ready_go_buff <= 1'b0;
    end
    else if (inst_sram_data_ok & !has_ex) begin
        F_ready_go_buff <= 1'b1;
    end
    else if (inst_sram_addr_ok & inst_sram_req || has_ex || ertn_flush) begin
        F_ready_go_buff <= 1'b0;
    end
end
assign F_ready_go = F_ready_go_buff | (inst_sram_data_ok & !has_ex);
wire F_allowin      = !F_valid || ex_en || F_ready_go && pD_allowin && !ex_F;//allow input data
assign FpD_valid     = F_valid_next & F_ready_go & !br_taken_buff & !br_taken && !ertn_flush || (ex_F & !ex_en);//validity of D stage
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
        send_handshake <= 1'b0;
    end
    else if(inst_sram_data_ok) begin
        send_handshake <= 1'b0;
    end
    else if(inst_sram_addr_ok & inst_sram_req) begin
        send_handshake <= 1'b1;
    end
end

//branch buff
always @(*) begin
    case (1'b1)
        br_taken_i : br_target = br_target_i;
        predict_taken : br_target = predict_target;
        default    : br_target = 32'b0;
    endcase
end
always @(posedge clk) begin
    if (!rstn) begin
        br_taken_buff <= 1'b0;
        br_target_buff <= 32'b0;
    end
    else if (!br_taken_buff & predict_taken | br_taken) begin
        br_taken_buff <= 1'b1;
        case (1'b1)
            br_taken : br_target_buff <= br_target;
            predict_taken : br_target_buff <= predict_target;
            default    : br_target_buff <= 32'b0;
        endcase
    end
    else if (F_valid_next & F_allowin || ex_en) begin
        br_taken_buff <= 1'b0;
    end
end

//has_ex buff
always @(posedge clk) begin
    if (!rstn) begin
        has_ex <= 1'b0;
    end
    else if (ex_D | ex_E) begin
        has_ex <= 1'b1;
    end
    else if (inst_sram_addr_ok & inst_sram_req & ex_en | predict_error) begin
        has_ex <= 1'b0;
    end
end

//ex_en & TLBR buff
always @(posedge clk) begin
    if (!rstn) begin
        ex_en <= 1'b0;
    end
    else if (ex_en_i) begin
        ex_en <= 1'b1;
        TLBR_en <= TLBR_en_i;
    end
    else if (F_valid_next & F_allowin) begin
        ex_en <= 1'b0;
        TLBR_en <= 1'b0;
    end
end

//ertn_flush buff
always @(posedge clk) begin
    if (!rstn) begin
        ertn_flush <= 1'b0;
    end
    else if (ertn_flush_i) begin
        ertn_flush <= 1'b1;
    end
    else if (F_valid_next & F_allowin) begin
        ertn_flush <= 1'b0;
    end
end

//PC
assign pc_en   = F_allowin && !ex_F && !send_handshake;
always @(*) begin
    case (1'b1)
        TLBR_en & has_ex: pc_next = TLBR_entryPC;
        ex_en & has_ex: pc_next = ex_entryPC;
        br_taken_buff : pc_next = br_target_buff;
        br_taken      : pc_next = br_target;
        has_ex        : pc_next = ex_entryPC;
        ertn_flush    : pc_next = new_pc;
        default       : pc_next = pc_plus4;
    endcase
end
/* assign pc_next = br_taken   ? br_target                        :
                 br_taken_D   ? br_target_D                        : 
                 ex_en        ? ex_entryPC                         :
                 predict_taken? predict_target                     :
                 ertn_flush   ? new_pc                             : pc_plus4; */

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
wire [ 2:0] csr_DMW0_PSEG;
wire        csr_DMW1_PLV0;
wire        csr_DMW1_PLV3;
wire [ 2:0] csr_DMW1_VSEG;
wire [ 2:0] csr_DMW1_PSEG;
assign {csr_ASID_ASID,csr_CRMD_DA,csr_CRMD_PG,csr_CRMD_PLV,
        csr_DMW0_PLV0,csr_DMW0_PLV3,csr_DMW0_VSEG,csr_DMW0_PSEG,
        csr_DMW1_PLV0,csr_DMW1_PLV3,csr_DMW1_VSEG,csr_DMW1_PSEG} = CSR2FE_BUS;

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

wire [31:0] tlb_addr = (s0_ps == 6'd12) ? {s0_ppn[19:0], offset[11:0]} :
                                          {s0_ppn[19:10], offset[21:0]};


assign da_hit = (csr_CRMD_DA == 1) && (csr_CRMD_PG == 0);

// DMW
assign dmw0_hit = (csr_CRMD_PLV == 2'b00 && csr_DMW0_PLV0   ||
                   csr_CRMD_PLV == 2'b11 && csr_DMW0_PLV3 ) && (vaddr[31:29] == csr_DMW0_VSEG); 
assign dmw1_hit = (csr_CRMD_PLV == 2'b00 && csr_DMW1_PLV0   ||
                   csr_CRMD_PLV == 2'b11 && csr_DMW1_PLV3 ) && (vaddr[31:29] == csr_DMW1_VSEG); 

wire [31:0] dmw_addr = {32{dmw0_hit}} & {csr_DMW0_PSEG, vaddr[28:0]} |
                       {32{dmw1_hit}} & {csr_DMW1_PSEG, vaddr[28:0]};

// PADDR
assign paddr = da_hit  ? vaddr    :
               dmw_hit ? dmw_addr :
                         tlb_addr ;

//exception manage
wire        ex_ADEF    = |pc_next[1:0];
wire        ex_TLBR    = ~da_hit & ~dmw_hit & ~s0_found;
wire        ex_PIF     = ~da_hit & ~dmw_hit & s0_found & ~s0_v;
wire        ex_PPI     = ~da_hit & ~dmw_hit & (csr_CRMD_PLV > s0_plv);
reg  [ 7:0] ecode_F;
reg         esubcode_F;
always @(posedge clk) begin
    if (!predict_error && F_valid_next && F_allowin) begin
        ex_F    <= (ex_ADEF || ex_TLBR || ex_PIF || ex_PPI);
        ecode_F <= ex_ADEF ? `ECODE_ADEF :
               ex_TLBR ? `ECODE_TLBR :
               ex_PIF  ? `ECODE_PIF  :
               ex_PPI  ? `ECODE_PPI  : 8'h00;
        esubcode_F <= `ESUBCODE_ADEF;
    end
    else begin
        ex_F <= 1'b0;
        ecode_F <= 8'h00;
        esubcode_F <= 1'b0;
    end
end

//inst sram manage
reg  [31:0] inst_sram_rdata_buff;
assign inst_sram_req   = pc_en;
assign inst_sram_wr    = 1'b0;
assign inst_sram_size  = 2'b10;
assign inst_sram_wstrb = 4'b0;
assign inst_sram_addr  = paddr; 
assign inst_sram_wdata = 32'b0 ;
always @(posedge clk) begin
    if (!rstn) begin
        inst_sram_rdata_buff <= 32'b0;
    end
    else if (inst_sram_data_ok) begin
        inst_sram_rdata_buff <= inst_sram_rdata;
    end
end

//FD BUS
assign FpD_BUS = {pc_reg,       //74:43
                 inst_sram_rdata_buff,//42:11
                 pc_en,         //10
                 ex_F & !predict_error,//9
                 ecode_F,       //8:1
                 esubcode_F};   //0


endmodule
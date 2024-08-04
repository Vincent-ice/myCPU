`include "Defines.vh"
module Decode (
    input                           clk,
    input                           rstn,

    input                           pDD_valid,
    input [`pDD_BUS_Wid-1:0]        pDD_BUS,

    input [ 7:0]                    hardware_interrupt,
    
    input                           E_allowin,
    output                          D_allowin,

    input [`ED_for_BUS_Wid-1:0]     ED_for_BUS,
    input [`MD_for_BUS_Wid-1:0]     MD_for_BUS,
    input [`Wrf_BUS_Wid-1:0]        Wrf_BUS,
    input [`Wcsr_BUS_Wid-1:0]       Wcsr_BUS,

    output                          DE_valid,
    output [`DE_BUS_Wid-1:0]        DE_BUS,

    input  [13:0]                   csr_raddr_forward,
    output [31:0]                   csr_rdata_forward,

    input                           predict_error,
    output                          ex_D,
    output                          ex_en,
    output [31:0]                   ex_entryPC,
    output                          ertn_flush,
    output [31:0]                   new_pc,
    output                          TLBR_en,
    output [31:0]                   TLBR_entryPC,

    input  [`TLB2CSR_BUS_WD_Wid-1:0]TLB2CSR_BUS_W,
    output [`CSR2TLB_BUS_DE_Wid-1:0]CSR2TLB_BUS_D,
    output [`CSR2FE_BUS_Wid-1:0]    CSR2FE_BUS
);

//pDD BUS
reg  [`pDD_BUS_Wid-1:0] pDD_BUS_D;
wire [31:0] pc_D;
wire [31:0] inst_D;
wire        pc_en_D;
wire        ex_pD;
wire [ 7:0] ecode_pD;
wire        esubcode_pD;
wire [63:0] op_31_26_d;
wire        inst_jirl;
wire        inst_b;
wire        inst_bl;
wire        inst_beq;
wire        inst_bne;
wire        inst_blt;
wire        inst_bge;
wire        inst_bltu;
wire        inst_bgeu;
wire        predict_taken;
wire [31:0] predict_target;

assign {pc_D,inst_D,pc_en_D,ex_pD,ecode_pD,esubcode_pD,op_31_26_d,
        inst_jirl,inst_b,inst_bl,inst_beq,inst_bne,inst_blt,inst_bge,inst_bltu,inst_bgeu,
        predict_taken,predict_target} = pDD_BUS_D;

//pipeline handshake
reg  D_valid;
reg  ex_flag;
wire load_stall;
wire forward_stall;
wire D_ready_go    = D_valid & !load_stall & !forward_stall;
(*max_fanout = 20*)assign D_allowin   = !D_valid || D_ready_go && E_allowin;
(*max_fanout = 20*)assign DE_valid    = D_valid && D_ready_go;
always @(posedge clk) begin
    if (!rstn) begin
        pDD_BUS_D <= 'b0;
    end
    else if (ex_en) begin
        pDD_BUS_D <= 'b0;
    end
    else if (pDD_valid && D_allowin) begin
        pDD_BUS_D <= pDD_BUS;
    end
end
always @(posedge clk) begin
    if (!rstn) begin
        D_valid <= 1'b0;
    end
    else if (ex_en) begin
        D_valid <= 1'b0;
    end
    else if (D_allowin) begin
        D_valid <= pDD_valid && (!ex_flag && !ex_D) && !predict_error;
    end
end

//inst decode
wire [ 3:0] op_25_22 = inst_D[25:22];
wire [ 1:0] op_21_20 = inst_D[21:20];
wire [ 4:0] op_19_15 = inst_D[19:15];
wire [ 4:0] op_14_10 = inst_D[14:10];

wire [ 4:0] rd = inst_D[ 4: 0];
wire [ 4:0] rj = inst_D[ 9: 5];
wire [ 4:0] rk = inst_D[14:10];

wire [11:0] i12 = inst_D[21:10];
wire [19:0] i20 = inst_D[24: 5];
wire [15:0] i16 = inst_D[25:10];
wire [25:0] i26 = {inst_D[ 9: 0], inst_D[25:10]};

wire [4:0]  invop = inst_D[4:0];

wire [15:0] op_25_22_d;
wire [ 3:0] op_21_20_d;
wire [31:0] op_19_15_d;
wire [31:0] op_14_10_d;

decoder_4_16 u_dec1(.in(op_25_22 ), .out(op_25_22_d ));
decoder_2_4  u_dec2(.in(op_21_20 ), .out(op_21_20_d ));
decoder_5_32 u_dec3(.in(op_19_15 ), .out(op_19_15_d ));
decoder_5_32 u_dec4(.in(op_14_10 ), .out(op_14_10_d ));
 
wire inst_add_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h00];
wire inst_sub_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h02];
wire inst_slt    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h04];
wire inst_sltu   = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h05];
wire inst_nor    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h08];
wire inst_and    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h09];
wire inst_or     = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0a];
wire inst_xor    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0b];
wire inst_sll_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0e]; 
wire inst_srl_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0f]; 
wire inst_sra_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h10];
wire inst_mul_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h18];
wire inst_mulh_w = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h19];
wire inst_mulh_wu= op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h1a];
wire inst_div_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h00];
wire inst_mod_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h01];
wire inst_div_wu = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h02];
wire inst_mod_wu = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h03];
wire inst_slli_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h01];
wire inst_srli_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h09];
wire inst_srai_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h11];
wire inst_slti   = op_31_26_d[6'h00] & op_25_22_d[4'h8];
wire inst_sltui  = op_31_26_d[6'h00] & op_25_22_d[4'h9];
wire inst_addi_w = op_31_26_d[6'h00] & op_25_22_d[4'ha];
wire inst_andi   = op_31_26_d[6'h00] & op_25_22_d[4'hd]; 
wire inst_ori    = op_31_26_d[6'h00] & op_25_22_d[4'he]; 
wire inst_xori   = op_31_26_d[6'h00] & op_25_22_d[4'hf]; 
wire inst_pcaddu12i= op_31_26_d[6'h7] & ~inst_D[25];

wire inst_ld_b   = op_31_26_d[6'h0a] & op_25_22_d[4'h0];
wire inst_ld_h   = op_31_26_d[6'h0a] & op_25_22_d[4'h1];
wire inst_ld_bu  = op_31_26_d[6'h0a] & op_25_22_d[4'h8];
wire inst_ld_hu  = op_31_26_d[6'h0a] & op_25_22_d[4'h9];
wire inst_ld_w   = op_31_26_d[6'h0a] & op_25_22_d[4'h2];
wire inst_st_b   = op_31_26_d[6'h0a] & op_25_22_d[4'h4];
wire inst_st_h   = op_31_26_d[6'h0a] & op_25_22_d[4'h5];
wire inst_st_w   = op_31_26_d[6'h0a] & op_25_22_d[4'h6];
wire inst_lu12i_w= op_31_26_d[6'h05] & ~inst_D[25];

wire inst_csrrd  = op_31_26_d[6'h01] && ~inst_D[25] && ~inst_D[24] && (rj==5'b00); 
wire inst_csrwr  = op_31_26_d[6'h01] && ~inst_D[25] && ~inst_D[24] && (rj==5'b01); 
wire inst_csrxchg= op_31_26_d[6'h01] & ~inst_D[25] & ~inst_D[24] & ~inst_csrrd & ~inst_csrwr; 
wire inst_ertn   = op_31_26_d[6'h01] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h10] & op_14_10_d[5'h0e] && (rj==5'b00) && (rd==5'b00); 
wire inst_break  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h14];
wire inst_syscall= op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h16]; 

wire inst_rdcntid   = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h0] & op_19_15_d[5'h00] & op_14_10_d[5'h18] & (rd==5'b00);
wire inst_rdcntvl_w = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h0] & op_19_15_d[5'h00] & op_14_10_d[5'h18] & (rj==5'b00);
wire inst_rdcntvh_w = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h0] & op_19_15_d[5'h00] & op_14_10_d[5'h19] & (rj==5'b00);

wire inst_tlbsrch = op_31_26_d[6'h01] && op_25_22_d[4'h9] && op_21_20_d[2'h0] && op_19_15_d[5'h10] && op_14_10_d[5'h0a] && (rj==5'b00) && (rd==5'b00);
wire inst_tlbrd   = op_31_26_d[6'h01] && op_25_22_d[4'h9] && op_21_20_d[2'h0] && op_19_15_d[5'h10] && op_14_10_d[5'h0b] && (rj==5'b00) && (rd==5'b00);
wire inst_tlbwr   = op_31_26_d[6'h01] && op_25_22_d[4'h9] && op_21_20_d[2'h0] && op_19_15_d[5'h10] && op_14_10_d[5'h0c] && (rj==5'b00) && (rd==5'b00);
wire inst_tlbfill = op_31_26_d[6'h01] && op_25_22_d[4'h9] && op_21_20_d[2'h0] && op_19_15_d[5'h10] && op_14_10_d[5'h0d] && (rj==5'b00) && (rd==5'b00);
wire inst_invtlb  = op_31_26_d[6'h01] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h13] & (invop==5'h00 | invop==5'h01 | invop==5'h02 | invop==5'h03 | invop==5'h04 | invop==5'h05 | invop==5'h06);

wire inst_cacop   = op_31_26_d[6'h01] & op_25_22_d[4'h8];
/* don't forget add the inst to the wire 'unknownInst' at last */

//alu_op manage
wire [`alu_op_Wid-1:0] alu_op;

assign alu_op[ 0] = inst_add_w | inst_addi_w | inst_ld_b | inst_ld_bu | inst_ld_h | inst_ld_hu | inst_ld_w | 
                    inst_st_b | inst_st_h | inst_st_w | 
                    inst_jirl | inst_bl | inst_pcaddu12i | inst_rdcntid | inst_rdcntvl_w | inst_rdcntvh_w;
assign alu_op[ 1] = inst_sub_w | inst_beq | inst_bne;
assign alu_op[ 2] = inst_slt | inst_slti | inst_blt | inst_bge;
assign alu_op[ 3] = inst_sltu | inst_sltui | inst_bltu | inst_bgeu;
assign alu_op[ 4] = inst_and | inst_andi;
assign alu_op[ 5] = inst_nor;
assign alu_op[ 6] = inst_or | inst_ori;
assign alu_op[ 7] = inst_xor | inst_xori;
assign alu_op[ 8] = inst_slli_w | inst_sll_w;
assign alu_op[ 9] = inst_srli_w | inst_srl_w;
assign alu_op[10] = inst_srai_w | inst_sra_w;
assign alu_op[11] = inst_lu12i_w;
assign alu_op[12] = inst_mul_w;
assign alu_op[13] = inst_mulh_w;
assign alu_op[14] = inst_mulh_wu;
assign alu_op[15] = inst_div_w;
assign alu_op[16] = inst_mod_w;
assign alu_op[17] = inst_div_wu;
assign alu_op[18] = inst_mod_wu;

//dataflow control manage
wire need_ui5   =  inst_slli_w | inst_srli_w | inst_srai_w;
wire need_si12  =  inst_addi_w | inst_ld_w | inst_st_w | inst_slti | inst_sltui |
                   inst_ld_b | inst_ld_h | inst_ld_bu | inst_ld_hu | inst_st_b | inst_st_h;
wire need_si12u =  inst_andi | inst_ori | inst_xori;
wire need_si16  =  inst_jirl | inst_beq | inst_bne | inst_blt | inst_bge | inst_bltu | inst_bgeu;
wire need_si20  =  inst_lu12i_w | inst_pcaddu12i;
wire need_si26  =  inst_b | inst_bl;
wire src2_is_4  =  inst_jirl | inst_bl;


reg  [31:0] imm;
always @(*) begin
    case (1'b1)
        src2_is_4 : imm = 32'h4;
        need_si20 : imm = {i20[19:0], 12'b0};
        need_si12u: imm = {20'b0, i12[11:0]};
        need_si16 : imm = {{14{i16[15]}}, i16, 2'b0};
        default   : imm = {{20{i12[11]}}, i12[11:0]}; //need_ui5 || need_si12
    endcase
end

wire   src_reg_is_rd = inst_beq | inst_bne | inst_blt | inst_bge | inst_bltu | 
                       inst_bgeu | inst_st_w | inst_st_b | inst_st_h| 
                       inst_csrrd | inst_csrwr | inst_csrxchg;
wire   src1_is_pc    = inst_jirl | inst_bl | inst_pcaddu12i;
wire   src2_is_imm   = inst_slli_w |
                       inst_srli_w |
                       inst_srai_w |
                       inst_addi_w |
                       inst_ld_b   |
                       inst_ld_bu  |
                       inst_ld_h   |
                       inst_ld_hu  |
                       inst_ld_w   |
                       inst_st_b   |
                       inst_st_h   |
                       inst_st_w   |
                       inst_lu12i_w|
                       inst_jirl   |
                       inst_bl     |
                       inst_pcaddu12i|
                       inst_slti   |
                       inst_sltui  |
                       inst_andi   |
                       inst_ori    |
                       inst_xori   ;
wire [3:0] res_from_mem  = inst_ld_w  ? 4'b1111 :
                           inst_ld_b  ? 4'b0001 :
                           inst_ld_bu ? 4'b0101 :
                           inst_ld_h  ? 4'b0011 :
                           inst_ld_hu ? 4'b0111 : 4'b0000;
wire       res_from_csr  = inst_csrrd | inst_csrwr | inst_csrxchg;
wire       dst_is_r1     = inst_bl;
wire       gr_we         = ~inst_st_w & ~inst_st_b & ~inst_st_h & ~inst_beq  & ~inst_bne & ~inst_b & D_valid & 
                           ~inst_ertn & ~inst_blt  & ~inst_bge  & ~inst_bltu & ~inst_bgeu& ~inst_break & ~inst_syscall & 
                           ~inst_tlbsrch & ~inst_tlbrd & ~inst_tlbwr & ~inst_tlbfill & ~inst_invtlb & ~inst_cacop;
wire [3:0] mem_we        = inst_st_w ? 4'b1111 :
                           inst_st_b ? 4'b0001 :
                           inst_st_h ? 4'b0011 : 4'b0000;
wire [4:0] dest          = dst_is_r1    ? 5'd1 : 
                           inst_rdcntid ? rj   : rd;

//regfile data manage
wire [ 4:0] rf_raddr1 = rj;
wire [ 4:0] rf_raddr2 = src_reg_is_rd ? rd :rk;
wire        rf_raddr1_neq0 = rf_raddr1 != 5'b0;
wire        rf_raddr2_neq0 = rf_raddr2 != 5'b0;
wire [31:0] rf_rdata1;
wire [31:0] rf_rdata2;
wire        rf_we;
wire [ 4:0] rf_waddr;
wire [31:0] rf_wdata;

assign {rf_we,rf_waddr,rf_wdata} = Wrf_BUS;

regfile u_regfile(
    .clk    (clk      ),
    .raddr1 (rf_raddr1),
    .rdata1 (rf_rdata1),
    .raddr2 (rf_raddr2),
    .rdata2 (rf_rdata2),
    .we     (rf_we    ),
    .waddr  (rf_waddr ),
    .wdata  (rf_wdata )
    );

    //forward manage
wire [ 3:0] res_from_mem_E;
wire [ 4:0] dest_E;
wire [ 4:0] dest_M;
wire [31:0] rf_wdata_E;
wire [31:0] rf_wdata_M;
wire        csr_we_E;
wire        csr_we_M;
wire [13:0] csr_addr_E;
wire [13:0] csr_addr_M;
wire [31:0] csr_wmask_E;
wire [31:0] csr_wmask_M;
wire [31:0] csr_wdata_E;
wire [31:0] csr_wdata_M;

assign {res_from_mem_E,dest_E,rf_wdata_E,csr_we_E,csr_addr_E,csr_wmask_E,csr_wdata_E} = ED_for_BUS;
assign {dest_M,rf_wdata_M,csr_we_M,csr_addr_M,csr_wmask_M,csr_wdata_M} = MD_for_BUS;

assign load_stall = |res_from_mem_E && !ex_en &&
                    ((rf_raddr1 == dest_E) && (rf_raddr1_neq0) || (rf_raddr2 == dest_E) && (rf_raddr2_neq0)) &&
                    ((rf_raddr1 != dest_M) || (rf_raddr2 != dest_M));

wire        rf_raddr1_eq_dest_E = (rf_raddr1 == dest_E) && (rf_raddr1_neq0) && !res_from_mem_E;
wire        rf_raddr2_eq_dest_E = (rf_raddr2 == dest_E) && (rf_raddr2_neq0) && !res_from_mem_E;
wire        rf_raddr1_eq_dest_M = (rf_raddr1 == dest_M) && (rf_raddr1_neq0);
wire        rf_raddr2_eq_dest_M = (rf_raddr2 == dest_M) && (rf_raddr2_neq0);
wire        rf_raddr1_eq_rf_waddr = (rf_raddr1 == rf_waddr) && (rf_raddr1_neq0) && rf_we;
wire        rf_raddr2_eq_rf_waddr = (rf_raddr2 == rf_waddr) && (rf_raddr2_neq0) && rf_we;
reg  [31:0] rj_value;
reg  [31:0] rkd_value;

always @(*) begin
    case (1'b1)
/*         rf_raddr1_eq_dest_E  : rj_value = rf_wdata_E; */
        rf_raddr1_eq_dest_M  : rj_value = rf_wdata_M;
        rf_raddr1_eq_rf_waddr: rj_value = rf_wdata;
        default              : rj_value = rf_rdata1;
    endcase
end

always @(*) begin
    case (1'b1)
/*         rf_raddr2_eq_dest_E  : rkd_value = rf_wdata_E; */
        rf_raddr2_eq_dest_M  : rkd_value = rf_wdata_M;
        rf_raddr2_eq_rf_waddr: rkd_value = rf_wdata;
        default              : rkd_value = rf_rdata2;
    endcase
end

assign forward_stall = rf_raddr1_eq_dest_E | rf_raddr2_eq_dest_E;

//CSR data manage
wire [13:0] csr_addr     = inst_ertn ? 14'h06 :
                           inst_rdcntid ? 14'h40 : inst_D[23:10];
wire        csr_we       = inst_csrwr | inst_csrxchg;
wire        csr_re       = inst_csrrd | inst_csrwr | inst_csrxchg;
wire [31:0] csr_wmask    = {32{inst_csrxchg}} & rj_value | {32{~inst_csrxchg}};
wire [31:0] csr_wdata    = rkd_value;
wire [31:0] csr_rdata;
wire [`CSR2TLB_BUS_Wid-1:0] CSR2TLB_BUS;
wire        csr_we_W;
wire [13:0] csr_addr_W;
wire [31:0] csr_wmask_W;
wire [31:0] csr_wdata_W;
wire        ex_en_W;
wire [ 7:0] ecode_W;
wire        esubcode_W;
wire [31:0] pc_W;
wire [31:0] era_pc;
wire [31:0] vaddr_W;
wire        has_int;
wire [ 7:0] int_ecode;
wire [63:0] counter;
wire [31:0] counterID;
wire [63:0] counter_shift;
assign {ex_en_W,ecode_W,esubcode_W,csr_we_W,csr_addr_W,csr_wmask_W,csr_wdata_W,pc_W,vaddr_W} = Wcsr_BUS;
assign ertn_flush = inst_ertn && D_valid;
assign ex_en      = ex_en_W;

csrReg u_csrReg(
    .clk       (clk       ),
    .rstn      (rstn      ),
    .csr_raddr (csr_addr  ),
    .csr_re    (csr_re    ),
    .csr_we    (csr_we_W  ),
    .csr_waddr (csr_addr_W),
    .csr_wmask (csr_wmask_W),
    .csr_wdata (csr_wdata_W),
    .csr_rdata (csr_rdata ),
    .csr_raddr_forward (csr_raddr_forward),
    .csr_rdata_forward (csr_rdata_forward),
    .ex_en     (ex_en_W   ),
    .ecode     (ecode_W   ),
    .esubcode  (esubcode_W),
    .pc        (pc_W      ),
    .vaddr     (vaddr_W   ),
    .ertn_flush(ertn_flush),
    .hardware_interrupt(hardware_interrupt),
    .has_int   (has_int   ),
    .int_ecode (int_ecode ),
    .new_pc    (era_pc    ),
    .ex_entryPC(ex_entryPC),
    .TLBR_entryPC(TLBR_entryPC),
    .counter   (counter   ),
    .counterID (counterID ),
    .counter_shift(counter_shift),
    .CSR2TLB_BUS(CSR2TLB_BUS),
    .TLB2CSR_BUS(TLB2CSR_BUS_W),
    .CSR2FE_BUS(CSR2FE_BUS)
);
assign TLBR_en = ex_en_W && (ecode_W == `ECODE_TLBR);
assign CSR2TLB_BUS_D = {inst_tlbsrch,inst_tlbrd,inst_tlbwr,inst_tlbfill,inst_invtlb,invop,CSR2TLB_BUS};

/* !! TLB CSR2TLB may get old csr data due to inst_csrwr haven't written back */

    //forward manage
wire        csr_forward_E = csr_we_E && (&(csr_addr_E ^ (~csr_addr)));
wire        csr_forward_M = csr_we_M && (&(csr_addr_M ^ (~csr_addr)));
wire        csr_forward_W = csr_we_W && (&(csr_addr_W ^ (~csr_addr)));
reg  [31:0] csr_value;
always @(*) begin
    case (1'b1)
        csr_forward_E : csr_value = csr_wdata_E;
        csr_forward_M : csr_value = csr_wdata_M;
        csr_forward_W : csr_value = csr_wdata_W;
        default       : csr_value = csr_rdata;
endcase
end

assign new_pc = csr_value;

//branch manage
wire [31:0] br_base;
wire [31:0] br_offs;
wire        b_inst = inst_beq | inst_bne | inst_blt | inst_bge |
                     inst_bltu | inst_bgeu | inst_b | inst_bl;
wire [31:0] b_offs;
wire [31:0] jirl_offs;

assign b_offs = need_si26 ? {{ 4{i26[25]}}, i26[25:0], 2'b0} :
                             {{14{i16[15]}}, i16[15:0], 2'b0} ; 
assign jirl_offs = {{14{i16[15]}}, i16[15:0], 2'b0};

assign br_base = b_inst                          ? pc_D       :
                 inst_jirl                       ? rj_value   :
                                                    32'b0;
assign br_offs = b_inst                          ? b_offs     :
                 inst_jirl                       ? jirl_offs  :
                                                    32'b0;

//alu data input manage
reg  [31:0] alu_src1;
reg  [31:0] alu_src2;
always @(*) begin
    case (1'b1)
        src1_is_pc     : alu_src1 = pc_D[31:0];
        inst_rdcntid   : alu_src1 = csr_value;
        inst_rdcntvl_w : alu_src1 = counter[31:0];
        inst_rdcntvh_w : alu_src1 = counter[63:32];
        default        : alu_src1 = rj_value;
    endcase
end
always @(*) begin
    case (1'b1)
        src2_is_imm    : alu_src2 = imm;
        inst_rdcntid   : alu_src2 = 32'b0;
        inst_rdcntvl_w : alu_src2 = 32'b0;
        inst_rdcntvh_w : alu_src2 = 32'b0;
        default        : alu_src2 = rkd_value;
    endcase
end

//exception manage
wire       unknownInst = !{|{inst_add_w,inst_sub_w,inst_slt,inst_sltu,inst_nor,inst_and,inst_or,inst_xor,
                             inst_sll_w,inst_srl_w,inst_sra_w,inst_mul_w,inst_mulh_w,inst_mulh_wu,inst_div_w,
                             inst_mod_w,inst_div_wu,inst_mod_wu,inst_slli_w,inst_srli_w,inst_srai_w,inst_slti,
                             inst_sltui,inst_addi_w,inst_andi,inst_ori,inst_xori,inst_pcaddu12i,inst_jirl,
                             inst_b,inst_bl,inst_beq,inst_bne,inst_blt,inst_bge,inst_bltu,inst_bgeu,
                             inst_ld_b,inst_ld_h,inst_ld_bu,inst_ld_hu,inst_ld_w,inst_st_b,inst_st_h,inst_st_w,
                             inst_lu12i_w,inst_csrrd,inst_csrwr,inst_csrxchg,inst_ertn,inst_break,inst_syscall,inst_cacop,inst_cacop,
                             inst_rdcntid,inst_rdcntvl_w,inst_rdcntvh_w,inst_tlbfill,inst_tlbwr,inst_tlbrd,inst_tlbsrch,inst_invtlb}};
assign     ex_D    = D_ready_go && !predict_error & !predict_error & (ex_pD | inst_syscall | inst_break | unknownInst | has_int);
wire [7:0] ecode_D = ~D_valid     ? 8'b0       :
                     ex_pD        ? ecode_pD   :
                     has_int      ? int_ecode  :
                     inst_syscall ? `ECODE_SYS :
                     inst_break   ? `ECODE_BRK :
                     unknownInst  ? `ECODE_INE : 8'b0;
wire       esubcode_D = esubcode_pD;

always @(posedge clk) begin
    if (!rstn) begin
        ex_flag <= 1'b0;
    end 
    else if (ex_en | predict_error) begin
        ex_flag <= 1'b0;
    end
    else if (ex_D) begin
        ex_flag <= 1'b1;
    end
end

//output manage
assign DE_BUS = {inst_D,        //420:389
                 inst_b,inst_bl,inst_jirl,   //388:386
                 br_base,     //385:354
                 predict_taken,//353
                 predict_target,//352:321
                 inst_beq,inst_bne,inst_blt,inst_bge,inst_bltu,inst_bgeu, //320:315
                 br_offs,         //314:283
                 pc_D,          //282:251
                 alu_op,        //250:232
                 alu_src1,      //231:200
                 alu_src2,      //199:168
                 rkd_value,     //167:136
                 gr_we,         //135
                 mem_we,        //134:131
                 dest,          //130:126
                 res_from_mem,  //125:122
                 ex_D,          //121
                 ecode_D,       //120:113
                 esubcode_D,    //112
                 csr_addr,      //111:98
                 csr_we,        //97
                 csr_value,     //96:65
                 csr_wmask,     //64:33
                 csr_wdata,     //32:1
                 res_from_csr}; //0

endmodule
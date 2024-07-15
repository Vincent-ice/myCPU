`include "Defines.vh"
module Decode (
    input                           clk,
    input                           rstn,

    input                           FD_valid,
    input [`FD_BUS_Wid-1:0]         FD_BUS,

    input [31:0]                    inst_sram_rdata,
    input [ 7:0]                    hardware_interrupt,
    
    input                           E_allowin,
    output                          D_allowin,

    input [`ED_for_BUS_Wid-1:0]     ED_for_BUS,
    input [`MD_for_BUS_Wid-1:0]     MD_for_BUS,
    input [`Wrf_BUS_Wid-1:0]        Wrf_BUS,
    input [`Wcsr_BUS_Wid-1:0]       Wcsr_BUS,

    output                          DE_valid,
    output [`DE_BUS_Wid-1:0]        DE_BUS,

    output [`Branch_BUS_Wid-1:0]    Branch_BUS,
    output                          ex_en,
    output [31:0]                   ex_entryPC,
    output                          ertn_flush,
    output [31:0]                   new_pc
);


//inst
wire [31:0] inst_D = rstn ? inst_sram_rdata : 32'b0;

wire [ 5:0] op_31_26 = inst_D[31:26];
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

wire [63:0] op_31_26_d;
wire [15:0] op_25_22_d;
wire [ 3:0] op_21_20_d;
wire [31:0] op_19_15_d;
wire [31:0] op_14_10_d;

//FD BUS
reg  [`FD_BUS_Wid-1:0] FD_BUS_D;
wire        pc_en_D;
wire [31:0] pc_D;
wire        ex_F;
wire [ 7:0] ecode_F;
wire        esubcode_D;

assign {pc_D,pc_en_D,ex_F,ecode_F,esubcode_D} = FD_BUS_D;

//pipeline handshake
reg  D_valid;
reg  ex_flag;
wire ex_D;
wire load_stall;
wire D_ready_go    = D_valid & ~load_stall;
assign D_allowin   = !D_valid || D_ready_go && E_allowin;
assign DE_valid    = D_valid && D_ready_go;
always @(posedge clk) begin
    if (!rstn) begin
        D_valid <= 1'b0;
        FD_BUS_D <= 'b0;
    end
    else if (D_allowin) begin
        D_valid <= FD_valid && (!ex_flag && !ex_D || ex_en);
    end

    if (FD_valid && D_allowin) begin
        FD_BUS_D <= FD_BUS;
    end
end


//inst decode
decoder_6_64 u_dec0(.in(op_31_26 ), .out(op_31_26_d ));
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
wire inst_jirl   = op_31_26_d[6'h13];
wire inst_b      = op_31_26_d[6'h14];
wire inst_bl     = op_31_26_d[6'h15];
wire inst_beq    = op_31_26_d[6'h16];
wire inst_bne    = op_31_26_d[6'h17];
wire inst_blt    = op_31_26_d[6'h18];
wire inst_bge    = op_31_26_d[6'h19];
wire inst_bltu   = op_31_26_d[6'h1a];
wire inst_bgeu   = op_31_26_d[6'h1b];
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

/* don't forget add the inst to the wire 'unknownInst' at last */

//alu_op manage
wire [`alu_op_Wid-1:0] alu_op;

assign alu_op[ 0] = inst_add_w | inst_addi_w | inst_ld_b | inst_ld_bu | inst_ld_h | inst_ld_hu | inst_ld_w | 
                    inst_st_b | inst_st_h | inst_st_w | 
                    inst_jirl | inst_bl | inst_pcaddu12i | inst_rdcntid | inst_rdcntvl_w | inst_rdcntvh_w;
assign alu_op[ 1] = inst_sub_w;
assign alu_op[ 2] = inst_slt | inst_slti;
assign alu_op[ 3] = inst_sltu | inst_sltui;
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


wire [31:0] imm;
assign imm = src2_is_4 ? 32'h4                      :
             need_si20 ? {i20[19:0], 12'b0}         :
             need_si12u? {20'b0, i12[11:0]}         :
             need_si16 ? {{14{i16[15]}}, i16, 2'b0} :
/*need_ui5 || need_si12*/{{20{i12[11]}}, i12[11:0]} ;
 

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
wire       gr_we         = ~inst_st_w & ~inst_st_b & ~inst_st_h & ~inst_beq  & ~inst_bne & ~inst_b & pc_en_D & 
                           ~inst_ertn & ~inst_blt  & ~inst_bge  & ~inst_bltu & ~inst_bgeu  ;
wire [3:0] mem_we        = inst_st_w ? 4'b1111 :
                           inst_st_b ? 4'b0001 :
                           inst_st_h ? 4'b0011 : 4'b0000;
wire [4:0] dest          = dst_is_r1    ? 5'd1 : 
                           inst_rdcntid ? rj   : rd;

//regfile data manage
wire [ 4:0] rf_raddr1 = rj;
wire [ 4:0] rf_raddr2 = src_reg_is_rd ? rd :rk;
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
                    ((rf_raddr1 == dest_E) && (|rf_raddr1) || (rf_raddr2 == dest_E) && (|rf_raddr2)) && 
                    ((rf_raddr1 != dest_M) || (rf_raddr2 != dest_M));

wire [31:0] rj_value;
wire [31:0] rkd_value;
assign rj_value  =  |rj               ? 
                    ((rj == dest_E)   ? rf_wdata_E :
                     (rj == dest_M)   ? rf_wdata_M : 
                     (rj == rf_waddr) && rf_we ? rf_wdata : rf_rdata1) : rf_rdata1;
assign rkd_value =  |rf_raddr2               ? 
                    ((rf_raddr2 == dest_E)   ? rf_wdata_E :
                     (rf_raddr2 == dest_M)   ? rf_wdata_M : 
                     (rf_raddr2 == rf_waddr) && rf_we ? rf_wdata : rf_rdata2) : rf_rdata2;

//CSR data manage
wire [13:0] csr_addr     = inst_ertn ? 14'h06 :
                           inst_rdcntid ? 14'h40 : inst_D[23:10];
wire        csr_we       = inst_csrwr | inst_csrxchg;
wire        csr_re       = inst_csrrd | inst_csrwr | inst_csrxchg;
wire [31:0] csr_wmask    = {32{inst_csrxchg}} & rj_value | {32{~inst_csrxchg}};
wire [31:0] csr_wdata    = rkd_value;
wire [31:0] csr_rdata;

wire        csr_we_W;
wire [13:0] csr_addr_W;
wire [31:0] csr_wmask_W;
wire [31:0] csr_wdata_W;
wire [13:0] csr_raddr_forward;
wire [31:0] csr_rdata_forward;
wire        ex_en_W;
wire [ 7:0] ecode_W;
wire        esubcode_W;
wire [31:0] pc_W;
wire [31:0] ex_pc;
wire [31:0] era_pc;
wire [31:0] vaddr_W;
wire        has_int;
wire [ 7:0] int_ecode;
wire [63:0] counter;
wire [31:0] counterID;
assign {ex_en_W,ecode_W,esubcode_W,csr_we_W,csr_addr_W,csr_wmask_W,csr_wdata_W,pc_W,vaddr_W} = Wcsr_BUS;
assign ertn_flush = inst_ertn && D_valid;
assign ex_en      = ex_en_W;
assign ex_pc      = ex_F ? pc_D - 32'd4 : pc_W;

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
    .hardware_interrupt(hardware_interrupt),
    .has_int   (has_int   ),
    .int_ecode (int_ecode ),
    .new_pc    (era_pc    ),
    .ertn_flush(ertn_flush),
    .ex_entryPC(ex_entryPC),
    .counter   (counter   ),
    .counterID (counterID )
);

    //forward manage
wire        csr_forward_E = csr_we_E && (csr_addr_E == csr_addr);
wire        csr_forward_M = csr_we_M && (csr_addr_M == csr_addr);
wire        csr_forward_W = csr_we_W && (csr_addr_W == csr_addr);
assign      csr_raddr_forward = ({14{csr_forward_E}} & csr_addr_E) | ({14{csr_forward_M}} & csr_addr_M);
wire [31:0] csr_wmask_forward = ({32{csr_forward_E}} & csr_wmask_E) | ({32{csr_forward_M}} & csr_wmask_M);
wire [31:0] csr_wdata_forward = ({32{csr_forward_E}} & csr_wdata_E) | ({32{csr_forward_M}} & csr_wdata_M);
wire [31:0] csr_value;
assign csr_value =  csr_forward_E | csr_forward_M ? (csr_wdata_forward & csr_wmask_forward | ~csr_wmask_forward & csr_rdata_forward) : 
                    csr_forward_W                 ? (csr_wdata_W & csr_wmask_W | ~csr_wmask_W & csr_wdata_forward)        : csr_rdata;
assign new_pc = csr_value;

//branch manage
wire        rj_eq_rd;
wire        rj_lt_rd;
wire        rj_ltu_rd;
wire [31:0] out;
wire        onverflow;
wire        sign_bit;
wire        br_taken;
wire [31:0] br_target;
wire [31:0] br_offs;
wire [31:0] jirl_offs;

assign {sign_bit, out} = {1'b0, rj_value} + {1'b1, ~rkd_value} + 33'd1;
assign rj_eq_rd = (rj_value == rkd_value);
assign overflow = (rj_value[31] ^ rkd_value[31]) & (rj_value[31] ^ out[31]);
assign rj_eq_rd = (rj_value == rkd_value);
assign rj_lt_rd = out[31] ^ overflow;
assign rj_ltu_rd= sign_bit;
assign br_taken = (   inst_beq  &&  rj_eq_rd
                   || inst_bne  && !rj_eq_rd
                   || inst_jirl
                   || inst_bl
                   || inst_b
                   || inst_blt  &&  rj_lt_rd
                   || inst_bge  && !rj_lt_rd
                   || inst_bltu &&  rj_ltu_rd
                   || inst_bgeu && !rj_ltu_rd
                   ) && rstn && !ex_en;

assign br_offs = need_si26 ? {{ 4{i26[25]}}, i26[25:0], 2'b0} :
                             {{14{i16[15]}}, i16[15:0], 2'b0} ; 
assign jirl_offs = {{14{i16[15]}}, i16[15:0], 2'b0};

assign br_target = (inst_beq || inst_bne || inst_bl   || inst_b    ||
                    inst_blt || inst_bge || inst_bltu || inst_bgeu) ? (pc_D + br_offs) :
                                                   /*inst_jirl*/ (rj_value + jirl_offs);

//alu data input manage
wire  [31:0] alu_src1;
wire  [31:0] alu_src2;
assign alu_src1 = src1_is_pc     ? pc_D[31:0]     :
                  inst_rdcntid   ? csr_value      :
                  inst_rdcntvl_w ? counter[31:0]  : 
                  inst_rdcntvh_w ? counter[63:32] : rj_value;
assign alu_src2 = src2_is_imm                                    ? imm   :
                  inst_rdcntid | inst_rdcntvl_w | inst_rdcntvh_w ? 32'b0 : rkd_value;

//exception manage
wire       unknownInst = ~inst_add_w && ~inst_sub_w && ~inst_slt && ~inst_sltu && ~inst_nor && ~inst_and && ~inst_or && ~inst_xor && 
                         ~inst_sll_w && ~inst_srl_w && ~inst_sra_w && ~inst_mul_w && ~inst_mulh_w && ~inst_mulh_wu && ~inst_div_w && 
                         ~inst_mod_w && ~inst_div_wu && ~inst_mod_wu && ~inst_slli_w && ~inst_srli_w && ~inst_srai_w && ~inst_slti && 
                         ~inst_sltui && ~inst_addi_w && ~inst_andi && ~inst_ori && ~inst_xori && ~inst_pcaddu12i && ~inst_jirl && 
                         ~inst_b && ~inst_bl && ~inst_beq && ~inst_bne && ~inst_blt && ~inst_bge && ~inst_bltu && ~inst_bgeu && 
                         ~inst_ld_b && ~inst_ld_h && ~inst_ld_bu && ~inst_ld_hu && ~inst_ld_w && ~inst_st_b && ~inst_st_h && ~inst_st_w && 
                         ~inst_lu12i_w && ~inst_csrrd && ~inst_csrwr && ~inst_csrxchg && ~inst_ertn && ~inst_break && ~inst_syscall &&
                         ~inst_rdcntid && ~inst_rdcntvl_w && ~inst_rdcntvh_w;
assign     ex_D    = D_ready_go && (ex_F | inst_syscall | inst_break | unknownInst | has_int);
wire [7:0] ecode_D = ~D_valid     ? 8'b0       :
                     ex_F         ? ecode_F    :
                     has_int      ? int_ecode  :
                     inst_syscall ? `ECODE_SYS :
                     inst_break   ? `ECODE_BRK :
                     unknownInst  ? `ECODE_INE : 8'b0;

always @(posedge clk) begin
    if (!rstn) begin
        ex_flag <= 1'b0;
    end 
    else if (ex_D) begin
        ex_flag <= 1'b1;
    end
    else if (ex_en) begin
        ex_flag <= 1'b0;
    end
end

//output manage
assign Branch_BUS = {br_taken,  //32
                     br_target};//31:0
assign DE_BUS = {pc_D,          //282:251
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
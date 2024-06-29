`include "Defines.vh"
module Decode (
    input                           clk,
    input                           rstn,

    input                           FD_valid,
    input [`FD_BUS_Wid-1:0]         FD_BUS,

    input [31:0]                    inst_sram_rdata,
    
    input                           E_allowin,
    output                          D_allowin,

    input [`ED_for_BUS_Wid-1:0]     ED_for_BUS,
    input [`MD_for_BUS_Wid-1:0]     MD_for_BUS,
    input [`Wrf_BUS_Wid-1:0]        Wrf_BUS,

    output                          DE_valid,
    output [`DE_BUS_Wid-1:0]        DE_BUS,

    output [`Branch_BUS_Wid-1:0]    Branch_BUS
);


//inst
wire [31:0] inst_D = inst_sram_rdata;

wire [ 5:0] op_31_26 = inst_D[31:26];
wire [ 3:0] op_25_22 = inst_D[25:22];
wire [ 1:0] op_21_20 = inst_D[21:20];
wire [ 4:0] op_19_15 = inst_D[19:15];

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

//FD BUS
reg  [`FD_BUS_Wid-1:0] FD_BUS_D;
wire        pc_en_D;
wire [31:0] pc_D;

assign {pc_D,pc_en_D} = FD_BUS_D;

//pipeline handshake
reg  D_valid;
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
        D_valid <= FD_valid;
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
wire inst_ld_w   = op_31_26_d[6'h0a] & op_25_22_d[4'h2];
wire inst_st_w   = op_31_26_d[6'h0a] & op_25_22_d[4'h6];
wire inst_pcaddu12i= op_31_26_d[6'h7] & ~inst_D[25];
wire inst_jirl   = op_31_26_d[6'h13];
wire inst_b      = op_31_26_d[6'h14];
wire inst_bl     = op_31_26_d[6'h15];
wire inst_beq    = op_31_26_d[6'h16];
wire inst_bne    = op_31_26_d[6'h17];
wire inst_lu12i_w= op_31_26_d[6'h05] & ~inst_D[25];

//alu_op manage
wire [`alu_op_Wid-1:0] alu_op;

assign alu_op[ 0] = inst_add_w | inst_addi_w | inst_ld_w | inst_st_w
                    | inst_jirl | inst_bl | inst_pcaddu12i;
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
                   inst_andi | inst_ori | inst_xori;
wire need_si16  =  inst_jirl | inst_beq | inst_bne;
wire need_si20  =  inst_lu12i_w | inst_pcaddu12i;
wire need_si26  =  inst_b | inst_bl;
wire src2_is_4  =  inst_jirl | inst_bl;


wire [31:0] imm;
assign imm = src2_is_4 ? 32'h4                      :
             need_si20 ? {i20[19:0], 12'b0}         :
/*need_ui5 || need_si12*/{{20{i12[11]}}, i12[11:0]} ;
 

wire   src_reg_is_rd = inst_beq | inst_bne | inst_st_w;
wire   src1_is_pc    = inst_jirl | inst_bl | inst_pcaddu12i;
wire   src2_is_imm   = inst_slli_w |
                       inst_srli_w |
                       inst_srai_w |
                       inst_addi_w |
                       inst_ld_w   |
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
wire   res_from_mem  = inst_ld_w;
wire   dst_is_r1     = inst_bl;
wire   gr_we         = ~inst_st_w & ~inst_beq & ~inst_bne & ~inst_b & pc_en_D;
wire   mem_we        = inst_st_w;
wire [4:0] dest      = dst_is_r1 ? 5'd1 : rd;

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
wire        res_from_mem_E;
wire [ 4:0] dest_E;
wire [ 4:0] dest_M;
wire [31:0] result_E;
wire [31:0] result_M;
assign {res_from_mem_E,dest_E,result_E} = ED_for_BUS;
assign {dest_M,result_M} = MD_for_BUS;

assign load_stall = res_from_mem_E && ((rf_raddr1 == dest_E) || (rf_raddr2 == dest_E));

wire [31:0] rj_value;
wire [31:0] rkd_value;
assign rj_value  =  rj                ? 
                    ((rj == dest_E)   ? result_E :
                     (rj == dest_M)   ? result_M : 
                     (rj == rf_waddr) && rf_we ? rf_wdata : rf_rdata1) : rf_rdata1;
assign rkd_value =  rf_raddr2                ? 
                    ((rf_raddr2 == dest_E)   ? result_E :
                     (rf_raddr2 == dest_M)   ? result_M : 
                     (rf_raddr2 == rf_waddr) && rf_we ? rf_wdata : rf_rdata2) : rf_rdata2;

//branch manage
wire        rj_eq_rd;
wire        br_taken;
wire [31:0] br_target;
wire [31:0] br_offs;
wire [31:0] jirl_offs;

assign rj_eq_rd = (rj_value == rkd_value);
assign br_taken = (   inst_beq  &&  rj_eq_rd
                   || inst_bne  && !rj_eq_rd
                   || inst_jirl
                   || inst_bl
                   || inst_b
                  ) && rstn;

assign br_offs = need_si26 ? {{ 4{i26[25]}}, i26[25:0], 2'b0} :
                             {{14{i16[15]}}, i16[15:0], 2'b0} ; 
assign jirl_offs = {{14{i16[15]}}, i16[15:0], 2'b0};

assign br_target = (inst_beq || inst_bne || inst_bl || inst_b) ? (pc_D + br_offs) :
                                                   /*inst_jirl*/ (rj_value + jirl_offs);

//alu data input manage
wire  [31:0] alu_src1;
wire  [31:0] alu_src2;
assign alu_src1 = src1_is_pc  ? pc_D[31:0] : rj_value;
assign alu_src2 = src2_is_imm ? imm : (inst_bl ? 32'd4 : rkd_value);
//output manage
assign Branch_BUS = {br_taken,br_target};
assign DE_BUS = {pc_D,alu_op,alu_src1,alu_src2,rkd_value,gr_we,mem_we,dest,res_from_mem};

endmodule
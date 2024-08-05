`timescale 1ns / 1ps
`include "Defines.vh"
module preDecode (
    input                       clk,
(*max_fanout = 40*)    input                       rstn,

    input                       FpD_valid,
    input  [`FpD_BUS_Wid-1:0]   FpD_BUS,

    output                      pDD_valid,
    output [`pDD_BUS_Wid-1:0]   pDD_BUS,

    input                       D_allowin,
    output                      pD_allowin,

    output [`predict_BUS_Wid-1:0]predict_BUS,
    input  [`PB_BUS_Wid-1:0]    PB_BUS,

    input                       predict_error,
    input                       ertn_flush,
    input                       ex_D,
    input                       ex_E,
    input                       ex_en
);

//FpD BUS
reg  [`FpD_BUS_Wid-1:0] FpD_BUS_pD;
wire        pc_en_pD;
wire [31:0] pc_pD;
wire [31:0] inst_pD;
wire        ex_F;
wire [ 7:0] ecode_pD;
wire        esubcode_pD;

assign {pc_pD,inst_pD,pc_en_pD,ex_F,ecode_pD,esubcode_pD} = FpD_BUS_pD;

//predict BUS
wire [31:0] inst_W;
wire [31:0] pc_W;
wire        direct_jump_W;
wire        indirect_jump_W;
wire        br_taken_W;
wire [31:0] br_target_W;
assign {inst_W,direct_jump_W,indirect_jump_W,br_taken_W,br_target_W,pc_W} = PB_BUS;

//pipeline handshake
reg  pD_valid;
wire ex_pD;
reg  ex_flag;
wire pD_ready_go    = pD_valid;
(*max_fanout = 20*)assign pD_allowin   = !pD_valid || pD_ready_go && D_allowin;
(*max_fanout = 20*)assign pDD_valid    = pD_valid && pD_ready_go;
always @(posedge clk) begin
    if (!rstn) begin
        FpD_BUS_pD <= 'b0;
    end
    else if (ex_en) begin
        FpD_BUS_pD <= 'b0;
    end
    else if (FpD_valid && pD_allowin) begin
        FpD_BUS_pD <= FpD_BUS;
    end
    
    if (!rstn) begin
        pD_valid <= 1'b0;
    end
    else if (pD_allowin) begin
        pD_valid <= FpD_valid && (!ex_flag && !ex_pD/*  || ex_en */) && !predict_error && !ertn_flush;
    end

    
end


wire [ 5:0] op_31_26 = inst_pD[31:26];
wire [63:0] op_31_26_d;
decoder_6_64 u_dec0(.in(op_31_26 ), .out(op_31_26_d ));
wire inst_jirl   = op_31_26_d[6'h13];
wire inst_b      = op_31_26_d[6'h14];
wire inst_bl     = op_31_26_d[6'h15];
wire inst_beq    = op_31_26_d[6'h16];
wire inst_bne    = op_31_26_d[6'h17];
wire inst_blt    = op_31_26_d[6'h18];
wire inst_bge    = op_31_26_d[6'h19];
wire inst_bltu   = op_31_26_d[6'h1a];
wire inst_bgeu   = op_31_26_d[6'h1b];

// Branch Target Buffer      for direct jump Instructions
reg  [11:0] BTB_PC [`BTB_NUM-1:0];          // use PC[13:2] as index
reg  [0:0]  BTB_value [`BTB_NUM-1:0];
reg  [31:0] BTB_predict [`BTB_NUM-1:0];
reg  [$clog2(`BTB_NUM)-1:0] BTB_tag;
wire [`BTB_NUM-1:0] BTB_hit;
wire [`BTB_NUM-1:0] BTB_target_buf [31:0];
wire [31:0] BTB_target;

integer n;
always @(posedge clk) begin
    if (!rstn) begin
        BTB_tag <= 'b0;
        for (n = 0;n < `BTB_NUM;n = n + 1) begin
            BTB_PC[n]    <= 12'h0;
            BTB_value[n] <= 1'b0;
            BTB_predict[n]<= 32'h0;
        end
    end
    else if (direct_jump_W) begin
        BTB_PC[BTB_tag] <= pc_W[13:2];
        BTB_value[BTB_tag] <= 1'b1;
        BTB_predict[BTB_tag] <= br_target_W;
        BTB_tag <= BTB_tag + 1;
    end
end

generate
    genvar i,j;
    for (i = 0;i < `BTB_NUM;i = i + 1) begin
        assign BTB_hit[i] = BTB_value[i] & (BTB_PC[i] == pc_pD[13:2]);
        for (j = 0;j < 32;j = j + 1) begin
            assign BTB_target_buf[j][i] = BTB_hit[i] & BTB_predict[i][j];
        end
    end
endgenerate

generate
    for (i = 0;i < 32;i = i + 1) begin
        assign BTB_target[i] = |BTB_target_buf[i];
    end
endgenerate

// Adaptive Two-level Predictror
reg  [`BHR_Wid-1:0] BHT [2**`BHT_INDEX_Wid-1:0];         // use PC's 5-bit hash as index
reg  [1:0]          PHT [2**`BHR_Wid-1:0];
wire [`BHT_INDEX_Wid-1:0] BHT_index;
wire [`BHR_Wid-1:0] PHT_index;
hash_function #(`BHT_INDEX_Wid) u_hash_function(.data_in(pc_pD),.hash_out(BHT_index));

wire [`BHT_INDEX_Wid-1:0] BHT_index_W;
hash_function #(`BHT_INDEX_Wid) u_hash_function_W(.data_in(pc_W),.hash_out(BHT_index_W));
wire [`BHR_Wid-1:0] PHT_index_W = BHT[BHT_index_W] ^ pc_W[`BHT_INDEX_Wid-1:0];
wire [1:0]          PHT_wdata;
bimodal_predictor u_bimodal_predictor(.data_i(PHT[PHT_index_W]),.taken(br_taken_W),.data_o(PHT_wdata));
always @(posedge clk) begin
    if (!rstn) begin
        for (n = 0;n < 2**`BHT_INDEX_Wid;n = n + 1) begin
            BHT[n] <= `BHR_Wid'b0;
        end
        for (n = 0;n < 2**`BHR_Wid;n = n + 1) begin
            PHT[n] <= 2'b0;
        end    
    end
    else if (indirect_jump_W) begin
        BHT[BHT_index_W] <= {BHT[BHT_index_W][`BHR_Wid-2:0],br_taken_W};
        PHT[PHT_index_W] <= PHT_wdata;
    end
end

assign PHT_index = BHT[BHT_index] ^ pc_pD[`BHT_INDEX_Wid-1:0];   // use xor to avoid aliasing

// Target Cache
reg  [31:0] TC_PC [`TC_NUM-1:0];
wire [31:0] TC_target;

always @(posedge clk) begin
    if (!rstn) begin
        for (n = 0;n < `TC_NUM;n = n + 1) begin
            TC_PC[n] <= 32'b0;
        end
    end
    else if (indirect_jump_W && br_taken_W) begin
        TC_PC[PHT_index_W] <= br_target_W;
    end
end

assign TC_target = TC_PC[PHT_index];

// Branch Prediction
wire [31:0] predict_target;
wire        predict_taken;
wire        predict_direct_taken;
wire        predict_indirect_taken;

assign predict_direct_taken = pD_valid & (inst_jirl | inst_b | inst_bl) & (|BTB_hit);
assign predict_indirect_taken = pD_valid & PHT[PHT_index][1] & (inst_beq | inst_bne | inst_blt | inst_bge | inst_bltu | inst_bgeu);
assign predict_taken = predict_direct_taken | predict_indirect_taken;
assign predict_target = predict_direct_taken ? (|BTB_hit ? BTB_target : TC_target) : 32'b0;

assign predict_BUS = {predict_taken,predict_target};

// exception flag
assign ex_pD = pD_valid & !predict_error & ex_F;
always @(posedge clk) begin
    if (!rstn) begin
        ex_flag <= 1'b0;
    end 
    else if (ex_en | predict_error) begin
        ex_flag <= 1'b0;
    end
    else if (ex_pD) begin
        ex_flag <= 1'b1;
    end
end
// pDD BUS
assign pDD_BUS = {pc_pD,            //180:149
                  inst_pD,          //148:117
                  pc_en_pD,         //116
                  ex_pD,            //115
                  ecode_pD,         //114:107
                  esubcode_pD,      //106
                  op_31_26_d,       //105:42
                  inst_jirl,        //41
                  inst_b,           //40
                  inst_bl,          //39
                  inst_beq,         //38
                  inst_bne,         //37
                  inst_blt,         //36
                  inst_bge,         //35
                  inst_bltu,        //34    
                  inst_bgeu,        //33
                  predict_taken,    //32
                  predict_target};  //31:0
endmodule

module bimodal_predictor (
    input  [1:0] data_i,
    input        taken,
    output reg [1:0] data_o
);                          //00 <-> 01 <-> 11 <-> 10

always @(*) begin
    case (data_i)
        2'b00: data_o = taken ? 2'b01 : 2'b00;
        2'b01: data_o = taken ? 2'b11 : 2'b00;
        2'b11: data_o = taken ? 2'b10 : 2'b01;
        2'b10: data_o = taken ? 2'b10 : 2'b11;
        default: data_o = 2'b00;
    endcase
end
  
endmodule

module hash_function #(
    parameter hash = 5
) (    
    input [31:0] data_in,
    output [hash-1:0] hash_out
);

wire [31:0] data_right_shift_16 = data_in >> 16;
wire [31:0] data_right_shift_8 = data_in >> 8;
wire [hash-1:0] final_hash = (data_in[hash-1:0] ^ data_right_shift_16[hash-1:0]) + (data_in[hash-1:0] ^ data_right_shift_8[hash-1:0]);

assign hash_out = final_hash;

endmodule
`include "Defines.vh"
module Fetch (
    input                           clk,
    input                           rstn,

    input    [`predict_BUS_Wid-1:0] predict_BUS,
    input    [`Branch_BUS_Wid-1:0]  Branch_BUS_D,
    input    [`Branch_BUS_Wid-1:0]  Branch_BUS_E,
    input                           ex_en,
    input    [31:0]                 ex_entryPC,
    input                           ertn_flush,
    input    [31:0]                 new_pc,

    input                           pD_allowin,  

    output                          FpD_valid,
    output   [`FpD_BUS_Wid-1:0]     FpD_BUS,

    output                          inst_sram_en,
    output   [3:0]                  inst_sram_we,
    output   [31:0]                 inst_sram_addr,
    output   [31:0]                 inst_sram_wdata

);

//Branch bus
wire br_taken_D;
wire [31:0] br_target_D;
assign {br_taken_D,br_target_D} = Branch_BUS_D;
wire br_taken_E;
wire [31:0] br_target_E;
assign {br_taken_E,br_target_E} = Branch_BUS_E;

wire        predict_taken  = predict_BUS[32];
wire [31:0] predict_target = predict_BUS[31:0];

//pipeline handshake
wire ex_F;
reg  F_valid;
wire F_valid_next   = rstn;//next cycle valid
wire F_ready_go     = 1'b1;//ready send to next stage
wire F_allowin      = !F_valid || ex_en || F_ready_go && pD_allowin && !ex_F;//allow input data
assign FpD_valid     = F_valid_next && F_ready_go;//validity of D stage
always @(posedge clk) begin
    if (!rstn) begin
        F_valid <= 1'b0;
    end
    else if (F_allowin) begin
        F_valid <= F_valid_next;
    end
end

//PC
reg  [31:0] pc_reg;
wire [31:0] pc_next;
wire        pc_en;
wire [31:0] pc_plus4 = pc_reg + 32'd4;

assign pc_en = F_valid_next && F_allowin;
assign pc_next = br_taken_E   ? br_target_E                        :
                 br_taken_D   ? br_target_D                        : 
                 ex_en        ? ex_entryPC                         :
                 predict_taken? predict_target                     :
                 ertn_flush   ? new_pc                             : pc_plus4;

always @(posedge clk) begin
    if(!rstn)begin
        pc_reg <= 32'h1bff_fffc;
    end else if (F_valid_next && F_allowin) begin
        pc_reg <= pc_next;
    end
end

//exception manage
assign      ex_F       = |pc_next[1:0] && F_valid_next;
wire [ 7:0] ecode_F    = ex_F ? `ECODE_ADEF : 8'h00;
wire        esubcode_F = `ESUBCODE_ADEF;

//FD BUS
assign FpD_BUS = {pc_next,      //42:11
                 pc_en,         //10
                 ex_F,          //9
                 ecode_F,       //8:1
                 esubcode_F};   //0

//inst sram manage
assign inst_sram_en    = pc_en ; 
assign inst_sram_addr  = pc_next; //virtual
assign inst_sram_we    = 4'b0  ;
assign inst_sram_wdata = 32'b0 ;

    
endmodule
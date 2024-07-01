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
    output   [31:0]                 inst_sram_addr,inst_sram_wdata

);

//Branch bus
wire br_taken;
wire [31:0] br_target;
assign {br_taken,br_target} = Branch_BUS;

//pipeline handshake
wire ex_F;
reg  F_valid;
wire F_valid_next   = rstn;//next cycle valid
wire F_ready_go     = 1'b1;//ready send to next stage
wire F_allowin      = !F_valid || ex_en || ertn_flush || F_ready_go && D_allowin && !ex_F;//allow input data
assign FD_valid     = F_valid_next && F_ready_go;//validity of D stage
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

//exception manage
assign      ex_F       = |pc_next[1:0] && F_valid_next;
wire [ 5:0] ecode_F    = ex_F ? `ECODE_ADEF : 6'h00;
wire        esubcode_F = `ESUBCODE_ADEF;

//FD BUS
assign FD_BUS = {inst_sram_addr,pc_en,ex_F,ecode_F,esubcode_F};

//inst sram manage
assign inst_sram_en    = pc_en ; 
assign inst_sram_addr  = pc_next; //virtual
assign inst_sram_we    = 4'b0  ;
assign inst_sram_wdata = 32'b0 ;

    
endmodule
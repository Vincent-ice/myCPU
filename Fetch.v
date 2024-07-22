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

    output                          inst_sram_req,
    output                          inst_sram_wr,
    output   [1:0]                  inst_sram_size,
    output   [3:0]                  inst_sram_wstrb,
    output   [31:0]                 inst_sram_addr,
    input                           inst_sram_addr_ok,
    input                           inst_sram_data_ok,
    output   [31:0]                 inst_sram_wdata,
    input    [31:0]                 inst_sram_rdata

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
reg  [31:0] pc_reg;
reg  [31:0] pc_next;
wire        pc_en;
wire [31:0] pc_plus4 = pc_reg + 32'd4;
wire ex_F;
wire br_taken = br_taken_D | br_taken_E | predict_taken;
reg  [31:0] br_target;
reg  br_taken_buff;
reg  [31:0] br_target_buff;
reg  send_handshake;
reg  F_valid;
wire F_valid_next   = rstn & inst_sram_req & inst_sram_addr_ok;//next cycle valid
wire F_ready_go     = inst_sram_data_ok & !ex_en | ex_F;//ready send to next stage
wire F_allowin      = !F_valid || ex_en || F_ready_go && pD_allowin && !ex_F;//allow input data
assign FpD_valid     = F_valid & F_ready_go & !br_taken_buff & !br_taken;//validity of D stage
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
    else if(inst_sram_data_ok & inst_sram_req) begin
        send_handshake <= 1'b1;
    end
end

//branch buff
always @(*) begin
    case (1'b1)
        br_taken_D : br_target = br_target_D;
        br_taken_E : br_target = br_target_E;
        predict_taken : br_target = predict_target;
        default    : br_target = 32'b0;
    endcase
end
always @(posedge clk) begin
    if (!rstn) begin
        br_taken_buff <= 1'b0;
        br_target_buff <= 32'b0;
    end
    else if (!br_taken_buff & predict_taken | br_taken_D | br_taken_E) begin
        br_taken_buff <= 1'b1;
        case (1'b1)
            br_taken_D : br_target_buff <= br_target_D;
            br_taken_E : br_target_buff <= br_target_E;
            predict_taken : br_target_buff <= predict_target;
            default    : br_target_buff <= 32'b0;
        endcase
    end
    else if (F_valid_next & F_allowin) begin
        br_taken_buff <= 1'b0;
    end
end

//PC
assign pc_en   = F_allowin && !ex_F && !send_handshake || ex_en;
always @(*) begin
    case (1'b1)
        br_taken_buff : pc_next = br_target_buff;
        br_taken      : pc_next = br_target;
        ex_en         : pc_next = ex_entryPC;
        ertn_flush    : pc_next = new_pc;
        default       : pc_next = pc_plus4;
    endcase
end
/* assign pc_next = br_taken_E   ? br_target_E                        :
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

//exception manage
assign      ex_F       = |pc_next[1:0] && F_valid_next;
wire [ 7:0] ecode_F    = ex_F ? `ECODE_ADEF : 8'h00;
wire        esubcode_F = `ESUBCODE_ADEF;

//FD BUS
assign FpD_BUS = {pc_reg,       //74:43
                 inst_sram_rdata,//42:11
                 pc_en,         //10
                 ex_F,          //9
                 ecode_F,       //8:1
                 esubcode_F};   //0

//inst sram manage
assign inst_sram_req   = pc_en;
assign inst_sram_wr    = 1'b0;
assign inst_sram_size  = 2'b10;
assign inst_sram_wstrb = 4'b0;
assign inst_sram_addr  = pc_next; //virtual
assign inst_sram_wdata = 32'b0 ;

    
endmodule
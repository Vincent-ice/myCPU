`include "Defines.vh"
module Fetch (
    input                           clk,
    input                           rstn,

    input    [`predict_BUS_Wid-1:0] predict_BUS,
    input    [`Branch_BUS_Wid-1:0]  Branch_BUS_D,
    input    [`Branch_BUS_Wid-1:0]  Branch_BUS_E,

    input                           ex_D,
    input                           ex_E, 
    input                           ex_en_i,
    input    [31:0]                 ex_entryPC,
    input                           ertn_flush_i,
    input    [31:0]                 new_pc,

    input                           pD_allowin,
    input                           BTB_stall,

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
reg  has_ex;
reg  ex_en;
reg  ertn_flush;
wire br_taken = br_taken_D | br_taken_E | predict_taken;
reg  [31:0] br_target;
reg  br_taken_buff;
reg  [31:0] br_target_buff;
reg  send_handshake;
reg  F_valid;
wire F_valid_next   = rstn & inst_sram_req & inst_sram_addr_ok;//next cycle valid
reg  F_ready_go;//ready send to next stage
always @(posedge clk or posedge inst_sram_data_ok) begin
    if (!rstn) begin
        F_ready_go <= 1'b0;
    end
    else if (inst_sram_data_ok & !has_ex) begin
        F_ready_go <= 1'b1;
    end
    else if (inst_sram_addr_ok & inst_sram_req || has_ex || ertn_flush) begin
        F_ready_go <= 1'b0;
    end
end
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
    else if (inst_sram_addr_ok & inst_sram_req & ex_en) begin
        has_ex <= 1'b0;
    end
end

//ex_en buff
always @(posedge clk) begin
    if (!rstn) begin
        ex_en <= 1'b0;
    end
    else if (ex_en_i) begin
        ex_en <= 1'b1;
    end
    else if (F_valid_next & F_allowin) begin
        ex_en <= 1'b0;
    end
end

//ertn_flush buff
always @(posedge clk or posedge ertn_flush_i) begin
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
assign pc_en   = F_allowin && !ex_F && !send_handshake && !BTB_stall;
always @(*) begin
    case (1'b1)
        ex_en & has_ex: pc_next = ex_entryPC;
        br_taken_buff : pc_next = br_target_buff;
        br_taken      : pc_next = br_target;
        has_ex        : pc_next = ex_entryPC;
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
assign      ex_F       = |pc_reg[1:0] && F_valid;
wire [ 7:0] ecode_F    = ex_F ? `ECODE_ADEF : 8'h00;
wire        esubcode_F = `ESUBCODE_ADEF;

//inst sram manage
reg  [31:0] inst_sram_rdata_buff;
assign inst_sram_req   = pc_en;
assign inst_sram_wr    = 1'b0;
assign inst_sram_size  = 2'b10;
assign inst_sram_wstrb = 4'b0;
assign inst_sram_addr  = pc_next; //virtual
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
                 ex_F,          //9
                 ecode_F,       //8:1
                 esubcode_F};   //0
endmodule
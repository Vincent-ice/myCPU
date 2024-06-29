`include "Defines.vh"
module Writeback (
    input                       clk,
    input                       rstn,

    output                      W_allowin,

    input                       MW_valid,
    input  [`MW_BUS_Wid-1:0]    MW_BUS,

    output [`Wrf_BUS_Wid-1:0]   Wrf_BUS,

    output [31:0]               debug_wb_pc,
    output [3:0]                debug_wb_rf_we,
    output [4:0]                debug_wb_rf_wnum,
    output [31:0]               debug_wb_rf_wdata 
);

//MW BUS
reg [`MW_BUS_Wid-1:0] MW_BUS_W;
wire [31:0] pc_W;
wire [31:0] final_result_W;
wire        gr_we_W;
wire [ 4:0] dest_W;

assign {pc_W,final_result_W,gr_we_W,dest_W} = MW_BUS_W;

//pipeline handshake
reg    W_valid;
wire   W_ready_go = 1'b1;
assign W_allowin  = !W_valid || W_ready_go;
always @(posedge clk) begin
    if (!rstn) begin
        W_valid <= 1'b0;
        MW_BUS_W <= 'b0;
    end
    else if (W_allowin) begin
        W_valid <= MW_valid;
    end

    if (MW_valid && W_allowin) begin
        MW_BUS_W <= MW_BUS;
    end
end

//Wrf BUS
assign Wrf_BUS = {gr_we_W && W_valid,dest_W,final_result_W};
    
// debug info generate
assign debug_wb_pc       = pc_W;
assign debug_wb_rf_we    = {4{gr_we_W && W_valid}};
assign debug_wb_rf_wnum  = dest_W;
assign debug_wb_rf_wdata = final_result_W;

endmodule
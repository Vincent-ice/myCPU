`include "Defines.vh"
module Writeback (
    input                       clk,
    input                       rstn,

    output                      W_allowin,

    input                       MW_valid,
    input  [`MW_BUS_Wid-1:0]    MW_BUS,

    output [`Wrf_BUS_Wid-1:0]   Wrf_BUS,
    output [`Wcsr_BUS_Wid-1:0]  Wcsr_BUS,
    output [`PB_BUS_Wid-1:0]    PB_BUS,

    input                       ex_en,

    output [31:0]               debug_wb_pc,
    output [3:0]                debug_wb_rf_we,
    output [4:0]                debug_wb_rf_wnum,
    output [31:0]               debug_wb_rf_wdata 
);

//MW BUS
reg [`MW_BUS_Wid-1:0] MW_BUS_W;
wire [`WpD_BUS_Wid-1:0] PB_BUS_W;
wire [31:0] pc_W;
wire [31:0] final_result_W;
wire        gr_we_W;
wire [ 4:0] dest_W;
wire [31:0] vaddr_W;
wire        ex_W;
wire [ 7:0] ecode_W;
wire        esubcode_W;
wire [13:0] csr_addr_W;
wire        csr_we_W;
wire [31:0] csr_wmask_W;
wire [31:0] csr_wdata_W;

assign {PB_BUS_W,pc_W,final_result_W,gr_we_W,dest_W,vaddr_W,
        ex_W,ecode_W,esubcode_W,csr_addr_W,csr_we_W,csr_wmask_W,csr_wdata_W} = MW_BUS_W;

//pipeline handshake
reg    W_valid;
wire   W_ready_go = 1'b1;
assign W_allowin  = !W_valid || W_ready_go;
always @(posedge clk) begin
    if (!rstn) begin
        W_valid <= 1'b0;
        MW_BUS_W <= 'b0;
    end
    else if (ex_en) begin
        W_valid <= 1'b0;
        MW_BUS_W <= 'b0;
    end
    else if (MW_valid && W_allowin) begin
        MW_BUS_W <= MW_BUS;
    end
    
    if (W_allowin) begin
        W_valid <= MW_valid;
    end
end

//Wrf BUS
assign Wrf_BUS = {gr_we_W && W_valid && !ex_W,  //37
                  dest_W,                       //36:32
                  final_result_W};              //31:0

//Wcsr BUS
assign Wcsr_BUS = {ex_W && W_valid,     //152
                   ecode_W,             //151:144
                   esubcode_W,          //143
                   csr_we_W && W_valid, //142
                   csr_addr_W,          //141:128
                   csr_wmask_W,         //127:96
                   csr_wdata_W,         //95:64
                   pc_W,                //63:32
                   vaddr_W};            //31:0

//PB BUS
assign PB_BUS = {PB_BUS_W & {`WpD_BUS_Wid{W_valid}},pc_W};

// debug info generate
assign debug_wb_pc       = pc_W;
assign debug_wb_rf_we    = {4{gr_we_W && W_valid && !ex_W}};
assign debug_wb_rf_wnum  = dest_W;
assign debug_wb_rf_wdata = final_result_W;

endmodule
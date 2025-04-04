`timescale 1ns / 1ps
`include "Defines.vh"
module Writeback (
    input                       clk,
    input                       rstn,

    output                      W_allowin,
    output reg                  W_valid,

    input                       MW_valid,
    input  [`MW_BUS_Wid-1:0]    MW_BUS,

    output [`Wrf_BUS_Wid-1:0]   Wrf_BUS,
    output [`Wcsr_BUS_Wid-1:0]  Wcsr_BUS,
    output [`PB_BUS_Wid-1:0]    PB_BUS,

    input  [`CSR2TLB_BUS_MW_Wid-1:0] CSR2TLB_BUS_M,
    input  [`TLB2CSR_BUS_MW_Wid-1:0] TLB2CSR_BUS_M,
    output [`TLB2CSR_BUS_WD_Wid-1:0] TLB2CSR_BUS,

    input                       ex_en,

`ifdef DIFFTEST_EN
    input [`DIFFTEST_RAM_BUS_Wid-1:0] difftest_ram_BUS_M,
    output reg [`DIFFTEST_RAM_BUS_Wid-1:0] difftest_ram_BUS,
`endif

    // invtlb opcode
    output wire                      invtlb_valid,
    output wire [               4:0] invtlb_op,

    // write port
    output wire                      we,     //w(rite) e(nable)
    output wire [$clog2(`TLBNUM)-1:0]w_index,
    output wire                      w_e,
    output wire [              18:0] w_vppn,
    output wire [               5:0] w_ps,
    output wire [               9:0] w_asid,
    output wire                      w_g,
    output wire [              19:0] w_ppn0,
    output wire [               1:0] w_plv0,
    output wire [               1:0] w_mat0,
    output wire                      w_d0,
    output wire                      w_v0,
    output wire [              19:0] w_ppn1,
    output wire [               1:0] w_plv1,
    output wire [               1:0] w_mat1,
    output wire                      w_d1,
    output wire                      w_v1,

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

reg  [`CSR2TLB_BUS_MW_Wid-1:0] CSR2TLB_BUS_W;
reg  [`TLB2CSR_BUS_MW_Wid-1:0] TLB2CSR_BUS_W;
//pipeline handshake
// reg    W_valid;
wire   W_ready_go = 1'b1;
(*max_fanout = 20*)assign W_allowin  = !W_valid || W_ready_go;
always @(posedge clk) begin
    if (!rstn) begin
        MW_BUS_W <= 'b0;
        CSR2TLB_BUS_W <= 'b0;
        TLB2CSR_BUS_W <= 'b0;
    end
    else if (ex_en) begin
        MW_BUS_W <= 'b0;
        CSR2TLB_BUS_W <= 'b0;
        TLB2CSR_BUS_W <= 'b0;
    end
    else if (MW_valid && W_allowin) begin
        MW_BUS_W <= MW_BUS; 
        CSR2TLB_BUS_W <= CSR2TLB_BUS_M;
        TLB2CSR_BUS_W <= TLB2CSR_BUS_M;
    end
end
`ifdef DIFFTEST_EN
always @(posedge clk) begin
    if (!rstn) begin
        difftest_ram_BUS <= 'b0;
    end
    else if (ex_en) begin
        difftest_ram_BUS <= 'b0;
    end
    else if (MW_valid && W_allowin) begin
        difftest_ram_BUS <= difftest_ram_BUS_M;
    end
end
`endif
always @(posedge clk) begin
    if (!rstn) begin
        W_valid <= 1'b0;
    end
    else if (ex_en) begin
        W_valid <= 1'b0;
    end
    else if (W_allowin) begin
        W_valid <= MW_valid;
    end
end

//TLB data
wire we_W;
assign {invtlb_valid,invtlb_op,we_W,w_index,w_e,w_vppn,w_ps,w_asid,w_g,
        w_ppn0,w_plv0,w_mat0,w_d0,w_v0,w_ppn1,w_plv1,w_mat1,w_d1,w_v1} = CSR2TLB_BUS_W;
assign TLB2CSR_BUS = TLB2CSR_BUS_W;

assign we = we_W & W_valid & !ex_W;
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
assign PB_BUS = W_valid ? {PB_BUS_W,pc_W} : 'b0;

// debug info generate
assign debug_wb_pc       = pc_W;
assign debug_wb_rf_we    = {4{gr_we_W && W_valid && !ex_W}};
assign debug_wb_rf_wnum  = dest_W;
assign debug_wb_rf_wdata = final_result_W;

endmodule
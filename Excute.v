`include "Defines.vh"
module Excute (
    input                       clk,
    input                       rstn,

    input                       M_allowin,
    output                      E_allowin,

    input                       DE_valid,
    input   [`DE_BUS_Wid-1:0]   DE_BUS,
    
    output                      EM_valid,
    output  [`EM_BUS_Wid-1:0]   EM_BUS,

    output  [`ED_for_BUS_Wid-1:0]   ED_for_BUS,

    output                      data_sram_en,
    output  [ 3:0]              data_sram_we,
    output  [31:0]              data_sram_addr,
    output  [31:0]              data_sram_wdata
);
    
//DE BUS
reg [`DE_BUS_Wid-1:0] DE_BUS_E;
wire [31:0] pc_E;
wire [`alu_op_Wid-1:0] alu_op_E;
wire [31:0] alu_src1_E;
wire [31:0] alu_src2_E;
wire [31:0] rkd_value_E;
wire        gr_we_E;
wire        mem_we_E;
wire [ 4:0] dest_E;
wire        res_from_mem_E;
wire        stall;

assign {pc_E,alu_op_E,alu_src1_E,alu_src2_E,rkd_value_E,gr_we_E,mem_we_E,dest_E,res_from_mem_E} = DE_BUS_E;

//pipeline handshake
reg    E_valid;
wire   E_ready_go     = 1'b1;
assign E_allowin      = (!E_valid || E_ready_go && M_allowin) && !stall;
assign EM_valid       = E_valid && E_ready_go && !stall;
always @(posedge clk) begin
    if (!rstn) begin
        E_valid <= 1'b0;
        DE_BUS_E <= 'b0;
    end
    else if (E_allowin) begin
        E_valid <= DE_valid;
    end

    if (DE_valid && E_allowin) begin
        DE_BUS_E <= DE_BUS;
    end
end

//ALU
wire [31:0] alu_result_E;

alu u_alu(
    .clk          (clk         ),
    .rstn         (rstn        ),
    .alu_op       (alu_op_E    ),
    .alu_src1     (alu_src1_E  ),
    .alu_src2     (alu_src2_E  ),
    .alu_result   (alu_result_E),
    .div_stall    (stall       )
    );

//data sram manage
assign data_sram_en    = E_valid && (mem_we_E | res_from_mem_E);
assign data_sram_we    = {4{mem_we_E && E_valid}};
assign data_sram_addr  = alu_result_E;
assign data_sram_wdata = rkd_value_E;

//EM BUS
assign EM_BUS = {pc_E,alu_result_E,gr_we_E,dest_E,res_from_mem_E};

//ED forward BUS
assign ED_for_BUS = {res_from_mem_E,dest_E & {5{E_valid && gr_we_E}},alu_result_E};

endmodule
`include "Defines.vh"
module Memory (
    input                       clk,
    input                       rstn,

    input                       W_allowin,
    output                      M_allowin,

    input                       EM_valid,
    input  [`EM_BUS_Wid-1:0]    EM_BUS,

    output [`MD_for_BUS_Wid-1:0] MD_for_BUS,

    input  [31:0]               data_sram_rdata,

    output                      MW_valid,
    output [`MW_BUS_Wid-1:0]    MW_BUS
);

//EM BUS
reg [`EM_BUS_Wid-1:0] EM_BUS_M;
wire [31:0] pc_M;
wire [31:0] alu_result_M;
wire        gr_we_M;
wire [ 4:0] dest_M;
wire        res_from_mem_M;

assign {pc_M,alu_result_M,gr_we_M,dest_M,res_from_mem_M} = EM_BUS_M;

//pipeline handshake
reg    M_valid;
wire   M_ready_go    = 1'b1;
assign M_allowin     = !M_valid || M_ready_go && W_allowin;
assign MW_valid      = M_valid && M_ready_go;
always @(posedge clk) begin
    if (!rstn) begin
        M_valid <= 1'b0;
        EM_BUS_M <= 'b0;
    end
    else if (M_allowin) begin
        M_valid <= EM_valid;
    end

    if (EM_valid && M_allowin) begin
        EM_BUS_M <= EM_BUS;
    end
end

//data sram read manage
wire  [31:0] mem_result_M;
wire  [31:0] final_result_M;
assign mem_result_M   = data_sram_rdata;
assign final_result_M = res_from_mem_M ? mem_result_M : alu_result_M;

//MW BUS
assign MW_BUS = {pc_M,final_result_M,gr_we_M,dest_M};

//MD forward BUS
assign MD_for_BUS = {dest_M & {5{M_valid && gr_we_M}},final_result_M};

endmodule
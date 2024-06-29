`include "Defines.vh"
module Fetch (
    input                           clk,
    input                           rstn,

    input    [`Branch_BUS_Wid-1:0]  Branch_BUS,

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
reg  F_valid;
wire F_valid_next   = rstn;//next cycle valid
wire F_ready_go     = 1'b1;//ready send to next stage
wire F_allowin      = !F_valid || F_ready_go && D_allowin;//allow input data
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

assign pc_en = F_valid_next && F_allowin;
assign pc_next = br_taken ? br_target : pc_reg + 32'd4;

always @(posedge clk) begin
    if(!rstn)begin
        pc_reg <= 32'h1bff_fffc;
    end else if (F_valid_next && F_allowin) begin
        pc_reg <= pc_next;
    end
end

//FD BUS
assign FD_BUS = {inst_sram_addr,pc_en};

//inst sram manage
assign inst_sram_en    = pc_en ; 
assign inst_sram_addr  = pc_next; //virtual
assign inst_sram_we    = 4'b0  ;
assign inst_sram_wdata = 32'b0 ;

    
endmodule
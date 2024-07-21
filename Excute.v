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

    input                       ex_en,

    output                      data_sram_en,
    output  [ 3:0]              data_sram_we,
    output  [31:0]              data_sram_addr,
    output  [31:0]              data_sram_wdata
);
    
//DE BUS
reg [`DE_BUS_Wid-1:0] DE_BUS_E;
wire [`WpD_BUS_Wid-1:0] PB_BUS_E;
wire [31:0] pc_E;
wire [`alu_op_Wid-1:0] alu_op_E;
wire [31:0] alu_src1_E;
wire [31:0] alu_src2_E;
wire [31:0] rkd_value_E;
wire        gr_we_E;
wire [ 3:0] mem_we_E;
wire [ 4:0] dest_E;
wire [ 3:0] res_from_mem_E;
wire        stall;
wire        ex_D;
wire [ 7:0] ecode_D;
wire        esubcode_D;
wire [13:0] csr_addr_E;
wire        csr_we_E;
wire [31:0] csr_rdata_E;
wire [31:0] csr_wmask_E;
wire [31:0] csr_wdata_E;
wire        res_from_csr_E;

assign {PB_BUS_E,pc_E,alu_op_E,alu_src1_E,alu_src2_E,rkd_value_E,gr_we_E,mem_we_E,dest_E,res_from_mem_E,
        ex_D,ecode_D,esubcode_D,csr_addr_E,csr_we_E,csr_rdata_E,csr_wmask_E,csr_wdata_E,res_from_csr_E} = DE_BUS_E;

//pipeline handshake
reg    E_valid;
reg    ex_flag;
wire   ex_E;
wire   E_ready_go     = 1'b1;
assign E_allowin      = (!E_valid || E_ready_go && M_allowin) && !stall;
assign EM_valid       = E_valid && E_ready_go && !stall;
always @(posedge clk) begin
    if (!rstn) begin
        E_valid <= 1'b0;
        DE_BUS_E <= 'b0;
    end
    else if (ex_en) begin
        DE_BUS_E <= 'b0;
    end
    else if (DE_valid && E_allowin) begin
        DE_BUS_E <= DE_BUS;
    end
    
    if (E_allowin) begin
        E_valid <= DE_valid && (!ex_flag && !ex_E && !ex_en);
    end
end

//ALU
wire [31:0] alu_result_E;
wire [`alu_op_Wid-1:0] alu_op = alu_op_E & {`alu_op_Wid{!ex_flag}};

alu u_alu(
    .clk          (clk         ),
    .rstn         (rstn        ),
    .alu_op       (alu_op    ),
    .alu_src1     (alu_src1_E  ),
    .alu_src2     (alu_src2_E  ),
    .alu_result   (alu_result_E),
    .stall        (stall       )
    );

//data sram manage
wire [31:0] vaddr_E = alu_result_E;
assign data_sram_en    = E_valid && (|mem_we_E || |res_from_mem_E);
assign data_sram_we    = E_valid && !ex_E ? mem_we_E[3] ? 4'b1111                          :
                                            mem_we_E[1] ? (vaddr_E[1] ? 4'b1100 : 4'b0011) :
                                            mem_we_E[0] ? (vaddr_E[1] ? vaddr_E[0] ? 4'b1000 : 4'b0100 : vaddr_E[0] ? 4'b0010 : 4'b0001)
                                                        : 4'b0000
                                          : 4'b0000;
assign data_sram_addr  = vaddr_E;
assign data_sram_wdata = mem_we_E[3] ? rkd_value_E            : 
                         mem_we_E[1] ? {2{rkd_value_E[15:0]}} :
                         mem_we_E[0] ? {4{rkd_value_E[7:0]}}  : 32'b0;

//exception manage
wire        ALE        = ((mem_we_E[3] | res_from_mem_E[3])&(|data_sram_addr[1:0])) ||
                         ((mem_we_E[1] | res_from_mem_E[1])&( data_sram_addr[0]  ));
assign      ex_E       = E_valid && (ex_D | ALE);
wire [7:0]  ecode_E    = ~E_valid ? 8'h00       :
                         ex_D     ? ecode_D     :
                         ALE      ? `ECODE_ALE  : 8'b0;
wire        esubcode_E = ex_D     ? esubcode_D  : 1'b0;

always @(posedge clk) begin
    if (!rstn) begin
        ex_flag <= 1'b0;
    end 
    else if (ex_E) begin
        ex_flag <= 1'b1;
    end
    else if (ex_en) begin
        ex_flag <= 1'b0;
    end
end

//regfile wdata from csr
wire [31:0] rf_wdata_E = res_from_csr_E ? csr_rdata_E : alu_result_E;

//EM BUS
assign EM_BUS = {PB_BUS_E,          //261:195
                 pc_E,              //194:163
                 rf_wdata_E,        //162:131
                 gr_we_E,           //130
                 dest_E,            //129:125
                 res_from_mem_E,    //124:121
                 data_sram_addr,    //120:89
                 ex_E,              //88
                 ecode_E,           //87:80
                 esubcode_E,        //79
                 csr_addr_E,        //78:65
                 csr_we_E,          //64
                 csr_wmask_E,       //63:32
                 csr_wdata_E};      //31:0

//ED forward BUS
assign ED_for_BUS = {res_from_mem_E,                    //119:116
                     dest_E & {5{E_valid && gr_we_E}},  //115:111
                     rf_wdata_E,                        //110:79
                     csr_we_E && E_valid,               //78
                     csr_addr_E,                        //77:64
                     csr_wmask_E,                       //63:32
                     csr_wdata_E};                      //31:0

endmodule
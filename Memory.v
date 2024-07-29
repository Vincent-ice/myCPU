`include "Defines.vh"
module Memory (
    input                       clk,
    input                       rstn,

    input                       W_allowin,
    output                      M_allowin,

    input                       EM_valid,
    input  [`EM_BUS_Wid-1:0]    EM_BUS,

    output [`MD_for_BUS_Wid-1:0] MD_for_BUS,

    input                       data_sram_data_ok,
    input  [31:0]               data_sram_rdata,

    input                       ex_en,

    output                      MW_valid,
    output [`MW_BUS_Wid-1:0]    MW_BUS
);

//EM BUS
reg [`EM_BUS_Wid-1:0] EM_BUS_M;
wire [`WpD_BUS_Wid-1:0] PB_BUS_M;
wire [31:0] pc_M;
wire [31:0] rf_wdata_M;
wire        gr_we_M;
wire [ 4:0] dest_M;
wire [ 3:0] res_from_mem_M;
wire [31:0] vaddr_M;
wire        ex_E,ex_M;
wire [ 7:0] ecode_M;
wire        esubcode_M;
wire [13:0] csr_addr_M;
wire        csr_we_M;
wire [31:0] csr_wmask_M;
wire [31:0] csr_wdata_M;

assign {PB_BUS_M,pc_M,rf_wdata_M,gr_we_M,dest_M,res_from_mem_M,vaddr_M,
        ex_E,ecode_M,esubcode_M,csr_addr_M,csr_we_M,csr_wmask_M,csr_wdata_M} = EM_BUS_M;

//pipeline handshake
reg    M_valid;
wire   M_ready_go    = (!ex_M & |res_from_mem_M )? data_sram_data_ok : 1'b1;
assign M_allowin     = !M_valid || M_ready_go && W_allowin;
assign MW_valid      = M_valid && M_ready_go || data_sram_data_ok;
assign ex_M = M_valid && ex_E;
always @(posedge clk) begin
    if (!rstn) begin
        EM_BUS_M <= 'b0;
    end
    else if (ex_en) begin
        EM_BUS_M <= 'b0;
    end
    else if (EM_valid && M_allowin) begin
        EM_BUS_M <= EM_BUS;
    end
end
always @(posedge clk) begin
    if (!rstn) begin
        M_valid <= 1'b0;
    end
    else if (ex_en) begin
        M_valid <= 1'b0;
    end
    else if (M_allowin) begin
        M_valid <= EM_valid && (!ex_M && !ex_en);
    end
end

//data sram read manage
wire  [31:0] mem_result_M;
wire  [31:0] final_result_M;
assign mem_result_M   = res_from_mem_M[3] ? data_sram_rdata                                                                                                                             : 
                        res_from_mem_M[1] ? res_from_mem_M[2] ? (vaddr_M[1] ? {16'b0,data_sram_rdata[31:16]} : {16'b0,data_sram_rdata[15:0]})                                       : 
                                                                (vaddr_M[1] ? {{16{data_sram_rdata[31]}},data_sram_rdata[31:16]} : {{16{data_sram_rdata[15]}},data_sram_rdata[15:0]})   :
                        res_from_mem_M[0] ? res_from_mem_M[2] ? (vaddr_M[1] ? (vaddr_M[0] ? {24'b0,data_sram_rdata[31:24]} : {24'b0,data_sram_rdata[23:16]}) :
                                                                              (vaddr_M[0] ? {24'b0,data_sram_rdata[15: 8]} : {24'b0,data_sram_rdata[ 7:0]}))                        :
                                                                (vaddr_M[1] ? (vaddr_M[0] ? {{24{data_sram_rdata[31]}},data_sram_rdata[31:24]} : {{24{data_sram_rdata[23]}},data_sram_rdata[23:16]}):
                                                                              (vaddr_M[0] ? {{24{data_sram_rdata[15]}},data_sram_rdata[15: 8]} : {{24{data_sram_rdata[ 7]}},data_sram_rdata[ 7: 0]})) 
                                            : 32'b0;
assign final_result_M = |res_from_mem_M ? mem_result_M : rf_wdata_M;

//MW BUS
assign MW_BUS = {PB_BUS_M,      //257:191
                 pc_M,          //190:159
                 final_result_M,//158:127
                 gr_we_M,       //126
                 dest_M,        //125:121
                 vaddr_M,       //120:89
                 ex_M,          //88
                 ecode_M,       //87:80
                 esubcode_M,    //79
                 csr_addr_M,    //78:65
                 csr_we_M,      //64
                 csr_wmask_M,   //63:32
                 csr_wdata_M};  //31:0

//MD forward BUS
assign MD_for_BUS = {dest_M & {5{M_valid && gr_we_M}},  //115:111
                     final_result_M,                    //110:79
                     csr_we_M && M_valid,               //78
                     csr_addr_M,                        //77:64 
                     csr_wmask_M,                       //63:32
                     csr_wdata_M};                      //31:0

endmodule
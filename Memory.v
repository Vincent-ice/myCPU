`include "Defines.vh"
module Memory (
    input                       clk,
    input                       rstn,

    input                       W_allowin,
    output                      M_allowin,

    input                       EM_valid,
    input  [`EM_BUS_Wid-1:0]    EM_BUS,

    output [`MD_for_BUS_Wid-1:0] MD_for_BUS,

    input  [`TLB2CSR_BUS_EM_Wid-1:0] TLB2CSR_BUS_E,
    output [`TLB2CSR_BUS_MW_Wid-1:0] TLB2CSR_BUS,
    input  [`CSR2TLB_BUS_EM_Wid-1:0] CSR2TLB_BUS_E,
    output [`CSR2TLB_BUS_MW_Wid-1:0] CSR2TLB_BUS,

    input  [31:0]               data_sram_rdata,

    input                       ex_en,

    output                      MW_valid,
    output [`MW_BUS_Wid-1:0]    MW_BUS,

    // read port
    output wire [$clog2(`TLBNUM)-1:0] r_index,
    input  wire                      r_e,
    input  wire [              18:0] r_vppn,
    input  wire [               5:0] r_ps,
    input  wire [               9:0] r_asid,
    input  wire                      r_g,
    input  wire [              19:0] r_ppn0,
    input  wire [               1:0] r_plv0,
    input  wire [               1:0] r_mat0,
    input  wire                      r_d0,
    input  wire                      r_v0,
    input  wire [              19:0] r_ppn1,
    input  wire [               1:0] r_plv1,
    input  wire [               1:0] r_mat1,
    input  wire                      r_d1,
    input  wire                      r_v1
);

//EM BUS
reg [`EM_BUS_Wid-1:0] EM_BUS_M;
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

assign {pc_M,rf_wdata_M,gr_we_M,dest_M,res_from_mem_M,vaddr_M,
        ex_E,ecode_M,esubcode_M,csr_addr_M,csr_we_M,csr_wmask_M,csr_wdata_M} = EM_BUS_M;

reg  [`CSR2TLB_BUS_EM_Wid-1:0] CSR2TLB_BUS_M;
reg  [`TLB2CSR_BUS_EM_Wid-1:0] TLB2CSR_BUS_M;
//pipeline handshake
reg    M_valid;
wire   M_ready_go    = 1'b1;
assign M_allowin     = !M_valid || M_ready_go && W_allowin;
assign MW_valid      = M_valid && M_ready_go;
assign ex_M = M_valid && ex_E;
always @(posedge clk) begin
    if (!rstn) begin
        M_valid <= 1'b0;
        EM_BUS_M <= 'b0;
        CSR2TLB_BUS_M <= 'b0;
        TLB2CSR_BUS_M <= 'b0;
    end
    else if (ex_en) begin
        EM_BUS_M <= 'b0;
    end
    else if (M_allowin) begin
        M_valid <= EM_valid && (!ex_M || ex_en);
    end

    if (EM_valid && M_allowin) begin
        EM_BUS_M <= EM_BUS;
        CSR2TLB_BUS_M <= CSR2TLB_BUS_E;
        TLB2CSR_BUS_M <= TLB2CSR_BUS_E;
    end
end

//TLB data
wire        inst_invtlb;
wire [ 4:0] invop;
wire        we;
wire [$clog2(`TLBNUM)-1:0] w_index;
wire        w_e;
wire [18:0] w_vppn;
wire [ 5:0] w_ps;
wire [ 9:0] w_asid;
wire        w_g;
wire [19:0] w_ppn0;
wire [ 1:0] w_plv0;
wire [ 1:0] w_mat0;
wire        w_d0;
wire        w_v0;
wire [19:0] w_ppn1;
wire [ 1:0] w_plv1;
wire [ 1:0] w_mat1;
wire        w_d1;
wire        w_v1;

assign {inst_tlbsrch,inst_tlbrd,inst_invtlb,invop,we,w_index,w_e,w_vppn,w_ps,w_asid,w_g,
        w_ppn0,w_plv0,w_mat0,w_d0,w_v0,w_ppn1,w_plv1,w_mat1,w_d1,w_v1,r_index} = CSR2TLB_BUS_M;
//assign {s1_found,s1_index} = TLB2CSR_BUS_M;

assign CSR2TLB_BUS = {inst_invtlb,invop,we,w_index,w_e,w_vppn,w_ps,w_asid,w_g,
                      w_ppn0,w_plv0,w_mat0,w_d0,w_v0,w_ppn1,w_plv1,w_mat1,w_d1,w_v1};
assign TLB2CSR_BUS = {TLB2CSR_BUS_M,r_e,r_vppn,r_ps,r_asid,r_g,
                      r_ppn0,r_plv0,r_mat0,r_d0,r_v0,r_ppn1,r_plv1,r_mat1,r_d1,r_v1};

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
assign MW_BUS = {pc_M,          //190:159
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
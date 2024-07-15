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

    input   [`CSR2TLB_BUS_DE_Wid-1:0]  CSR2TLB_BUS_D,
    output  [`CSR2TLB_BUS_EM_Wid-1:0]  CSR2TLB_BUS,
    output  [`TLB2CSR_BUS_EM_Wid-1:0]  TLB2CSR_BUS,

    input                       ex_en,

    output                      data_sram_en,
    output  [ 3:0]              data_sram_we,
    output  [31:0]              data_sram_addr,
    output  [31:0]              data_sram_wdata,

    // search port 1 (for load/store)
    output wire [              18:0] s1_vppn,
    output wire                      s1_va_bit12,
    output wire [               9:0] s1_asid,
    input  wire                      s1_found,
    input  wire [$clog2(`TLBNUM)-1:0] s1_index,
    input  wire [              19:0] s1_ppn,
    input  wire [               5:0] s1_ps,
    input  wire [               1:0] s1_plv,
    input  wire [               1:0] s1_mat,
    input  wire                      s1_d,
    input  wire                      s1_v
);
    
//DE BUS
reg [`DE_BUS_Wid-1:0] DE_BUS_E;
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

assign {pc_E,alu_op_E,alu_src1_E,alu_src2_E,rkd_value_E,gr_we_E,mem_we_E,dest_E,res_from_mem_E,
        ex_D,ecode_D,esubcode_D,csr_addr_E,csr_we_E,csr_rdata_E,csr_wmask_E,csr_wdata_E,res_from_csr_E} = DE_BUS_E;

reg  [`CSR2TLB_BUS_DE_Wid-1:0] CSR2TLB_BUS_E;
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
        CSR2TLB_BUS_E <= 'b0;
    end
    else if (E_allowin) begin
        E_valid <= DE_valid && (!ex_flag && !ex_E || ex_en);
    end

    if (DE_valid && E_allowin) begin
        DE_BUS_E <= DE_BUS;
        CSR2TLB_BUS_E <= CSR2TLB_BUS_D;
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

//TLB data
wire [31:0] vaddr_E;
wire        inst_tlbsrch;
wire        inst_tlbrd;
wire        inst_tlbwr;
wire        inst_tlbfill;
wire        inst_invtlb;
wire [ 4:0] invop;
wire        wen;
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
wire [$clog2(`TLBNUM)-1:0] r_index;

assign {inst_tlbsrch,inst_tlbrd,inst_tlbwr,inst_tlbfill,inst_invtlb,invop,wen,w_index,w_e,w_vppn,w_ps,w_asid,w_g,
        w_ppn0,w_plv0,w_mat0,w_d0,w_v0,w_ppn1,w_plv1,w_mat1,w_d1,w_v1,r_index} = CSR2TLB_BUS_E;

assign s1_vppn     = inst_tlbsrch ? w_vppn : vaddr_E[19:1];
assign s1_va_bit12 = inst_tlbsrch ? w_vppn[0] : vaddr_E[0];
assign s1_asid     = w_asid;

assign CSR2TLB_BUS = CSR2TLB_BUS_E;
assign TLB2CSR_BUS = {s1_found,s1_index};

//data sram manage
assign vaddr_E = alu_result_E;
assign data_sram_en    = E_valid && (|mem_we_E || |res_from_mem_E);
assign data_sram_we    = E_valid ? mem_we_E[3] ? 4'b1111                          :
                                   mem_we_E[1] ? (vaddr_E[1] ? 4'b1100 : 4'b0011) :
                                   mem_we_E[0] ? (vaddr_E[1] ? vaddr_E[0] ? 4'b1000 : 4'b0100 : vaddr_E[0] ? 4'b0010 : 4'b0001)
                                               : 4'b0000
                                 : 4'b0000;
assign data_sram_addr  = vaddr_E;
assign data_sram_wdata = mem_we_E[3] ? rkd_value_E            : 
                         mem_we_E[1] ? {2{rkd_value_E[15:0]}} :
                         mem_we_E[0] ? {4{rkd_value_E[7:0]}}  : 32'b0;

//exception manage
wire        ADEM       = ((mem_we_E[3] | res_from_mem_E[3])&(|data_sram_addr[1:0])) ||
                         ((mem_we_E[1] | res_from_mem_E[1])&( data_sram_addr[0]  ));
assign      ex_E       = E_valid && (ex_D | ADEM);
wire [7:0]  ecode_E    = ~E_valid ? 8'h00       :
                         ex_D     ? ecode_D     :
                         ADEM     ? `ECODE_ADEM : 8'b0;
wire        esubcode_E = ex_D     ? esubcode_D  :
                         ADEM     ? `ESUBCODE_ADEM : 1'b0;

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
assign EM_BUS = {pc_E,rf_wdata_E,gr_we_E,dest_E,res_from_mem_E,data_sram_addr,
                 ex_E,ecode_E,esubcode_E,csr_addr_E,csr_we_E,csr_wmask_E,csr_wdata_E};

//ED forward BUS
assign ED_for_BUS = {res_from_mem_E,dest_E & {5{E_valid && gr_we_E}},rf_wdata_E,
                     csr_we_E && E_valid,csr_addr_E,csr_wmask_E,csr_wdata_E};

endmodule
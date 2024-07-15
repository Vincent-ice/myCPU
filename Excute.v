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

    input   [`CSR2FE_BUS_Wid-1:0]      CSR2FE_BUS,
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
    input  wire [$clog2(`TLBNUM)-1:0]s1_index,
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
    else if (ex_en) begin
        DE_BUS_E <= 'b0;
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
wire [`alu_op_Wid-1:0] alu_op = alu_op_E & {`alu_op_Wid{!ex_flag}};

alu u_alu(
    .clk          (clk         ),
    .rstn         (rstn        ),
    .alu_op       (alu_op    ),
    .alu_src1     (alu_src1_E  ),
    .alu_src2     (alu_src2_E  ),
    .alu_result   (alu_result_E),
    .div_stall    (stall       )
    );

//address translation
wire [31:0] vaddr;
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

wire [ 9:0] csr_ASID_ASID;
wire        csr_CRMD_DA;
wire        csr_CRMD_PG;
wire [ 1:0] csr_CRMD_PLV;
wire        csr_DMW0_PLV0;
wire        csr_DMW0_PLV3;
wire [ 2:0] csr_DMW0_VSEG;
wire        csr_DMW1_PLV0;
wire        csr_DMW1_PLV3;
wire [ 2:0] csr_DMW1_VSEG;
assign {csr_ASID_ASID,csr_CRMD_DA,csr_CRMD_PG,csr_CRMD_PLV,
        csr_DMW0_PLV0,csr_DMW0_PLV3,csr_DMW0_VSEG,csr_DMW0_PSEG,
        csr_DMW1_PLV0,csr_DMW1_PLV3,csr_DMW1_VSEG,csr_DMW1_PSEG} = CSR2FE_BUS;

wire        da_hit;
wire        dmw0_hit;
wire        dmw1_hit;
wire        dmw_hit = dmw0_hit || dmw1_hit;
// TLB search
assign vaddr = alu_result_E;
wire [31:0] paddr;
wire [21:0] offset = vaddr[21:0];

assign s1_vppn     = inst_invtlb  ? alu_src2_E[31:13] :
                     inst_tlbsrch ? w_vppn            : 
                     vaddr[31:13];
assign s1_va_bit12 = inst_invtlb  ? alu_src2_E[12]    :
                     inst_tlbsrch ? 1'b0              :
                     vaddr[12];
assign s1_asid     = inst_invtlb  ? alu_src1_E[9:0]   :
                     csr_ASID_ASID;


wire [31:0] tlb_addr = (s1_ps == 6'd12) ? {s1_ppn[19:0], offset[11:0]} :
                                          {s1_ppn[19:10], offset[21:0]};

assign da_hit = (csr_CRMD_DA == 1) && (csr_CRMD_PG == 0);

// DMW
assign dmw0_hit = (csr_CRMD_PLV == 2'b00 && csr_DMW0_PLV0   ||
                   csr_CRMD_PLV == 2'b11 && csr_DMW0_PLV3 ) && (vaddr[31:29] == csr_DMW0_VSEG); 
assign dmw1_hit = (csr_CRMD_PLV == 2'b00 && csr_DMW1_PLV0   ||
                   csr_CRMD_PLV == 2'b11 && csr_DMW1_PLV3 ) && (vaddr[31:29] == csr_DMW1_VSEG); 

wire [31:0] dmw_addr = {32{dmw0_hit}} & {csr_DMW0_PSEG, vaddr[28:0]} |
                       {32{dmw1_hit}} & {csr_DMW1_PSEG, vaddr[28:0]};

// PADDR
assign paddr = da_hit  ? vaddr    :
               dmw_hit ? dmw_addr :
                         tlb_addr ;

//data sram manage
assign data_sram_en    = E_valid && (|mem_we_E || |res_from_mem_E);
assign data_sram_we    = E_valid && !ex_E ? mem_we_E[3] ? 4'b1111                          :
                                            mem_we_E[1] ? (vaddr[1] ? 4'b1100 : 4'b0011) :
                                            mem_we_E[0] ? (vaddr[1] ? vaddr[0] ? 4'b1000 : 4'b0100 : vaddr[0] ? 4'b0010 : 4'b0001)
                                                        : 4'b0000
                                          : 4'b0000;
assign data_sram_addr  = vaddr;
assign data_sram_wdata = mem_we_E[3] ? rkd_value_E            : 
                         mem_we_E[1] ? {2{rkd_value_E[15:0]}} :
                         mem_we_E[0] ? {4{rkd_value_E[7:0]}}  : 32'b0;

//exception manage
wire        ex_ALE        = ((mem_we_E[3] | res_from_mem_E[3])&(|data_sram_addr[1:0])) ||
                         ((mem_we_E[1] | res_from_mem_E[1])&( data_sram_addr[0]  ));
wire        ex_TLBR    = ~da_hit & ~dmw_hit & (mem_we_E | res_from_mem_E) & ~s1_found;
wire        ex_PIL     = ~da_hit & ~dmw_hit & res_from_mem_E & s1_found & ~s1_v;
wire        ex_PIS     = ~da_hit & ~dmw_hit & mem_we_E & s1_found & ~s1_v;
wire        ex_PPI     = ~da_hit & ~dmw_hit & (mem_we_E | res_from_mem_E) & s1_found & s1_v & csr_CRMD_PLV == 2'b11 && s1_plv == 2'b00;            
wire        ex_PME     = ~da_hit & ~dmw_hit & mem_we_E & s1_found & s1_v & ~ex_PPI & ~s1_d;
wire        ex_ADEM    = ~da_hit & ~dmw_hit & (mem_we_E | res_from_mem_E) & csr_CRMD_PLV == 2'b11 & vaddr[31];

assign      ex_E       = E_valid && (ex_D | ex_ALE | ex_TLBR | ex_PIL | ex_PIS | ex_PME | ex_PPI | ex_ADEM);
wire [7:0]  ecode_E    = ~E_valid ? 8'h00       :
                         ex_D     ? ecode_D     :
                         ex_ALE   ? `ECODE_ALE  :
                         ex_TLBR  ? `ECODE_TLBR :
                         ex_PIL   ? `ECODE_PIL  :
                         ex_PIS   ? `ECODE_PIS  :
                         ex_PME   ? `ECODE_PME  :
                         ex_PPI   ? `ECODE_PPI  :
                         ex_ADEM  ? `ECODE_ADEM : 8'b0;
wire        esubcode_E = ex_D     ? esubcode_D  :
                         ex_ADEM  ? 1'b1        : 1'b0;

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

//TLB BUS
assign CSR2TLB_BUS = CSR2TLB_BUS_E;
assign TLB2CSR_BUS = {s1_found,s1_index}; 
endmodule
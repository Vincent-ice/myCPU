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
    output  [13:0]              csr_raddr_forward,
    input   [31:0]              csr_rdata_forward,

    input   [`CSR2FE_BUS_Wid-1:0]      CSR2FE_BUS,
    input   [`CSR2TLB_BUS_DE_Wid-1:0]  CSR2TLB_BUS_D,
    output  [`CSR2TLB_BUS_EM_Wid-1:0]  CSR2TLB_BUS,
    output  [`TLB2CSR_BUS_EM_Wid-1:0]  TLB2CSR_BUS,

    output                      ex_E,
    input                       ex_en,
    output                      predict_error,
    output  [`Branch_BUS_Wid-1:0]  Branch_BUS,

    output                      data_sram_req,
    output reg [ 3:0]           data_sram_wstrb,
    output  [31:0]              data_sram_addr,
    output reg [31:0]           data_sram_wdata,
    output reg [ 1:0]           data_sram_size,
    input   [31:0]              data_sram_rdata,
    input                       data_sram_addr_ok,
    input                       data_sram_data_ok,
    output                      data_sram_wr,

    // search port 1 (for load/store)
    output wire                      st_inst, //to update dirty bit
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
wire [`WpD_BUS_Wid-1:0] PB_BUS_E;
wire [31:0] inst_E;
wire        inst_b,inst_bl,inst_jirl;
wire [31:0] br_offs;
wire        predict_taken;
wire [31:0] predict_target;
wire        inst_beq,inst_bne,inst_bge,inst_blt,inst_bgeu,inst_bltu;
wire [31:0] br_base;
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

assign {inst_E,inst_b,inst_bl,inst_jirl,br_base,predict_taken,predict_target,inst_beq,inst_bne,inst_blt,inst_bge,inst_bltu,inst_bgeu,br_offs,
        pc_E,alu_op_E,alu_src1_E,alu_src2_E,rkd_value_E,gr_we_E,mem_we_E,dest_E,res_from_mem_E,
        ex_D,ecode_D,esubcode_D,csr_addr_E,csr_we_E,csr_rdata_E,csr_wmask_E,csr_wdata_E,res_from_csr_E} = DE_BUS_E;

reg  [`CSR2TLB_BUS_DE_Wid-1:0] CSR2TLB_BUS_E;
//pipeline handshake
reg    E_valid;
reg    ex_flag;
reg    send_handshake;
wire   E_ready_go     = E_valid && !send_handshake && !data_sram_req || data_sram_data_ok || ex_E;
(*max_fanout = 20*)assign E_allowin      = (!E_valid || E_ready_go && M_allowin) && !stall;
(*max_fanout = 20*)assign EM_valid       = E_valid && E_ready_go && !stall;
always @(posedge clk) begin
    if (!rstn) begin
        DE_BUS_E <= 'b0;
        CSR2TLB_BUS_E <= 'b0;
    end
    else if (ex_en) begin
        DE_BUS_E <= 'b0;
        CSR2TLB_BUS_E <= 'b0;
    end
    else if (DE_valid && E_allowin) begin
        DE_BUS_E <= DE_BUS;
        CSR2TLB_BUS_E <= CSR2TLB_BUS_D;
    end
end
always @(posedge clk) begin
    if (!rstn) begin
        E_valid <= 1'b0;
    end
    else if (ex_en) begin
        E_valid <= 1'b0;
    end
    else if (E_allowin) begin
        E_valid <= DE_valid && (!ex_flag && !ex_E && !ex_en) && !predict_error;
    end
end

always @(posedge clk) begin
    if (!rstn) begin
        send_handshake <= 1'b0;
    end
    else if(data_sram_data_ok) begin
        send_handshake <= 1'b0;
    end
    else if(data_sram_addr_ok & data_sram_req) begin
        send_handshake <= 1'b1;
    end
end

//ALU
wire [31:0] alu_result_E;
wire [`alu_op_Wid-1:0] alu_op = alu_op_E & {`alu_op_Wid{!ex_flag}};

alu u_alu(
    .clk          (clk         ),
    .rstn         (rstn        ),
    .alu_op       (alu_op      ),
    .alu_src1     (alu_src1_E  ),
    .alu_src2     (alu_src2_E  ),
    .alu_result   (alu_result_E),
    .stall        (stall       )
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
wire [ 2:0] csr_DMW0_PSEG;
wire        csr_DMW1_PLV0;
wire        csr_DMW1_PLV3;
wire [ 2:0] csr_DMW1_VSEG;
wire [ 2:0] csr_DMW1_PSEG;
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
assign st_inst     = data_sram_req && data_sram_wr;

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
wire        req = E_valid && !ex_E && !send_handshake && (|mem_we_E || |res_from_mem_E);
reg         req_reg;
always @(posedge clk) begin
    if (!rstn) begin
        req_reg <= 1'b0;
    end
    else if (req & !data_sram_addr_ok) begin
        req_reg <= 1'b1;
    end 
    else if (data_sram_addr_ok) begin
        req_reg <= 1'b0;
    end
end
assign data_sram_req = (req | req_reg);

always @(*) begin
    case ({mem_we_E,vaddr[1:0]})
        6'b0001_00 : {data_sram_wstrb,data_sram_size} = 6'b0001_00;
        6'b0001_01 : {data_sram_wstrb,data_sram_size} = 6'b0010_00;
        6'b0001_10 : {data_sram_wstrb,data_sram_size} = 6'b0100_00;
        6'b0001_11 : {data_sram_wstrb,data_sram_size} = 6'b1000_00;
        6'b0011_00 : {data_sram_wstrb,data_sram_size} = 6'b0011_01;
        6'b0011_01 : {data_sram_wstrb,data_sram_size} = 6'b0011_01;
        6'b0011_10 : {data_sram_wstrb,data_sram_size} = 6'b1100_01;
        6'b0011_11 : {data_sram_wstrb,data_sram_size} = 6'b1100_01;
        6'b1111_00 : {data_sram_wstrb,data_sram_size} = 6'b1111_10;
        6'b1111_01 : {data_sram_wstrb,data_sram_size} = 6'b1111_10;
        6'b1111_10 : {data_sram_wstrb,data_sram_size} = 6'b1111_10;
        6'b1111_11 : {data_sram_wstrb,data_sram_size} = 6'b1111_10;
        default    : {data_sram_wstrb,data_sram_size} = 6'b0000_00;
    endcase
end

assign data_sram_addr  = paddr;

always @(*) begin
    case (mem_we_E)
        4'b0001 : data_sram_wdata = {4{rkd_value_E[7:0]}};
        4'b0011 : data_sram_wdata = {2{rkd_value_E[15:0]}};
        4'b1111 : data_sram_wdata = rkd_value_E;
        default : data_sram_wdata = 32'b0;
    endcase
end
assign data_sram_wr = (|mem_we_E);

//exception manage
wire        ex_ALE     = ((mem_we_E[3] | res_from_mem_E[3])&(|vaddr[1:0])) ||
                         ((mem_we_E[1] | res_from_mem_E[1])&( vaddr[0]  ));
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
wire [31:0] badvaddr   = ex_D     ? pc_E        : vaddr;

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
reg  [31:0] rf_wdata_E;
always @(*) begin
    case (1'b1)
        |res_from_mem_E : rf_wdata_E = data_sram_rdata;
        res_from_csr_E  : rf_wdata_E = csr_rdata_E;
        |alu_op_E       : rf_wdata_E = alu_result_E;
        default         : rf_wdata_E = 32'b0;
    endcase
end


//indirect predict branch judge
wire rj_eq_rd = (alu_src1_E == alu_src2_E);
wire rj_lt_rd = ($signed(alu_src1_E) < $signed(alu_src2_E));
wire rj_ltu_rd= (alu_src1_E < alu_src2_E);
reg  br_taken;
wire [31:0] pc_E_plus4;
wire [31:0] br_PC;
wire [31:0] br_target_final;
always @(*) begin
    case (1'b1)
        inst_beq  : br_taken = rj_eq_rd;
        inst_bne  : br_taken = !rj_eq_rd;
        inst_blt  : br_taken = rj_lt_rd;
        inst_bge  : br_taken = !rj_lt_rd;
        inst_bltu : br_taken = rj_ltu_rd;
        inst_bgeu : br_taken = !rj_ltu_rd;
        inst_b    : br_taken = 1'b1;
        inst_bl   : br_taken = 1'b1;
        inst_jirl : br_taken = 1'b1;
        default   : br_taken = 1'b0;
    endcase
end
assign br_PC = br_base + br_offs;
assign br_target_error = (br_PC != predict_target);
assign pc_E_plus4 = pc_E + 32'd4;
assign predict_error = E_valid && (br_taken ^ predict_taken ||
                       br_taken & predict_taken & br_target_error);
assign br_target_final= br_taken ? br_PC : pc_E_plus4;

assign Branch_BUS = {predict_error,br_target_final};

wire        direct_jump   = inst_jirl || inst_b || inst_bl;
wire        indirect_jump = inst_beq || inst_bne || inst_blt || inst_bge || inst_bltu || inst_bgeu;
wire [31:0] br_target     = br_taken ? br_PC : 32'b0;
assign PB_BUS_E = {inst_E,direct_jump,indirect_jump,br_taken,br_target};

//csr forward caculate
wire [31:0] csr_wdata_final;
assign csr_raddr_forward = csr_we_E ? csr_addr_E : 14'b0;
assign csr_wdata_final = (csr_wdata_E & csr_wmask_E) | (~csr_wmask_E & csr_rdata_forward);

//EM BUS
assign EM_BUS = {PB_BUS_E,          //261:195
                 pc_E,              //194:163
                 rf_wdata_E,        //162:131
                 gr_we_E,           //130
                 dest_E,            //129:125
                 res_from_mem_E,    //124:121
                 badvaddr,             //120:89
                 ex_E,              //88
                 ecode_E,           //87:80
                 esubcode_E,        //79
                 csr_addr_E,        //78:65
                 csr_we_E,          //64
                 csr_wmask_E,       //63:32
                 csr_wdata_final};      //31:0

//ED forward BUS
assign ED_for_BUS = {res_from_mem_E,                    //119:116
                     dest_E & {5{E_valid && gr_we_E}},  //115:111
                     rf_wdata_E,                        //110:79
                     csr_we_E && E_valid,               //78
                     csr_addr_E,                        //77:64
                     csr_wmask_E,                       //63:32
                     csr_wdata_final};                      //31:0

//TLB BUS
assign CSR2TLB_BUS = CSR2TLB_BUS_E;
assign TLB2CSR_BUS = {s1_found,s1_index}; 
endmodule
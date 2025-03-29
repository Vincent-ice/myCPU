`timescale 1ns / 1ps

`include "Defines.vh"
module core_top(
    input  wire [7:0]  intrpt  ,
    input  wire        aclk    ,
    input  wire        aresetn ,

    output wire [3 :0] arid   ,
    output wire [31:0] araddr ,
    output wire [7 :0] arlen  ,
    output wire [2 :0] arsize ,
    output wire [1 :0] arburst,
    output wire [1 :0] arlock ,
    output wire [3 :0] arcache,
    output wire [2 :0] arprot ,
    output wire        arvalid,
    input  wire        arready,

    input  wire [3 :0] rid    ,
    input  wire [31:0] rdata  ,
    input  wire [1 :0] rresp  ,
    input  wire        rlast  ,
    input  wire        rvalid ,
    output wire        rready ,

    output wire [3 :0] awid   ,
    output wire [31:0] awaddr ,
    output wire [7 :0] awlen  ,
    output wire [2 :0] awsize ,
    output wire [1 :0] awburst,
    output wire [1 :0] awlock ,
    output wire [3 :0] awcache,
    output wire [2 :0] awprot ,
    output wire        awvalid,
    input  wire        awready,

    output wire [3 :0] wid    ,
    output wire [31:0] wdata  ,
    output wire [3 :0] wstrb  ,
    output wire        wlast  ,
    output wire        wvalid ,
    input  wire        wready ,

    input  wire [3 :0] bid    ,
    input  wire [1 :0] bresp  ,
    input  wire        bvalid ,
    output wire        bready ,
    //debug
    input           break_point,
    input           infor_flag,
    input  [ 4:0]   reg_num,
    output          ws_valid,
    output [31:0]   rf_rdata,
    // trace debug interface
    output wire [31:0] debug0_wb_pc,
    output wire [ 3:0] debug0_wb_rf_wen,
    output wire [ 4:0] debug0_wb_rf_wnum,
    output wire [31:0] debug0_wb_rf_wdata
);

wire                            FpD_valid;
wire [`FpD_BUS_Wid-1:0]         FpD_BUS;
wire                            pDD_valid;
wire [`pDD_BUS_Wid-1:0]         pDD_BUS;
wire                            DE_valid;
wire [`DE_BUS_Wid-1:0]          DE_BUS;
wire [`predict_BUS_Wid-1:0]     predict_BUS;
wire [`Branch_BUS_Wid-1:0]      Branch_BUS;
wire                            EM_valid;
wire [`EM_BUS_Wid-1:0]          EM_BUS;
wire                            MW_valid;
wire [`MW_BUS_Wid-1:0]          MW_BUS;
wire [`ED_for_BUS_Wid-1:0]      ED_for_BUS;
wire [13:0]                     csr_raddr_forward;
wire [31:0]                     csr_rdata_forward;
wire [`MD_for_BUS_Wid-1:0]      MD_for_BUS;
wire                            W_valid;
wire [`Wrf_BUS_Wid-1:0]         Wrf_BUS;
wire [`Wcsr_BUS_Wid-1:0]        Wcsr_BUS;
wire [`PB_BUS_Wid-1:0]          PB_BUS;

wire                            D_allowin;
wire                            E_allowin;
wire                            M_allowin;
wire                            W_allowin;

wire                            ex_D;
wire                            ex_E;
wire                            ex_en;
wire [31:0]                     ex_entryPC;
wire                            ertn_flush;
wire [31:0]                     new_pc;
wire                            TLBR_en;
wire [31:0]                     TLBR_entryPC;

wire                            predict_error;
wire [ 7:0]                     hardware_interrupt;
assign hardware_interrupt = intrpt;
//assign hardware_interrupt = 8'b0;

wire                            inst_sram_req;
wire [ 3:0]                     inst_sram_wstrb;
wire [31:0]                     inst_sram_addr;
wire [31:0]                     inst_sram_wdata;
wire [31:0]                     inst_sram_rdata;
wire [ 1:0]                     inst_sram_size;
wire                            inst_sram_addr_ok;
wire                            inst_sram_data_ok;
wire                            inst_sram_wr;

wire                            data_sram_req;
wire [ 3:0]                     data_sram_wstrb;
wire [31:0]                     data_sram_addr;
wire [31:0]                     data_sram_wdata;
wire [31:0]                     data_sram_rdata;
wire [ 1:0]                     data_sram_size;
wire                            data_sram_addr_ok;
wire                            data_sram_data_ok;
wire                            data_sram_wr;


wire [`CSR2FE_BUS_Wid-1:0]      CSR2FE_BUS;
wire [`CSR2TLB_BUS_DE_Wid-1:0]  CSR2TLB_BUS_DE;
wire [`CSR2TLB_BUS_EM_Wid-1:0]  CSR2TLB_BUS_EM;
wire [`CSR2TLB_BUS_MW_Wid-1:0]  CSR2TLB_BUS_MW;
wire [`TLB2CSR_BUS_EM_Wid-1:0]  TLB2CSR_BUS_EM;
wire [`TLB2CSR_BUS_MW_Wid-1:0]  TLB2CSR_BUS_MW;
wire [`TLB2CSR_BUS_WD_Wid-1:0]  TLB2CSR_BUS_WD;

`ifdef DIFFTEST_EN
wire [`DIFFTEST_RAM_BUS_Wid-1:0] difftest_ram_BUS_EM;
wire [`DIFFTEST_RAM_BUS_Wid-1:0] difftest_ram_BUS_MW;
wire [`DIFFTEST_RAM_BUS_Wid-1:0] difftest_ram_BUS_W;
`endif

wire [               18:0] s0_vppn;
wire                       s0_va_bit12;
wire [                9:0] s0_asid;
wire                       s0_found;
wire [$clog2(`TLBNUM)-1:0] s0_index;
wire [               19:0] s0_ppn;
wire [                5:0] s0_ps;
wire [                1:0] s0_plv;
wire [                1:0] s0_mat;
wire                       s0_d;
wire                       s0_v;
wire                       st_inst;
wire [               18:0] s1_vppn;
wire                       s1_va_bit12;
wire [                9:0] s1_asid;
wire                       s1_found;
wire [$clog2(`TLBNUM)-1:0] s1_index;
wire [               19:0] s1_ppn;
wire [                5:0] s1_ps;
wire [                1:0] s1_plv;
wire [                1:0] s1_mat;
wire                       s1_d;
wire                       s1_v;
wire                       invtlb_valid;
wire [                4:0] invtlb_op;
wire                       we;
wire [$clog2(`TLBNUM)-1:0] w_index;
wire                       w_e;
wire [               18:0] w_vppn;
wire [                5:0] w_ps;
wire [                9:0] w_asid;
wire                       w_g;
wire [               19:0] w_ppn0;
wire [                1:0] w_plv0;
wire [                1:0] w_mat0;
wire                       w_d0;
wire                       w_v0;
wire [               19:0] w_ppn1;
wire [                1:0] w_plv1;
wire [                1:0] w_mat1;
wire                       w_d1;
wire                       w_v1;
wire [$clog2(`TLBNUM)-1:0] r_index;
wire                       r_e;
wire [               18:0] r_vppn;
wire [                5:0] r_ps;
wire [                9:0] r_asid;
wire                       r_g;
wire [               19:0] r_ppn0;
wire [                1:0] r_plv0;
wire [                1:0] r_mat0;
wire                       r_d0;
wire                       r_v0;
wire [               19:0] r_ppn1;
wire [                1:0] r_plv1;
wire [                1:0] r_mat1;
wire                       r_d1;
wire                       r_v1;

cpu_axi_interface u_cpu_axi_interface(
    .clk          (aclk              ),
    .resetn       (aresetn           ),

    .inst_req     (inst_sram_req     ),
    .inst_wr      (inst_sram_wr      ),
    .inst_size    (inst_sram_size    ),
    .inst_addr    (inst_sram_addr    ),
    .inst_wdata   (inst_sram_wdata   ),
    .inst_rdata   (inst_sram_rdata   ),
    .inst_addr_ok (inst_sram_addr_ok ),
    .inst_data_ok (inst_sram_data_ok ),

    .data_req     (data_sram_req     ),
    .data_wr      (data_sram_wr      ),
    .data_size    (data_sram_size    ),
    .data_addr    (data_sram_addr    ),
    .data_wdata   (data_sram_wdata   ),
    .data_rdata   (data_sram_rdata   ),
    .data_addr_ok (data_sram_addr_ok ),
    .data_data_ok (data_sram_data_ok ),

    .arid         (arid          ),
    .araddr       (araddr        ),
    .arlen        (arlen         ),
    .arsize       (arsize        ),
    .arburst      (arburst       ),
    .arlock       (arlock        ),
    .arcache      (arcache       ),
    .arprot       (arprot        ),
    .arvalid      (arvalid       ),
    .arready      (arready       ),

    .rid          (rid           ),
    .rdata        (rdata         ),
    .rresp        (rresp         ),
    .rlast        (rlast         ),
    .rvalid       (rvalid        ),
    .rready       (rready        ),

    .awid         (awid          ),
    .awaddr       (awaddr        ),
    .awlen        (awlen         ),
    .awsize       (awsize        ),
    .awburst      (awburst       ),
    .awlock       (awlock        ),
    .awcache      (awcache       ),
    .awprot       (awprot        ),
    .awvalid      (awvalid       ),
    .awready      (awready       ),

    .wid          (wid           ),
    .wdata        (wdata         ),
    .wstrb        (wstrb         ),
    .wlast        (wlast         ),
    .wvalid       (wvalid        ),
    .wready       (wready        ),
    .bid          (bid           ),
    .bresp        (bresp         ),
    .bvalid       (bvalid        ),
    .bready       (bready        )
);


Fetch u_Fetch(
    .clk             (aclk             ),
    .rstn            (aresetn          ),
    .predict_BUS     (predict_BUS     ),
    .Branch_BUS      (Branch_BUS      ),
    .predict_error   (predict_error   ),
    .ex_D            (ex_D            ),
    .ex_E            (ex_E            ),
    .ex_en_i         (ex_en           ),
    .ex_entryPC      (ex_entryPC      ),
    .ertn_flush_i    (ertn_flush      ),
    .new_pc          (new_pc          ),
    .TLBR_en_i       (TLBR_en         ),
    .TLBR_entryPC    (TLBR_entryPC    ),
    .pD_allowin      (pD_allowin      ),
    .FpD_valid       (FpD_valid       ),
    .FpD_BUS         (FpD_BUS         ),
    .inst_sram_req     (inst_sram_req    ),
    .inst_sram_wstrb   (inst_sram_wstrb  ),
    .inst_sram_addr    (inst_sram_addr   ),
    .inst_sram_wdata   (inst_sram_wdata  ),
    .inst_sram_size    (inst_sram_size   ),
    .inst_sram_addr_ok (inst_sram_addr_ok),
    .inst_sram_data_ok (inst_sram_data_ok),
    .inst_sram_wr      (inst_sram_wr     ),
    .inst_sram_rdata   (inst_sram_rdata  ),
    .CSR2FE_BUS      (CSR2FE_BUS      ),
    .s0_vppn         (s0_vppn         ),
    .s0_va_bit12     (s0_va_bit12     ),
    .s0_asid         (s0_asid         ),
    .s0_found        (s0_found        ),
    .s0_index        (s0_index        ),
    .s0_ppn          (s0_ppn          ),
    .s0_ps           (s0_ps           ),
    .s0_plv          (s0_plv          ),
    .s0_mat          (s0_mat          ),
    .s0_d            (s0_d            ),
    .s0_v            (s0_v            )
);

preDecode u_preDecode(
    .clk             (aclk            ),
    .rstn            (aresetn         ),
    .FpD_valid       (FpD_valid       ),
    .FpD_BUS         (FpD_BUS         ),
    .pDD_valid       (pDD_valid       ),
    .pDD_BUS         (pDD_BUS         ),
    .D_allowin       (D_allowin       ),
    .pD_allowin      (pD_allowin      ),
    .predict_BUS     (predict_BUS     ),
    .PB_BUS          (PB_BUS          ),
    .predict_error   (predict_error   ),
    .ertn_flush      (ertn_flush      ),
    .ex_D            (ex_D            ),
    .ex_E            (ex_E            ),
    .ex_en           (ex_en           )
);

Decode u_Decode(
    .clk                (aclk               ),
    .rstn               (aresetn            ),
    .pDD_valid          (pDD_valid          ),
    .pDD_BUS            (pDD_BUS            ),
    .hardware_interrupt (hardware_interrupt ),
    .E_allowin          (E_allowin          ),
    .D_allowin          (D_allowin          ),
    .ED_for_BUS         (ED_for_BUS         ),
    .MD_for_BUS         (MD_for_BUS         ),
    .Wrf_BUS            (Wrf_BUS            ),
    .Wcsr_BUS           (Wcsr_BUS           ),
    .DE_valid           (DE_valid           ),
    .DE_BUS             (DE_BUS             ),
    .csr_raddr_forward  (csr_raddr_forward  ),
    .csr_rdata_forward  (csr_rdata_forward  ),
    .predict_error      (predict_error      ),
    .ex_D               (ex_D               ),
    .ex_en              (ex_en              ),
    .ex_entryPC         (ex_entryPC         ),
    .ertn_flush         (ertn_flush         ),
    .new_pc             (new_pc             ),
    .TLBR_en            (TLBR_en            ),
    .TLBR_entryPC       (TLBR_entryPC       ),
`ifdef DIFFTEST_EN
    .tlbfill_en         (tlbfill_en         ),
    .tlbfill_rand_index (tlbfill_rand_index ),
    .timer_64_value     (timer_64_diff      ),
    .csr_estat_diff     (csr_estat_diff_0   ),
    .reg_diff           (regs               ),

    .csr_crmd_diff_0         (csr_crmd_diff_0),
    .csr_prmd_diff_0         (csr_prmd_diff_0),
    // output wire     [31:0]  csr_ectl_diff_0     ,
    .csr_estat_diff_0        (csr_estat_diff_0),
    .csr_era_diff_0          (csr_era_diff_0),
    .csr_badv_diff_0         (csr_badv_diff_0),
    .csr_eentry_diff_0       (csr_eentry_diff_0),
    .csr_tlbidx_diff_0       (csr_tlbidx_diff_0),
    .csr_tlbehi_diff_0       (csr_tlbehi_diff_0),
    .csr_tlbelo0_diff_0      (csr_tlbelo0_diff_0),
    .csr_tlbelo1_diff_0      (csr_tlbelo1_diff_0),
    .csr_asid_diff_0         (csr_asid_diff_0),
    .csr_save0_diff_0        (csr_save0_diff_0),
    .csr_save1_diff_0        (csr_save1_diff_0),
    .csr_save2_diff_0        (csr_save2_diff_0),
    .csr_save3_diff_0        (csr_save3_diff_0),
    .csr_tid_diff_0          (csr_tid_diff_0),
    .csr_tcfg_diff_0         (csr_tcfg_diff_0),
    .csr_tval_diff_0         (csr_tval_diff_0),
    .csr_ticlr_diff_0        (csr_ticlr_diff_0),
    .csr_llbctl_diff_0       (csr_llbctl_diff_0),
    .csr_tlbrentry_diff_0    (csr_tlbrentry_diff_0),
    .csr_dmw0_diff_0         (csr_dmw0_diff_0),
    .csr_dmw1_diff_0         (csr_dmw1_diff_0),
    .csr_pgdl_diff_0         (csr_pgdl_diff_0),
    .csr_pgdh_diff_0         (csr_pgdh_diff_0),
`endif
    .TLB2CSR_BUS_W      (TLB2CSR_BUS_WD     ),
    .CSR2TLB_BUS_D      (CSR2TLB_BUS_DE     ),
    .CSR2FE_BUS         (CSR2FE_BUS         )
);

Excute u_Excute(
    .clk             (aclk            ),
    .rstn            (aresetn         ),
    .M_allowin       (M_allowin       ),
    .E_allowin       (E_allowin       ),
    .DE_valid        (DE_valid        ),
    .DE_BUS          (DE_BUS          ),
    .EM_valid        (EM_valid        ),
    .EM_BUS          (EM_BUS          ),
    .ED_for_BUS      (ED_for_BUS      ),
    .csr_raddr_forward(csr_raddr_forward),
    .csr_rdata_forward(csr_rdata_forward),
    .CSR2FE_BUS      (CSR2FE_BUS      ),
    .CSR2TLB_BUS_D   (CSR2TLB_BUS_DE  ),
    .CSR2TLB_BUS     (CSR2TLB_BUS_EM  ),
    .TLB2CSR_BUS     (TLB2CSR_BUS_EM  ),
    .ex_E            (ex_E            ),
    .ex_en           (ex_en           ),
    .predict_error   (predict_error   ),
    .Branch_BUS      (Branch_BUS      ),
    .data_sram_req    (data_sram_req    ),
    .data_sram_wr     (data_sram_wr     ),
    .data_sram_size   (data_sram_size   ),
    .data_sram_wstrb  (data_sram_wstrb  ),
    .data_sram_addr   (data_sram_addr   ),
    .data_sram_wdata  (data_sram_wdata  ),
    .data_sram_rdata  (data_sram_rdata  ),
    .data_sram_addr_ok(data_sram_addr_ok),
    .data_sram_data_ok(data_sram_data_ok),
`ifdef DIFFTEST_EN
    .difftest_ram_BUS (difftest_ram_BUS_EM),
`endif
    .st_inst         (st_inst         ),
    .s1_vppn         (s1_vppn         ),
    .s1_va_bit12     (s1_va_bit12     ),
    .s1_asid         (s1_asid         ),
    .s1_found        (s1_found        ),
    .s1_index        (s1_index        ),
    .s1_ppn          (s1_ppn          ),
    .s1_ps           (s1_ps           ),
    .s1_plv          (s1_plv          ),
    .s1_mat          (s1_mat          ),
    .s1_d            (s1_d            ),
    .s1_v            (s1_v            )
);

Memory u_Memory(
    .clk             (aclk            ),
    .rstn            (aresetn         ),
    .W_allowin       (W_allowin       ),
    .M_allowin       (M_allowin       ),
    .EM_valid        (EM_valid        ),
    .EM_BUS          (EM_BUS          ),
    .MD_for_BUS      (MD_for_BUS      ),
    .TLB2CSR_BUS_E   (TLB2CSR_BUS_EM  ),
    .TLB2CSR_BUS     (TLB2CSR_BUS_MW  ),
    .CSR2TLB_BUS_E   (CSR2TLB_BUS_EM  ),
    .CSR2TLB_BUS     (CSR2TLB_BUS_MW  ),
    .ex_en           (ex_en           ),
    .MW_valid        (MW_valid        ),
    .MW_BUS          (MW_BUS          ),
`ifdef DIFFTEST_EN
    .difftest_ram_BUS_E(difftest_ram_BUS_EM),
    .difftest_ram_BUS  (difftest_ram_BUS_MW),
`endif
    .r_index         (r_index         ),
    .r_e             (r_e             ),
    .r_vppn          (r_vppn          ),
    .r_ps            (r_ps            ),
    .r_asid          (r_asid          ),
    .r_g             (r_g             ),
    .r_ppn0          (r_ppn0          ),
    .r_plv0          (r_plv0          ),
    .r_mat0          (r_mat0          ),
    .r_d0            (r_d0            ),
    .r_v0            (r_v0            ),
    .r_ppn1          (r_ppn1          ),
    .r_plv1          (r_plv1          ),
    .r_mat1          (r_mat1          ),
    .r_d1            (r_d1            ),
    .r_v1            (r_v1            )
);
    
Writeback u_Writeback(
    .clk               (aclk              ),
    .rstn              (aresetn           ),
    .W_allowin         (W_allowin         ),
    .W_valid           (W_valid           ),
    .MW_valid          (MW_valid          ),
    .MW_BUS            (MW_BUS            ),
    .Wrf_BUS           (Wrf_BUS           ),
    .Wcsr_BUS          (Wcsr_BUS          ),
    .PB_BUS            (PB_BUS            ),
    .CSR2TLB_BUS_M     (CSR2TLB_BUS_MW    ),
    .TLB2CSR_BUS_M     (TLB2CSR_BUS_MW    ),
    .TLB2CSR_BUS       (TLB2CSR_BUS_WD    ),
    .ex_en             (ex_en             ),
`ifdef DIFFTEST_EN
    .difftest_ram_BUS_M(difftest_ram_BUS_MW),
    .difftest_ram_BUS  (difftest_ram_BUS_W),
`endif
    .invtlb_valid      (invtlb_valid      ),
    .invtlb_op         (invtlb_op         ),
    .we                (we                ),
    .w_index           (w_index           ),
    .w_e               (w_e               ),
    .w_vppn            (w_vppn            ),
    .w_ps              (w_ps              ),
    .w_asid            (w_asid            ),
    .w_g               (w_g               ),
    .w_ppn0            (w_ppn0            ),
    .w_plv0            (w_plv0            ),
    .w_mat0            (w_mat0            ),
    .w_d0              (w_d0              ),
    .w_v0              (w_v0              ),
    .w_ppn1            (w_ppn1            ),
    .w_plv1            (w_plv1            ),
    .w_mat1            (w_mat1            ),
    .w_d1              (w_d1              ),
    .w_v1              (w_v1              ),

    .debug_wb_pc       (debug0_wb_pc      ),
    .debug_wb_rf_we    (debug0_wb_rf_wen  ),
    .debug_wb_rf_wnum  (debug0_wb_rf_wnum ),
    .debug_wb_rf_wdata (debug0_wb_rf_wdata)
);

tlb #(`TLBNUM) u_tlb(
    .clk          (aclk        ),
    .rstn         (aresetn     ),
    .s0_vppn      (s0_vppn     ),
    .s0_va_bit12  (s0_va_bit12 ),
    .s0_asid      (s0_asid     ),
    .s0_found     (s0_found    ),
    .s0_index     (s0_index    ),
    .s0_ppn       (s0_ppn      ),
    .s0_ps        (s0_ps       ),
    .s0_plv       (s0_plv      ),
    .s0_mat       (s0_mat      ),
    .s0_d         (s0_d        ),
    .s0_v         (s0_v        ),

    .st_inst      (st_inst     ),
    .s1_vppn      (s1_vppn     ),
    .s1_va_bit12  (s1_va_bit12 ),
    .s1_asid      (s1_asid     ),
    .s1_found     (s1_found    ),
    .s1_index     (s1_index    ),
    .s1_ppn       (s1_ppn      ),
    .s1_ps        (s1_ps       ),
    .s1_plv       (s1_plv      ),
    .s1_mat       (s1_mat      ),
    .s1_d         (s1_d        ),
    .s1_v         (s1_v        ),

    .invtlb_valid (invtlb_valid),
    .invtlb_op    (invtlb_op   ),

    .we           (we          ),
    .w_index      (w_index     ),
    .w_e          (w_e         ),
    .w_vppn       (w_vppn      ),
    .w_ps         (w_ps        ),
    .w_asid       (w_asid      ),
    .w_g          (w_g         ),
    .w_ppn0       (w_ppn0      ),
    .w_plv0       (w_plv0      ),
    .w_mat0       (w_mat0      ),
    .w_d0         (w_d0        ),
    .w_v0         (w_v0        ),
    .w_ppn1       (w_ppn1      ),
    .w_plv1       (w_plv1      ),
    .w_mat1       (w_mat1      ),
    .w_d1         (w_d1        ),
    .w_v1         (w_v1        ),

    .r_index      (r_index     ),
    .r_e          (r_e         ),
    .r_vppn       (r_vppn      ),
    .r_ps         (r_ps        ),
    .r_asid       (r_asid      ),
    .r_g          (r_g         ),
    .r_ppn0       (r_ppn0      ),
    .r_plv0       (r_plv0      ),
    .r_mat0       (r_mat0      ),
    .r_d0         (r_d0        ),
    .r_v0         (r_v0        ),
    .r_ppn1       (r_ppn1      ),
    .r_plv1       (r_plv1      ),
    .r_mat1       (r_mat1      ),
    .r_d1         (r_d1        ),
    .r_v1         (r_v1        )
);

`ifdef DIFFTEST_EN
// difftest
// from wb_stage
wire            ws_valid_diff = W_valid;
wire            cnt_inst_diff       ;
wire    [63:0]  timer_64_diff       ;
wire    [ 7:0]  inst_ld_en_diff     ;
wire    [ 7:0]  inst_st_en_diff     ;
wire    [31:0]  st_data_diff        ;
wire            csr_rstat_en_diff   ;
wire    [31:0]  csr_data_diff       ;

wire inst_valid_diff = ws_valid_diff;
reg             cmt_valid           ;
reg             cmt_cnt_inst        ;
reg     [63:0]  cmt_timer_64        ;
reg     [ 7:0]  cmt_inst_ld_en      ;
reg     [31:0]  cmt_ld_paddr        ;
reg     [31:0]  cmt_ld_vaddr        ;
reg     [ 7:0]  cmt_inst_st_en      ;
reg     [31:0]  cmt_st_paddr        ;
reg     [31:0]  cmt_st_vaddr        ;
reg     [31:0]  cmt_st_data         ;
reg             cmt_csr_rstat_en    ;
reg     [31:0]  cmt_csr_data        ;

reg             cmt_wen             ;
reg     [ 7:0]  cmt_wdest           ;
reg     [31:0]  cmt_wdata           ;
reg     [31:0]  cmt_pc              ;
reg     [31:0]  cmt_inst            ;

reg             cmt_excp_flush      ;
reg             cmt_ertn            ;
reg     [5:0]   cmt_csr_ecode       ;
reg             cmt_tlbfill_en      ;
reg     [4:0]   cmt_rand_index      ;

// to difftest debug
reg             trap                ;
reg     [ 7:0]  trap_code           ;
reg     [63:0]  cycleCnt            ;
reg     [63:0]  instrCnt            ;

// from regfile
wire    [31:0]  regs[31:0]          ;

// from csr
wire    [31:0]  csr_crmd_diff_0     ;
wire    [31:0]  csr_prmd_diff_0     ;
wire    [31:0]  csr_ectl_diff_0     ;
wire    [31:0]  csr_estat_diff_0    ;
wire    [31:0]  csr_era_diff_0      ;
wire    [31:0]  csr_badv_diff_0     ;
wire	[31:0]  csr_eentry_diff_0   ;
wire 	[31:0]  csr_tlbidx_diff_0   ;
wire 	[31:0]  csr_tlbehi_diff_0   ;
wire 	[31:0]  csr_tlbelo0_diff_0  ;
wire 	[31:0]  csr_tlbelo1_diff_0  ;
wire 	[31:0]  csr_asid_diff_0     ;
wire 	[31:0]  csr_save0_diff_0    ;
wire 	[31:0]  csr_save1_diff_0    ;
wire 	[31:0]  csr_save2_diff_0    ;
wire 	[31:0]  csr_save3_diff_0    ;
wire 	[31:0]  csr_tid_diff_0      ;
wire 	[31:0]  csr_tcfg_diff_0     ;
wire 	[31:0]  csr_tval_diff_0     ;
wire 	[31:0]  csr_ticlr_diff_0    ;
wire 	[31:0]  csr_llbctl_diff_0   ;
wire 	[31:0]  csr_tlbrentry_diff_0;
wire 	[31:0]  csr_dmw0_diff_0     ;
wire 	[31:0]  csr_dmw1_diff_0     ;
wire 	[31:0]  csr_pgdl_diff_0     ;
wire 	[31:0]  csr_pgdh_diff_0     ;

// from tlb
wire            tlbfill_en          ;
wire [$clog2(`TLBNUM):0] tlbfill_rand_index;

wire    [31:0]  debug0_wb_inst      ;
assign debug0_wb_inst = PB_BUS[`PB_BUS_Wid-1:`PB_BUS_Wid-32];
assign csr_rstat_en_diff = (debug0_wb_inst[31:24] == 8'b00000100) && (debug0_wb_inst[23:10] == 14'h05);

wire            excp_flush          ;
wire            ertn_flush_diff     ;
wire    [5:0]   ws_csr_ecode        ;
assign excp_flush = Wcsr_BUS[152];
assign ertn_flush_diff = debug0_wb_inst == 32'h06483800;
assign ws_csr_ecode = Wcsr_BUS[149:144];

// from memory
wire    [31:0]  vaddr_diff          ;
wire    [31:0]  paddr_diff          ;
assign {inst_st_en_diff,inst_ld_en_diff,vaddr_diff,paddr_diff,st_data_diff} = difftest_ram_BUS_W;

always @(posedge aclk) begin
    if (!aresetn) begin
        {cmt_valid, cmt_cnt_inst, cmt_timer_64, cmt_inst_ld_en, cmt_ld_paddr, cmt_ld_vaddr, cmt_inst_st_en, cmt_st_paddr, cmt_st_vaddr, cmt_st_data, cmt_csr_rstat_en, cmt_csr_data} <= 0;
        {cmt_wen, cmt_wdest, cmt_wdata, cmt_pc, cmt_inst} <= 0;
        {trap, trap_code, cycleCnt, instrCnt} <= 0;
    end else if (~trap) begin
        cmt_valid       <= inst_valid_diff          ;
        cmt_cnt_inst    <= cnt_inst_diff            ;
        cmt_timer_64    <= timer_64_diff            ;
        cmt_inst_ld_en  <= inst_ld_en_diff          ;
        cmt_ld_paddr    <= paddr_diff               ;
        cmt_ld_vaddr    <= vaddr_diff               ;
        cmt_inst_st_en  <= inst_st_en_diff          ;
        cmt_st_paddr    <= paddr_diff               ;
        cmt_st_vaddr    <= vaddr_diff               ;
        cmt_st_data     <= st_data_diff             ;
        cmt_csr_rstat_en<= csr_rstat_en_diff        ;
        cmt_csr_data    <= csr_data_diff            ;

        cmt_wen     <=  debug0_wb_rf_wen            ;
        cmt_wdest   <=  {3'd0, debug0_wb_rf_wnum}   ;
        cmt_wdata   <=  debug0_wb_rf_wdata          ;
        cmt_pc      <=  debug0_wb_pc                ;
        cmt_inst    <=  debug0_wb_inst              ;

        cmt_excp_flush  <= excp_flush               ;
        cmt_ertn        <= ertn_flush_diff          ;
        cmt_csr_ecode   <= ws_csr_ecode             ;
        cmt_tlbfill_en  <= tlbfill_en               ;
        cmt_rand_index  <= tlbfill_rand_index       ;

        trap            <= 0                        ;
        trap_code       <= regs[10][7:0]            ;
        cycleCnt        <= cycleCnt + 1             ;
        instrCnt        <= instrCnt + inst_valid_diff;
    end
end

DifftestInstrCommit DifftestInstrCommit(
    .clock              (aclk           ),
    .coreid             (0              ),
    .index              (0              ),
    .valid              (cmt_valid      ),
    .pc                 (cmt_pc         ),
    .instr              (cmt_inst       ),
    .skip               (0              ),
    .is_TLBFILL         (cmt_tlbfill_en ),
    .TLBFILL_index      (cmt_rand_index ),
    .is_CNTinst         (cmt_cnt_inst   ),
    .timer_64_value     (cmt_timer_64   ),
    .wen                (cmt_wen        ),
    .wdest              (cmt_wdest      ),
    .wdata              (cmt_wdata      ),
    .csr_rstat          (cmt_csr_rstat_en),
    .csr_data           (csr_estat_diff_0)
);

DifftestExcpEvent DifftestExcpEvent(
    .clock              (aclk           ),
    .coreid             (0              ),
    .excp_valid         (cmt_excp_flush ),
    .eret               (cmt_ertn       ),
    .intrNo             (csr_estat_diff_0[12:2]),
    .cause              (cmt_csr_ecode  ),
    .exceptionPC        (cmt_pc         ),
    .exceptionInst      (cmt_inst       )
);

DifftestTrapEvent DifftestTrapEvent(
    .clock              (aclk           ),
    .coreid             (0              ),
    .valid              (trap           ),
    .code               (trap_code      ),
    .pc                 (cmt_pc         ),
    .cycleCnt           (cycleCnt       ),
    .instrCnt           (instrCnt       )
);

DifftestStoreEvent DifftestStoreEvent(
    .clock              (aclk           ),
    .coreid             (0              ),
    .index              (0              ),
    .valid              (cmt_inst_st_en ),
    .storePAddr         (cmt_st_paddr   ),
    .storeVAddr         (cmt_st_vaddr   ),
    .storeData          (cmt_st_data    )
);

DifftestLoadEvent DifftestLoadEvent(
    .clock              (aclk           ),
    .coreid             (0              ),
    .index              (0              ),
    .valid              (cmt_inst_ld_en ),
    .paddr              (cmt_ld_paddr   ),
    .vaddr              (cmt_ld_vaddr   )
);

DifftestCSRRegState DifftestCSRRegState(
    .clock              (aclk               ),
    .coreid             (0                  ),
    .crmd               (csr_crmd_diff_0    ),
    .prmd               (csr_prmd_diff_0    ),
    .euen               (0                  ),
    .ecfg               (csr_ectl_diff_0    ),
    .estat              (csr_estat_diff_0   ),
    .era                (csr_era_diff_0     ),
    .badv               (csr_badv_diff_0    ),
    .eentry             (csr_eentry_diff_0  ),
    .tlbidx             (csr_tlbidx_diff_0  ),
    .tlbehi             (csr_tlbehi_diff_0  ),
    .tlbelo0            (csr_tlbelo0_diff_0 ),
    .tlbelo1            (csr_tlbelo1_diff_0 ),
    .asid               (csr_asid_diff_0    ),
    .pgdl               (csr_pgdl_diff_0    ),
    .pgdh               (csr_pgdh_diff_0    ),
    .save0              (csr_save0_diff_0   ),
    .save1              (csr_save1_diff_0   ),
    .save2              (csr_save2_diff_0   ),
    .save3              (csr_save3_diff_0   ),
    .tid                (csr_tid_diff_0     ),
    .tcfg               (csr_tcfg_diff_0    ),
    .tval               (csr_tval_diff_0    ),
    .ticlr              (csr_ticlr_diff_0   ),
    .llbctl             (csr_llbctl_diff_0  ),
    .tlbrentry          (csr_tlbrentry_diff_0),
    .dmw0               (csr_dmw0_diff_0    ),
    .dmw1               (csr_dmw1_diff_0    )
);

DifftestGRegState DifftestGRegState(
    .clock              (aclk       ),
    .coreid             (0          ),
    .gpr_0              (0          ),
    .gpr_1              (regs[1]    ),
    .gpr_2              (regs[2]    ),
    .gpr_3              (regs[3]    ),
    .gpr_4              (regs[4]    ),
    .gpr_5              (regs[5]    ),
    .gpr_6              (regs[6]    ),
    .gpr_7              (regs[7]    ),
    .gpr_8              (regs[8]    ),
    .gpr_9              (regs[9]    ),
    .gpr_10             (regs[10]   ),
    .gpr_11             (regs[11]   ),
    .gpr_12             (regs[12]   ),
    .gpr_13             (regs[13]   ),
    .gpr_14             (regs[14]   ),
    .gpr_15             (regs[15]   ),
    .gpr_16             (regs[16]   ),
    .gpr_17             (regs[17]   ),
    .gpr_18             (regs[18]   ),
    .gpr_19             (regs[19]   ),
    .gpr_20             (regs[20]   ),
    .gpr_21             (regs[21]   ),
    .gpr_22             (regs[22]   ),
    .gpr_23             (regs[23]   ),
    .gpr_24             (regs[24]   ),
    .gpr_25             (regs[25]   ),
    .gpr_26             (regs[26]   ),
    .gpr_27             (regs[27]   ),
    .gpr_28             (regs[28]   ),
    .gpr_29             (regs[29]   ),
    .gpr_30             (regs[30]   ),
    .gpr_31             (regs[31]   )
);
`endif

endmodule
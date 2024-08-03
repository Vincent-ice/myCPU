`include "Defines.vh"
module mycpu_top(
    input  wire [7:0]  ext_int ,
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
    // trace debug interface
    output wire [31:0] debug_wb_pc,
    output wire [ 3:0] debug_wb_rf_we,
    output wire [ 4:0] debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata
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
assign hardware_interrupt = ext_int;
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
    .data_sram_data_ok(data_sram_data_ok)
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
    .MW_valid          (MW_valid          ),
    .MW_BUS            (MW_BUS            ),
    .Wrf_BUS           (Wrf_BUS           ),
    .Wcsr_BUS          (Wcsr_BUS          ),
    .PB_BUS            (PB_BUS            ),
    .CSR2TLB_BUS_M     (CSR2TLB_BUS_MW    ),
    .TLB2CSR_BUS_M     (TLB2CSR_BUS_MW    ),
    .TLB2CSR_BUS       (TLB2CSR_BUS_WD    ),
    .ex_en             (ex_en             ),

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

    .debug_wb_pc       (debug_wb_pc       ),
    .debug_wb_rf_we    (debug_wb_rf_we    ),
    .debug_wb_rf_wnum  (debug_wb_rf_wnum  ),
    .debug_wb_rf_wdata (debug_wb_rf_wdata )
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


endmodule
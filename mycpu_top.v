`include "Defines.vh"
module mycpu_top(
    input  wire        clk,
    input  wire        resetn,
    // inst sram interface
    output wire        inst_sram_en,
    output wire [ 3:0] inst_sram_we,
    output wire [31:0] inst_sram_addr,
    output wire [31:0] inst_sram_wdata,
    input  wire [31:0] inst_sram_rdata,
    // data sram interface
    output wire        data_sram_en,
    output wire [ 3:0] data_sram_we,
    output wire [31:0] data_sram_addr,
    output wire [31:0] data_sram_wdata,
    input  wire [31:0] data_sram_rdata,
    // trace debug interface
    output wire [31:0] debug_wb_pc,
    output wire [ 3:0] debug_wb_rf_we,
    output wire [ 4:0] debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata
);

wire                            FD_valid;
wire [`FD_BUS_Wid-1:0]          FD_BUS;
wire                            DE_valid;
wire [`DE_BUS_Wid-1:0]          DE_BUS;
wire [`Branch_BUS_Wid-1:0]      Branch_BUS;
wire                            EM_valid;
wire [`EM_BUS_Wid-1:0]          EM_BUS;
wire                            MW_valid;
wire [`MW_BUS_Wid-1:0]          MW_BUS;
wire [`ED_for_BUS_Wid-1:0]      ED_for_BUS;
wire [`MD_for_BUS_Wid-1:0]      MD_for_BUS;
wire [`Wrf_BUS_Wid-1:0]         Wrf_BUS;
wire [`Wcsr_BUS_Wid-1:0]        Wcsr_BUS;

wire                            D_allowin;
wire                            E_allowin;
wire                            M_allowin;
wire                            W_allowin;

wire                            ex_en;
wire [31:0]                     ex_entryPC;
wire                            ertn_flush;
wire [31:0]                     new_pc;

wire [ 7:0]                     hardware_interrupt = 8'b0;

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


Fetch u_Fetch(
    .clk             (clk             ),
    .rstn            (resetn          ),
    .Branch_BUS      (Branch_BUS      ),
    .ex_en           (ex_en           ),
    .ex_entryPC      (ex_entryPC      ),
    .ertn_flush      (ertn_flush      ),
    .new_pc          (new_pc          ),
    .D_allowin       (D_allowin       ),
    .FD_valid        (FD_valid        ),
    .FD_BUS          (FD_BUS          ),
    .inst_sram_en    (inst_sram_en    ),
    .inst_sram_we    (inst_sram_we    ),
    .inst_sram_addr  (inst_sram_addr  ),
    .inst_sram_wdata (inst_sram_wdata ),
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

Decode u_Decode(
    .clk                (clk                ),
    .rstn               (resetn             ),
    .FD_valid           (FD_valid           ),
    .FD_BUS             (FD_BUS             ),
    .inst_sram_rdata    (inst_sram_rdata    ),
    .hardware_interrupt (hardware_interrupt ),
    .E_allowin          (E_allowin          ),
    .D_allowin          (D_allowin          ),
    .ED_for_BUS         (ED_for_BUS         ),
    .MD_for_BUS         (MD_for_BUS         ),
    .Wrf_BUS            (Wrf_BUS            ),
    .Wcsr_BUS           (Wcsr_BUS           ),
    .DE_valid           (DE_valid           ),
    .DE_BUS             (DE_BUS             ),
    .Branch_BUS         (Branch_BUS         ),
    .ex_en              (ex_en              ),
    .ex_entryPC         (ex_entryPC         ),
    .ertn_flush         (ertn_flush         ),
    .new_pc             (new_pc             ),
    .TLB2CSR_BUS_W      (TLB2CSR_BUS_WD     ),
    .CSR2TLB_BUS_D      (CSR2TLB_BUS_DE     ),
    .CSR2FE_BUS         (CSR2FE_BUS         )
);

Excute u_Excute(
    .clk             (clk             ),
    .rstn            (resetn          ),
    .M_allowin       (M_allowin       ),
    .E_allowin       (E_allowin       ),
    .DE_valid        (DE_valid        ),
    .DE_BUS          (DE_BUS          ),
    .EM_valid        (EM_valid        ),
    .EM_BUS          (EM_BUS          ),
    .ED_for_BUS      (ED_for_BUS      ),
    .CSR2FE_BUS      (CSR2FE_BUS      ),
    .CSR2TLB_BUS_D   (CSR2TLB_BUS_DE  ),
    .CSR2TLB_BUS     (CSR2TLB_BUS_EM  ),
    .TLB2CSR_BUS     (TLB2CSR_BUS_EM  ),
    .ex_en           (ex_en           ),
    .data_sram_en    (data_sram_en    ),
    .data_sram_we    (data_sram_we    ),
    .data_sram_addr  (data_sram_addr  ),
    .data_sram_wdata (data_sram_wdata ),
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
    .clk             (clk             ),
    .rstn            (resetn          ),
    .W_allowin       (W_allowin       ),
    .M_allowin       (M_allowin       ),
    .EM_valid        (EM_valid        ),
    .EM_BUS          (EM_BUS          ),
    .MD_for_BUS      (MD_for_BUS      ),
    .TLB2CSR_BUS_E   (TLB2CSR_BUS_EM  ),
    .TLB2CSR_BUS     (TLB2CSR_BUS_MW  ),
    .CSR2TLB_BUS_E   (CSR2TLB_BUS_EM  ),
    .CSR2TLB_BUS     (CSR2TLB_BUS_MW  ),
    .data_sram_rdata (data_sram_rdata ),
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
    .clk               (clk               ),
    .rstn              (resetn            ),
    .W_allowin         (W_allowin         ),
    .MW_valid          (MW_valid          ),
    .MW_BUS            (MW_BUS            ),
    .Wrf_BUS           (Wrf_BUS           ),
    .Wcsr_BUS          (Wcsr_BUS          ),
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
    .clk          (clk         ),
    .rstn         (resetn      ),
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
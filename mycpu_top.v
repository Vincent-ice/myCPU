`include "Defines.vh"
module mycpu_top(
    input  wire        clk,
    input  wire        resetn,
    // inst sram interface
    input wire         inst_sram_req,
    input wire  [ 3:0] inst_sram_wstrb,
    input wire  [31:0] inst_sram_addr,
    input wire  [31:0] inst_sram_wdata,
    input wire  [31:0] inst_sram_rdata,
    input wire  [ 1:0] inst_sram_size,
    input wire         inst_sram_addr_ok,
    input wire         inst_sram_data_ok,
    input wire         inst_sram_wr,
    // data sram interface
    input wire         data_sram_req,
    input wire  [ 3:0] data_sram_wstrb,
    input wire  [31:0] data_sram_addr,
    input wire  [31:0] data_sram_wdata,
    input wire  [31:0] data_sram_rdata,
    input wire  [ 1:0] data_sram_size,
    input wire         data_sram_addr_ok,
    input wire         data_sram_data_ok,
    input wire         data_sram_wr,
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
wire [`Branch_BUS_Wid-1:0]      Branch_BUS_D;
wire [`Branch_BUS_Wid-1:0]      Branch_BUS_E;
wire                            EM_valid;
wire [`EM_BUS_Wid-1:0]          EM_BUS;
wire                            MW_valid;
wire [`MW_BUS_Wid-1:0]          MW_BUS;
wire [`ED_for_BUS_Wid-1:0]      ED_for_BUS;
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

wire                            BTB_stall;
wire                            predict_error_D;
wire                            predict_error_E;
wire [ 7:0]                     hardware_interrupt = 8'b0;

Fetch u_Fetch(
    .clk             (clk             ),
    .rstn            (resetn          ),
    .predict_BUS     (predict_BUS     ),
    .Branch_BUS_D    (Branch_BUS_D    ),
    .Branch_BUS_E    (Branch_BUS_E    ),
    .ex_D            (ex_D            ),
    .ex_E            (ex_E            ),
    .ex_en_i         (ex_en           ),
    .ex_entryPC      (ex_entryPC      ),
    .ertn_flush_i    (ertn_flush      ),
    .new_pc          (new_pc          ),
    .BTB_stall       (BTB_stall       ),
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
    .inst_sram_rdata   (inst_sram_rdata  )
);

preDecode u_preDecode(
    .clk             (clk             ),
    .rstn            (resetn          ),
    .FpD_valid       (FpD_valid       ),
    .FpD_BUS         (FpD_BUS         ),
    .pDD_valid       (pDD_valid       ),
    .pDD_BUS         (pDD_BUS         ),
    .D_allowin       (D_allowin       ),
    .pD_allowin      (pD_allowin      ),
    .predict_BUS     (predict_BUS     ),
    .PB_BUS          (PB_BUS          ),
    .BTB_stall       (BTB_stall       ),
    .predict_error_D (predict_error_D ),
    .predict_error_E (predict_error_E ),
    .ertn_flush      (ertn_flush      ),
    .ex_en           (ex_en           )
);

Decode u_Decode(
    .clk                (clk                ),
    .rstn               (resetn             ),
    .pDD_valid          (pDD_valid           ),
    .pDD_BUS            (pDD_BUS             ),
    .hardware_interrupt (hardware_interrupt ),
    .E_allowin          (E_allowin          ),
    .D_allowin          (D_allowin          ),
    .ED_for_BUS         (ED_for_BUS         ),
    .MD_for_BUS         (MD_for_BUS         ),
    .Wrf_BUS            (Wrf_BUS            ),
    .Wcsr_BUS           (Wcsr_BUS           ),
    .DE_valid           (DE_valid           ),
    .DE_BUS             (DE_BUS             ),
    .BTB_stall_i        (BTB_stall          ),
    .predict_error_D    (predict_error_D    ),
    .predict_error_E    (predict_error_E    ),
    .Branch_BUS_D       (Branch_BUS_D       ),
    .ex_D               (ex_D               ),
    .ex_en              (ex_en              ),
    .ex_entryPC         (ex_entryPC         ),
    .ertn_flush         (ertn_flush         ),
    .new_pc             (new_pc             )
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
    .ex_E            (ex_E            ),
    .ex_en           (ex_en           ),
    .predict_error_E (predict_error_E ),
    .Branch_BUS_E    (Branch_BUS_E    ),
    .data_sram_req    (data_sram_req    ),
    .data_sram_wr     (data_sram_wr     ),
    .data_sram_size   (data_sram_size   ),
    .data_sram_wstrb  (data_sram_wstrb  ),
    .data_sram_addr   (data_sram_addr   ),
    .data_sram_wdata  (data_sram_wdata  ),
    .data_sram_addr_ok(data_sram_addr_ok),
    .data_sram_data_ok(data_sram_data_ok)
);

Memory u_Memory(
    .clk             (clk             ),
    .rstn            (resetn          ),
    .W_allowin       (W_allowin       ),
    .M_allowin       (M_allowin       ),
    .EM_valid        (EM_valid        ),
    .EM_BUS          (EM_BUS          ),
    .MD_for_BUS      (MD_for_BUS      ),
    .data_sram_data_ok(data_sram_data_ok),
    .data_sram_rdata (data_sram_rdata ),
    .ex_en           (ex_en           ),
    .MW_valid        (MW_valid        ),
    .MW_BUS          (MW_BUS          )
);
    
Writeback u_Writeback(
    .clk               (clk               ),
    .rstn              (resetn            ),
    .W_allowin         (W_allowin         ),
    .MW_valid          (MW_valid          ),
    .MW_BUS            (MW_BUS            ),
    .Wrf_BUS           (Wrf_BUS           ),
    .Wcsr_BUS          (Wcsr_BUS          ),
    .PB_BUS            (PB_BUS            ),
    .ex_en             (ex_en             ),
    .debug_wb_pc       (debug_wb_pc       ),
    .debug_wb_rf_we    (debug_wb_rf_we    ),
    .debug_wb_rf_wnum  (debug_wb_rf_wnum  ),
    .debug_wb_rf_wdata (debug_wb_rf_wdata )
);



endmodule
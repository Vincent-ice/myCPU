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

wire                            D_allowin;
wire                            E_allowin;
wire                            M_allowin;
wire                            W_allowin;

Fetch u_Fetch(
    .clk             (clk             ),
    .rstn            (resetn          ),
    .Branch_BUS      (Branch_BUS      ),
    .D_allowin       (D_allowin       ),
    .FD_valid        (FD_valid        ),
    .FD_BUS          (FD_BUS          ),
    .inst_sram_en    (inst_sram_en    ),
    .inst_sram_we    (inst_sram_we    ),
    .inst_sram_addr  (inst_sram_addr  ),
    .inst_sram_wdata (inst_sram_wdata )
);

Decode u_Decode(
    .clk             (clk             ),
    .rstn            (resetn          ),
    .FD_valid        (FD_valid        ),
    .FD_BUS          (FD_BUS          ),
    .inst_sram_rdata (inst_sram_rdata ),
    .E_allowin       (E_allowin       ),
    .D_allowin       (D_allowin       ),
    .ED_for_BUS      (ED_for_BUS      ),
    .MD_for_BUS      (MD_for_BUS      ),
    .Wrf_BUS         (Wrf_BUS         ),
    .DE_valid        (DE_valid        ),
    .DE_BUS          (DE_BUS          ),
    .Branch_BUS      (Branch_BUS      )
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
    .data_sram_en    (data_sram_en    ),
    .data_sram_we    (data_sram_we    ),
    .data_sram_addr  (data_sram_addr  ),
    .data_sram_wdata (data_sram_wdata )
);

Memory u_Memory(
    .clk             (clk             ),
    .rstn            (resetn          ),
    .W_allowin       (W_allowin       ),
    .M_allowin       (M_allowin       ),
    .EM_valid        (EM_valid        ),
    .EM_BUS          (EM_BUS          ),
    .MD_for_BUS      (MD_for_BUS      ),
    .data_sram_rdata (data_sram_rdata ),
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
    .debug_wb_pc       (debug_wb_pc       ),
    .debug_wb_rf_we    (debug_wb_rf_we    ),
    .debug_wb_rf_wnum  (debug_wb_rf_wnum  ),
    .debug_wb_rf_wdata (debug_wb_rf_wdata )
);



endmodule
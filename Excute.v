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
    output                      data_sram_wr
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
    end
    else if (ex_en) begin
        DE_BUS_E <= 'b0;
    end
    else if (DE_valid && E_allowin) begin
        DE_BUS_E <= DE_BUS;
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
wire [`alu_op_Wid-1:0] alu_op = alu_op_E & {`alu_op_Wid{!ex_D && !ex_flag}};

alu u_alu(
    .clk          (clk         ),
    .rstn         (rstn        ),
    .alu_op       (alu_op      ),
    .alu_src1     (alu_src1_E  ),
    .alu_src2     (alu_src2_E  ),
    .alu_result   (alu_result_E),
    .stall        (stall       )
    );

//data sram manage
wire [31:0] vaddr_E = alu_result_E;
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
    case ({mem_we_E,vaddr_E[1:0]})
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

assign data_sram_addr  = vaddr_E;

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
wire        ALE        = ((mem_we_E[3] | res_from_mem_E[3])&(|data_sram_addr[1:0])) ||
                         ((mem_we_E[1] | res_from_mem_E[1])&( data_sram_addr[0]  ));
assign      ex_E       = E_valid && (ex_D | ALE);
wire [7:0]  ecode_E    = ~E_valid ? 8'h00       :
                         ex_D     ? ecode_D     :
                         ALE      ? `ECODE_ALE  : 8'b0;
wire        esubcode_E = ex_D     ? esubcode_D  : 1'b0;

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
                 data_sram_addr,    //120:89
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

endmodule
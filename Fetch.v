`include "Defines.vh"
module Fetch (      // 整个Fetch的逻辑十分混乱，补丁太多了，建议重写
    input                           clk,
    input                           rstn,

    input    [`predict_BUS_Wid-1:0] predict_BUS,    // 分支预测总线 from pD
    input                           predict_error,  // 预测错误信号 from E
    input    [`Branch_BUS_Wid-1:0]  Branch_BUS,     // 预测错误时的分支总线 from E

    // 例外处理
    input                           ex_D,           // D阶段例外申请
    input                           ex_E,           // E阶段例外申请
    input                           ex_en_i,        // 例外处理使能信号，即Wb阶段的例外申请
    input    [31:0]                 ex_entryPC,     // 例外处理入口地址
    input                           ertn_flush_i,   // ertn指令刷新信号
    input    [31:0]                 new_pc,         // ertn指令刷新后的新PC

    // 级间握手信号
    input                           pD_allowin,
    
    output                          FpD_valid,
    output   [`FpD_BUS_Wid-1:0]     FpD_BUS,

    // inst sram相关
    output                          inst_sram_req,
    output                          inst_sram_wr,
    output   [1:0]                  inst_sram_size,
    output   [3:0]                  inst_sram_wstrb,
    output   [31:0]                 inst_sram_addr,
    input                           inst_sram_addr_ok,
    input                           inst_sram_data_ok,
    output   [31:0]                 inst_sram_wdata,
    input    [31:0]                 inst_sram_rdata

);

//Branch bus
wire br_taken_i;
wire [31:0] br_target_i;
assign {br_taken_i,br_target_i} = Branch_BUS;

wire        predict_taken  = predict_BUS[32];
wire [31:0] predict_target = predict_BUS[31:0];

//pipeline handshake  阻塞和重开逻辑大部分都是debug一点点磨出来的，看起来很复杂，我也看不懂
reg  [31:0] pc_reg;
reg  [31:0] pc_next;
wire        pc_en;
wire [31:0] pc_plus4 = pc_reg + 32'd4;
reg  ex_F;
reg  has_ex;
reg  ex_en;
reg  ertn_flush;
reg  [31:0] br_target;
reg  br_taken_buff;
reg  [31:0] br_target_buff;
reg  send_handshake;
reg  F_valid;
wire F_valid_next   = rstn & inst_sram_req & inst_sram_addr_ok;//next cycle valid
(*max_fanout = 20*)wire F_ready_go;//ready send to next stage
reg  F_ready_go_buff;
always @(posedge clk) begin
    if (!rstn) begin
        F_ready_go_buff <= 1'b0;
    end
    else if (inst_sram_data_ok & !has_ex) begin
        F_ready_go_buff <= 1'b1;
    end
    else if (inst_sram_addr_ok & inst_sram_req || has_ex || ertn_flush) begin
        F_ready_go_buff <= 1'b0;
    end
end
assign F_ready_go = F_ready_go_buff | (inst_sram_data_ok & !has_ex);
wire F_allowin      = !F_valid || ex_en || F_ready_go && pD_allowin && !ex_F;//allow input data
assign FpD_valid     = F_valid_next && F_ready_go && !br_taken_buff && !ertn_flush || (ex_F & !ex_en);//validity of D stage
always @(posedge clk) begin
    if (!rstn) begin
        F_valid <= 1'b0;
    end
    else if (F_allowin) begin
        F_valid <= F_valid_next;
    end
end

always @(posedge clk) begin
    if (!rstn) begin
        send_handshake <= 1'b0;
    end
    else if(inst_sram_data_ok) begin
        send_handshake <= 1'b0;
    end
    else if(inst_sram_addr_ok & inst_sram_req) begin
        send_handshake <= 1'b1;
    end
end

//branch buff   这些buff应该是切开关键路径用的
always @(posedge clk) begin
    if (!rstn) begin
        br_taken_buff <= 1'b0;
        br_target_buff <= 32'b0;
    end
    else if (br_taken_i) begin
        br_taken_buff <= 1'b1;
        br_target_buff <= br_target_i;
    end
    else if (!br_taken_buff & predict_taken) begin
        br_taken_buff <= 1'b1;
        br_target_buff <= predict_target;
    end
    else if (F_valid_next & F_allowin || ex_en) begin
        br_taken_buff <= 1'b0;
    end
end

//has_ex buff       用于检测到流水线中存在例外，关闭访存请求以减少可能的长等待
always @(posedge clk) begin
    if (!rstn) begin
        has_ex <= 1'b0;
    end
    else if (ex_D | ex_E) begin
        has_ex <= 1'b1;
    end
    else if (inst_sram_addr_ok & inst_sram_req & ex_en | predict_error) begin
        has_ex <= 1'b0;
    end
end

//ex_en buff
always @(posedge clk) begin
    if (!rstn) begin
        ex_en <= 1'b0;
    end
    else if (ex_en_i) begin
        ex_en <= 1'b1;
    end
    else if (F_valid_next & F_allowin) begin
        ex_en <= 1'b0;
    end
end

//ertn_flush buff
always @(posedge clk) begin
    if (!rstn) begin
        ertn_flush <= 1'b0;
    end
    else if (ertn_flush_i) begin
        ertn_flush <= 1'b1;
    end
    else if (F_valid_next & F_allowin) begin
        ertn_flush <= 1'b0;
    end
end

//PC    **这里建议把整个next pc重写一下，写的太丑了**
assign pc_en   = F_allowin && !ex_F && !send_handshake;
always @(*) begin
    case (1'b1)
        ex_en & has_ex: pc_next = ex_entryPC;       // 这个也是debug打的补丁
        br_taken_buff : pc_next = br_target_buff;
        has_ex        : pc_next = ex_entryPC;
        ertn_flush    : pc_next = new_pc;
        default       : pc_next = pc_plus4;
    endcase
end
/* assign pc_next = br_taken_E   ? br_target_E                        :
                 br_taken_D   ? br_target_D                        : 
                 ex_en        ? ex_entryPC                         :
                 predict_taken? predict_target                     :
                 ertn_flush   ? new_pc                             : pc_plus4; */

always @(posedge clk) begin
    if(!rstn)begin
        pc_reg <= 32'h1bff_fffc;
    end else if (F_valid_next && F_allowin) begin
        pc_reg <= pc_next;
    end
end

//exception manage
wire        ex_ADEF    = |pc_next[1:0];
reg  [ 7:0] ecode_F;
reg         esubcode_F;
always @(posedge clk) begin
    if (!predict_error && F_valid_next && F_allowin) begin
        ex_F    <= (ex_ADEF);
        ecode_F <= ex_ADEF ? `ECODE_ADEF : 8'h00;
        esubcode_F <= ex_ADEF ? `ESUBCODE_ADEF : 1'b0;
    end
    else begin
        ex_F <= 1'b0;
        ecode_F <= 8'h00;
        esubcode_F <= 1'b0;
    end
end

//inst sram manage
reg  [31:0] inst_sram_rdata_buff;
assign inst_sram_req   = pc_en;
assign inst_sram_wr    = 1'b0;
assign inst_sram_size  = 2'b10;
assign inst_sram_wstrb = 4'b0;
assign inst_sram_addr  = pc_next; //virtual
assign inst_sram_wdata = 32'b0 ;
always @(posedge clk) begin
    if (!rstn) begin
        inst_sram_rdata_buff <= 32'b0;
    end
    else if (inst_sram_data_ok) begin
        inst_sram_rdata_buff <= inst_sram_rdata;
    end
end

//FD BUS
assign FpD_BUS = {pc_reg,       //74:43             pc
                 inst_sram_rdata_buff,//42:11       inst
                 pc_en,         //10                pc有效性
                 ex_F & !predict_error,//9          F级例外
                 ecode_F,       //8:1               ecode
                 esubcode_F};   //0                 esubcode
endmodule
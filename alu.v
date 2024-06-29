`include "Defines.vh"
module alu(
  input  wire clk,
  input  wire rstn,
  input  wire [`alu_op_Wid-1:0] alu_op,
  input  wire [31:0] alu_src1,
  input  wire [31:0] alu_src2,
  output wire [31:0] alu_result,
  output wire        div_stall
);
 
wire op_add;   //add operation
wire op_sub;   //sub operation
wire op_slt;   //signed compared and set less than
wire op_sltu;  //unsigned compared and set less than
wire op_and;   //bitwise and
wire op_nor;   //bitwise nor
wire op_or;    //bitwise or
wire op_xor;   //bitwise xor
wire op_sll;   //logic left shift
wire op_srl;   //logic right shift
wire op_sra;   //arithmetic right shift
wire op_lui;   //Load Upper Immediate
wire op_mul;   //multiply          [31:0]
wire op_mulh;  //multiply signed   [63:32]
wire op_mulhu; //multiply unsigned [63:32]
wire op_div;   //division signed   quotient
wire op_divu;  //division unsigned quotient
wire op_mod;   //division signed   remainder
wire op_modu;  //division unsigned remainder

// control code decomposition
assign op_add  = alu_op[ 0];
assign op_sub  = alu_op[ 1];
assign op_slt  = alu_op[ 2];
assign op_sltu = alu_op[ 3];
assign op_and  = alu_op[ 4];
assign op_nor  = alu_op[ 5];
assign op_or   = alu_op[ 6];
assign op_xor  = alu_op[ 7];
assign op_sll  = alu_op[ 8];
assign op_srl  = alu_op[ 9];
assign op_sra  = alu_op[10];
assign op_lui  = alu_op[11];
assign op_mul  = alu_op[12];
assign op_mulh = alu_op[13];
assign op_mulhu= alu_op[14];
assign op_div  = alu_op[15];
assign op_mod  = alu_op[16];
assign op_divu = alu_op[17];
assign op_modu = alu_op[18];
 
wire [31:0] add_sub_result;
wire [31:0] slt_result;
wire [31:0] sltu_result;
wire [31:0] and_result;
wire [31:0] nor_result;
wire [31:0] or_result;
wire [31:0] xor_result;
wire [31:0] lui_result;
wire [31:0] sll_result;
wire [63:0] sr64_result;
wire [31:0] sr_result;
wire [63:0] mul_result;
wire [31:0] quo_result;
wire [31:0] rem_result;

// 32-bit adder
wire [31:0] adder_a;
wire [31:0] adder_b;
wire        adder_cin;
wire [31:0] adder_result;
wire        adder_cout;
 
assign adder_a   = alu_src1;
assign adder_b   = (op_sub | op_slt | op_sltu) ? ~alu_src2 : alu_src2;  //src1 - src2 rj-rk
assign adder_cin = (op_sub | op_slt | op_sltu) ? 1'b1      : 1'b0;
assign {adder_cout, adder_result} = adder_a + adder_b + adder_cin;
 
// ADD, SUB result
assign add_sub_result = adder_result;
 
// SLT result
assign slt_result[31:1] = 31'b0;   //rj < rk 1
assign slt_result[0]    = (alu_src1[31] & ~alu_src2[31])
                        | ((alu_src1[31] ~^ alu_src2[31]) & adder_result[31]);
                        
// SLTU result
assign sltu_result[31:1] = 31'b0;
assign sltu_result[0]    = ~adder_cout;
 
// bitwise operation
assign and_result = alu_src1 & alu_src2;
assign or_result  = alu_src1 | alu_src2;
assign nor_result = ~or_result;
assign xor_result = alu_src1 ^ alu_src2;
assign lui_result = alu_src2;
 
// SLL result
assign sll_result = alu_src1 << alu_src2[4:0];   //rj << i5
 
// SRL, SRA result
assign sr64_result = {{32{op_sra & alu_src1[31]}}, alu_src1[31:0]} >> alu_src2[4:0]; //rj >> i5
 
assign sr_result   = sr64_result[31:0];
 
// MUL, MULH, MULHU result
multCore u_multCore(
  .op1     (alu_src1          ),
  .op2     (alu_src2          ),
  .sign_en (op_mul | op_mulh  ),
  .out     (mul_result        )
);

// DIV, DIVU, MOD, MODU result
wire div_ready;
reg  div_ready_delay;
wire div_history_find;
wire div_go = div_ready_delay & (|alu_src2) & (op_div | op_mod | op_divu | op_modu);
wire div_en = !div_history_find & div_go;
wire div_sign = (op_div | op_mod);
divCore_srt2 u_divCore_srt2(
  .clk     (clk          ),
  .rst     (rstn         ),
  .enable  (div_en       ),
  .sign_en (div_sign     ),
  .op1     (alu_src1     ),
  .op2     (alu_src2     ),
  .rem_o   (rem          ),
  .quo_o   (quo          ),
  .ready   (div_ready    )
);
assign div_stall = ~div_ready;
always @(posedge clk ) begin
  if (!rstn) begin
    div_ready_delay <= 1'b0;
  end else begin
    div_ready_delay <= div_ready;
  end
end

  // div result history
reg [31:0] op1_history [7:0];
reg [31:0] op2_history [7:0];
reg [31:0] rem_history [7:0];
reg [31:0] quo_history [7:0];
reg        sign_history[7:0];
reg [ 3:0] tag;

always @(posedge clk) begin
  if (!rstn) begin
    tag <= 4'b0;
  end
end

always @(posedge div_en) begin
    op1_history[tag] <= alu_src1;
    op2_history[tag] <= alu_src2;
    sign_history[tag]<= div_sign;
end
always @(posedge div_ready_delay) begin
    tag              <= tag + 1;
    rem_history[tag] <= rem_result;
    quo_history[tag] <= quo_result;
end

wire [7:0] find_buff ;
generate
  genvar i;
  for (i = 0; i < 8; i = i + 1) begin
    assign find_buff[i] = div_go & (op1_history[i] == alu_src1) & (op2_history[i] == alu_src2);
  end
endgenerate
assign div_history_find = |find_buff;

assign rem_result = div_history_find ? (find_buff[0] ? rem_history[0] : 
                                        find_buff[1] ? rem_history[1] :
                                        find_buff[2] ? rem_history[2] :
                                        find_buff[3] ? rem_history[3] :
                                        find_buff[4] ? rem_history[4] :
                                        find_buff[5] ? rem_history[5] :
                                        find_buff[6] ? rem_history[6] :
                                        find_buff[7] ? rem_history[7] : 32'b0) : rem_result;
assign quo_result = div_history_find ? (find_buff[0] ? quo_history[0] :
                                        find_buff[1] ? quo_history[1] :
                                        find_buff[2] ? quo_history[2] :
                                        find_buff[3] ? quo_history[3] :
                                        find_buff[4] ? quo_history[4] :
                                        find_buff[5] ? quo_history[5] :
                                        find_buff[6] ? quo_history[6] :
                                        find_buff[7] ? quo_history[7] : 32'b0) : quo_result;

// final result mux
assign alu_result = ({32{op_add|op_sub}} & add_sub_result)
                  | ({32{op_slt       }} & slt_result)
                  | ({32{op_sltu      }} & sltu_result)
                  | ({32{op_and       }} & and_result)
                  | ({32{op_nor       }} & nor_result)
                  | ({32{op_or        }} & or_result)
                  | ({32{op_xor       }} & xor_result)
                  | ({32{op_lui       }} & lui_result)
                  | ({32{op_sll       }} & sll_result)
                  | ({32{op_srl|op_sra}} & sr_result)
                  | ({32{op_mul       }} & mul_result[31: 0])
                  | ({32{op_mulh|op_mulhu}} & mul_result[63:32])
                  | ({32{op_div|op_divu}} & quo_result)
                  | ({32{op_mod|op_modu}} & rem_result);
 
endmodule
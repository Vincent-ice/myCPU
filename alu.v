`include "Defines.vh"
module alu(
  input  wire clk,
  input  wire rstn,
  input  wire [`alu_op_Wid-1:0] alu_op,
  input  wire [31:0] alu_src1,
  input  wire [31:0] alu_src2,
  output reg  [31:0] alu_result,
  output wire        stall
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
  .clk     (clk               ),
  .rstn    (rstn              ),
  .op1     (alu_src1          ),
  .op2     (alu_src2          ),
  .sign_en (op_mul | op_mulh  ),
  .out     (mul_result        )
);//2-cycle multiply
/* wire signed [63:0] mul_sign = $signed(alu_src1) * $signed(alu_src2);
wire        [63:0] mul_unsign = alu_src1 * alu_src2;
assign mul_result = (op_mul | op_mulh) ? mul_sign :
                    op_mulhu           ? mul_unsign : 64'b0; */

wire mult_stall;
reg  mult_stall_delay;
always @(posedge clk) begin
    if (!rstn) begin
        mult_stall_delay <= 1'b0;
    end
    else begin
        mult_stall_delay <= mult_stall;
    end
end
assign mult_stall = (op_mul | op_mulh | op_mulhu) ^ mult_stall_delay;
// DIV, DIVU, MOD, MODU result
wire div_ready;
reg  div_ready_delay;
wire div_history_find;
wire div_go = div_ready_delay & (|alu_src2) & (op_div | op_mod | op_divu | op_modu);
wire dividend_is_0 = !(|alu_src1) & div_go;
wire div_en = !div_history_find & div_go & !dividend_is_0;
wire div_sign = (op_div | op_mod);
wire [31:0] rem,quo;
wire div_complete;

divCore_srt2 u_divCore_srt2(
  .clk     (clk          ),
  .rst     (rstn         ),
  .enable  (div_en       ),
  .sign_en (div_sign     ),
  .op1     (alu_src1     ),
  .op2     (alu_src2     ),
  .rem_o   (rem          ),
  .quo_o   (quo          ),
  .ready   (div_ready    ),
  .complete(div_complete )
);
wire div_stall = ~div_ready;
always @(posedge clk ) begin
    div_ready_delay <= div_ready;
end

  // div result history
reg [31:0] op1_history [7:0];
reg [31:0] op2_history [7:0];
reg [31:0] rem_history [7:0];
reg [31:0] quo_history [7:0];
reg        sign_history[7:0];
reg [ 3:0] tag;

integer n = 0;
always @(posedge clk) begin
  if (!rstn) begin
    tag <= 4'b0;
    for (n = 0;n < 8;n = n + 1) begin
      op1_history[n] <= 32'b0;
      op2_history[n] <= 32'b0;
      rem_history[n] <= 32'b0;
      quo_history[n] <= 32'b0;
      sign_history[n]<= 1'b0;
    end
  end
  else if (div_complete) begin
    tag              <= tag + 1;
    op1_history[tag] <= alu_src1;
    op2_history[tag] <= alu_src2;
    sign_history[tag]<= div_sign;
    rem_history[tag] <= rem;
    quo_history[tag] <= quo;    
  end
end

wire [7:0] find_buff ;
generate
  genvar i;
  for (i = 0; i < 8; i = i + 1) begin
    assign find_buff[i] = div_go & (op1_history[i] == alu_src1) & (op2_history[i] == alu_src2);
  end
endgenerate
assign div_history_find = |find_buff;

reg [31:0] find_rem;
reg [31:0] find_quo;
always @(*) begin
  case (1'b1)
    find_buff[0] : begin find_rem = rem_history[0]; find_quo = quo_history[0]; end
    find_buff[1] : begin find_rem = rem_history[1]; find_quo = quo_history[1]; end
    find_buff[2] : begin find_rem = rem_history[2]; find_quo = quo_history[2]; end
    find_buff[3] : begin find_rem = rem_history[3]; find_quo = quo_history[3]; end
    find_buff[4] : begin find_rem = rem_history[4]; find_quo = quo_history[4]; end
    find_buff[5] : begin find_rem = rem_history[5]; find_quo = quo_history[5]; end
    find_buff[6] : begin find_rem = rem_history[6]; find_quo = quo_history[6]; end
    find_buff[7] : begin find_rem = rem_history[7]; find_quo = quo_history[7]; end
    default      : begin find_rem = 32'b0         ; find_quo = 32'b0         ; end
  endcase
end

assign rem_result = dividend_is_0    ? 32'b0    :
                    div_history_find ? find_rem : rem;
assign quo_result = dividend_is_0    ? 32'b0    :
                    div_history_find ? find_quo : quo;

// stall signal
assign stall = mult_stall | div_stall;

// final result mux
always @(*) begin
  case (1'b1)
    op_add : alu_result = add_sub_result;
    op_sub : alu_result = add_sub_result;
    op_slt : alu_result = slt_result;
    op_sltu: alu_result = sltu_result;
    op_and : alu_result = and_result;
    op_nor : alu_result = nor_result;
    op_or  : alu_result = or_result;
    op_xor : alu_result = xor_result;
    op_lui : alu_result = lui_result;
    op_sll : alu_result = sll_result;
    op_srl : alu_result = sr_result;
    op_sra : alu_result = sr_result;
    op_mul : alu_result = mul_result[31: 0];
    op_mulh: alu_result = mul_result[63:32];
    op_mulhu:alu_result = mul_result[63:32];
    op_div : alu_result = quo_result;
    op_mod : alu_result = rem_result;
    op_divu: alu_result = quo_result;
    op_modu: alu_result = rem_result;
    default: alu_result = 32'b0;
  endcase
end

endmodule
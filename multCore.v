module multCore (
    input wire clk,
    input wire rstn,
    input wire [31:0] op1,op2,
    input wire sign_en, //1为有符号
    output wire [63:0] out
);
wire [65:0] op1_ext = sign_en ? (op1[31] ? {34'h3_ffff_ffff,op1} : {34'b0,op1})
                                   : {34'b0,op1};
wire [33:0] op2_ext = sign_en ? {{2{op2[31]}},op2} : {2'b0,op2};
wire [65:0] mult_buf [16:0];
wire [34:0] op2_left1 = op2_ext << 1;
wire [2:0]  judge_buff [16:0];

generate
    genvar i;
    for (i = 0; i < 17; i = i + 1) begin
        assign judge_buff[i] = op2_left1[2*i +:3];
    end
    for (i = 0; i < 17; i = i + 1) begin
        assign mult_buf[i] = judge_buff[i]==3'b001 ? op1_ext        :
                             judge_buff[i]==3'b010 ? op1_ext        :
                             judge_buff[i]==3'b011 ? op1_ext<<1     :
                             judge_buff[i]==3'b100 ? -(op1_ext<<1)  :
                             judge_buff[i]==3'b101 ? -op1_ext       :
                             judge_buff[i]==3'b110 ? -op1_ext       : 0;
    end  
endgenerate

wire [65:0] wallace1_buf [9:0];
begin:wallace1
    compressor32 #(66) wallace1_1(mult_buf[0],mult_buf[1]<<2,mult_buf[2]<<4,wallace1_buf[0],wallace1_buf[1]);
    compressor32 #(66) wallace1_2(mult_buf[3]<<6,mult_buf[4]<<8,mult_buf[5]<<10,wallace1_buf[2],wallace1_buf[3]);
    compressor32 #(66) wallace1_3(mult_buf[6]<<12,mult_buf[7]<<14,mult_buf[8]<<16,wallace1_buf[4],wallace1_buf[5]);
    compressor32 #(66) wallace1_4(mult_buf[9]<<18,mult_buf[10]<<20,mult_buf[11]<<22,wallace1_buf[6],wallace1_buf[7]);
    compressor32 #(66) wallace1_5(mult_buf[12]<<24,mult_buf[13]<<26,mult_buf[14]<<28,wallace1_buf[8],wallace1_buf[9]);
end
wire [65:0] wallace2_buf [7:0];
begin:wallace2
    compressor32 #(66) wallace2_1(wallace1_buf[0],wallace1_buf[1],wallace1_buf[2],wallace2_buf[0],wallace2_buf[1]);
    compressor32 #(66) wallace2_2(wallace1_buf[3],wallace1_buf[4],wallace1_buf[5],wallace2_buf[2],wallace2_buf[3]);
    compressor32 #(66) wallace2_3(wallace1_buf[6],wallace1_buf[7],wallace1_buf[8],wallace2_buf[4],wallace2_buf[5]);
    compressor32 #(66) wallace2_4(wallace1_buf[9],mult_buf[15]<<30,mult_buf[16]<<32,wallace2_buf[6],wallace2_buf[7]);
end
wire [65:0] wallace3_buf [3:0];
begin:wallace3
    compressor32 #(66) wallace3_1(wallace2_buf[0],wallace2_buf[1],wallace2_buf[2],wallace3_buf[0],wallace3_buf[1]);
    compressor32 #(66) wallace3_2(wallace2_buf[3],wallace2_buf[4],wallace2_buf[5],wallace3_buf[2],wallace3_buf[3]);
end


/*--------------------------------------*/
reg [65:0] wallace_buf [5:0];
always @(posedge clk) begin
    if (!rstn) begin
        wallace_buf[0] <= 66'b0;
        wallace_buf[1] <= 66'b0;
        wallace_buf[2] <= 66'b0;
        wallace_buf[3] <= 66'b0;
        wallace_buf[4] <= 66'b0;
        wallace_buf[5] <= 66'b0;
    end
    else begin
        wallace_buf[0] <= wallace3_buf[0];
        wallace_buf[1] <= wallace3_buf[1];
        wallace_buf[2] <= wallace3_buf[2];
        wallace_buf[3] <= wallace3_buf[3];
        wallace_buf[4] <= wallace2_buf[6];
        wallace_buf[5] <= wallace2_buf[7];
    end
end

wire [65:0] wallace4_buf [3:0];
begin:wallace4
    compressor32 #(66) wallace4_1(wallace_buf[0],wallace_buf[1],wallace_buf[2],wallace4_buf[0],wallace4_buf[1]);
    compressor32 #(66) wallace4_2(wallace_buf[3],wallace_buf[4],wallace_buf[5],wallace4_buf[2],wallace4_buf[3]);
end
wire [65:0] wallace5_buf [1:0];
begin:wallace5
    compressor32 #(66) wallace5(wallace4_buf[0],wallace4_buf[1],wallace4_buf[2],wallace5_buf[0],wallace5_buf[1]);
end
wire [65:0] wallace6_buf [1:0];
begin:wallace6
    compressor32 #(66) wallace6(wallace5_buf[0],wallace5_buf[1],wallace4_buf[3],wallace6_buf[0],wallace6_buf[1]);
end
wire [65:0] out_buf;
begin:adder
    assign out_buf = wallace6_buf[0] + wallace6_buf[1];
end
assign out = out_buf[63:0];
endmodule

module compressor32 #(parameter WIDTH = 8)(
    input [WIDTH-1:0] a,b,c,
    output[WIDTH-1:0] S,C
);

assign S = a^b^c;
assign C = (a&b|b&c|c&a)<<1;
    
endmodule


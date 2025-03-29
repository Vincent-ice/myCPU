`timescale 1ns / 1ps
module divCore_srt2(
	input			  clk,
	input			  rstn,
    input             enable,
	input 			  sign_en, // 1->signed divide
	input		[31:0] op1,	   // dividend
	input 		[31:0] op2,	   // divisor
	output reg  [31:0] rem_o,
	output reg  [31:0] quo_o,
    output reg         ready,
	output             complete
);

//------------------------ SIGNALS ------------------------//

reg  [33:0] op1_i;	// dividend
reg  [33:0] op2_i;  // divisor
wire [5:0]  op1_ld;	// leading digit
wire [5:0]  op2_ld;
reg  [5:0]  op1_s;
wire [5:0]  subs;
wire [33:0] op1_n;	// normalized
wire [33:0] op2_n;
reg  [33:0] rem_r;
wire        q;
wire        n;
wire        ops_sign;
reg  [33:0] Q_reg,Q_next;
reg  [33:0] QM_reg,QM_next;

//---------------------FSM Description---------------------//

localparam ST_IDLE = 4'b0001;
localparam ST_SAMP = 4'b0010;
localparam ST_DIV  = 4'b0100;
localparam ST_OUT  = 4'b1000;
reg  [3:0] state_next;
reg  [3:0] state_reg;
reg  [5:0] cnt;
wire [5:0] iter;

always @(*) begin
	case(state_reg)
		ST_IDLE: begin
			if(enable) begin
				state_next = ST_SAMP;
			end
			else begin
				state_next = ST_IDLE;
			end
		end
		ST_SAMP: begin
			state_next = ST_DIV;
		end
		ST_DIV: begin
			if(cnt==iter+1) begin
				state_next = ST_OUT;
			end
			else begin
				state_next = ST_DIV;
			end
		end
		ST_OUT: begin
			state_next = ST_IDLE;
		end
		default: begin
			state_next = ST_IDLE;
		end
	endcase
end

always @(posedge clk or negedge rstn) begin
	if(!rstn) begin
		state_reg <= ST_IDLE;
	end else begin
		state_reg <= state_next;
	end
end

assign complete = state_reg==ST_OUT ? 1'b1 : 1'b0;

always @(*) begin
	if(!rstn) begin
		ready <= 1'b1;
	end else begin
		if(rstn & state_next==ST_IDLE) begin
			ready <= 1'b1;
		end else begin
			ready <= 1'b0;
		end
	end
end

assign subs = op2_ld - op1_s;
assign iter = subs[5] ? 6'd0 : subs[5:0];
always @(posedge clk or negedge rstn) begin
	if(!rstn) begin
		cnt <= 6'd0;
	end else begin
		if(state_next==ST_DIV) begin
			if(cnt==iter+1) begin
				cnt <= 6'b0;
			end else begin
				cnt <= cnt + 1'b1;
			end
		end else begin
			cnt <= 6'b0;
		end
	end
end

//------------------------ PROCESS ------------------------//

always @(posedge clk or negedge rstn) begin
	if(!rstn) begin
		op1_i <= 34'b0;
		op2_i <= 34'b0;
	end else begin
		if(state_next==ST_SAMP) begin
			op1_i <= sign_en ? {op1[31],op1[31],op1}:{2'b0,op1};
			op2_i <= sign_en ? {op2[31],op2[31],op2}:{2'b0,op2};
		end
	end
end

// find leading 1s or 0s
find_ld_r2 #(34) u_find_ld_r2_1 (.op(op1_i), .pos(op1_ld));
find_ld_r2 #(34) u_find_ld_r2_2 (.op(op2_i), .pos(op2_ld));
/* always @(*) begin
	if(!rstn) begin
		op1_s <= 'd0;
	end else begin
		if(op1_ld[0]^op2_ld[0]) begin
			op1_s <= op1_ld-1;	// opt
		end else begin
			if(op1_ld>='d2) begin
				op1_s <= op1_ld-2;
			end else begin
				op1_s <= op1_ld;
			end
		end
	end
end */
always @(*) begin
	op1_s <= |op1_ld ? op1_ld-1 : op1_ld;
end
assign op1_n = op1_i << op1_s;
assign op2_n = op2_i << op2_ld;
genvar i;
generate
	qds_r2 #(34) u_qds(
		.r(rem_r),
		.sd(op2_n[33]),
		.q(q),
		.neg(n)
	);
endgenerate

// residual remainder
always @(posedge clk or negedge rstn) begin
	if(!rstn) begin
		rem_r <= 'd0;
	end else begin
		if(state_next==ST_SAMP) begin
			rem_r <= 'd0;
		end else begin
			if(state_next==ST_DIV) begin
				if(cnt=='d0) begin
					rem_r <= op1_n;
				end else begin
					case({n,q})
						2'b00: rem_r <= {rem_r[32:0],1'b0};
					    2'b01: rem_r <= {rem_r[32:0],1'b0}-op2_n;
					    2'b10: rem_r <= {rem_r[32:0],1'b0};
					    2'b11: rem_r <= {rem_r[32:0],1'b0}+op2_n;
					default: ;
					endcase
				end
			end
		end
	end
end

// on the fly conversion
assign ops_sign = sign_en&(op1[31]^op2[31]);
always @(posedge clk) begin
	if(!rstn) begin
		Q_reg   <= 'b0;
		QM_reg  <= 'b0;
	end else begin
		if(state_next==ST_SAMP) begin
			Q_reg  <= {34{ops_sign}};
			QM_reg <= {34{ops_sign}};
		end
		else begin
			Q_reg  <= Q_next;
			QM_reg <= QM_next;
		end
	end
end

always @(*) begin
	if(state_next==ST_SAMP) begin
		Q_next  = {34{ops_sign}};
		QM_next = {34{ops_sign}};
	end
	else if(state_reg==ST_DIV) begin
		if(!n) begin	
			Q_next  = {Q_reg[32:0],q};
		end else begin
			Q_next  = {QM_reg[32:0],q};
		end
		if(!n & q) begin	
			QM_next = {Q_reg[32:0],~q};
		end else begin
			QM_next = {QM_reg[32:0],~q};
		end
	end
	else begin
		Q_next  = Q_reg;
		QM_next = QM_reg;
	end
end

// post proccessing
always @(posedge clk or negedge rstn) begin
	if(!rstn) begin
		rem_o	<=	32'd0;
		quo_o   <=  32'd0;
	end else begin
        if(state_next==ST_OUT) begin
			if (op1_i[33]) begin   //if dividend is negative   rem is negative
				if (rem_r[33]) begin
					if (|iter) begin
						if (op2_n == rem_r) begin
							rem_o <= 32'b0;
							quo_o <= Q_reg+1;
						end else if (op2_n == (-rem_r)) begin
							rem_o <= 32'b0;
							quo_o <= Q_reg-1;
						end else begin
							rem_o <= $signed(rem_r) >>> op2_ld;
							quo_o <= Q_reg;
						end
					end else begin
						rem_o <= $signed(rem_r) >>> op1_s;
						quo_o <= 32'b0;
					end
				end else begin
					if (op2_i[33]) begin
						rem_o <= $signed(rem_r+op2_n) >>> op2_ld;
						quo_o <= Q_reg-1;								
					end else begin
						rem_o <= $signed(rem_r-op2_n) >>> op2_ld;
						quo_o <= Q_reg+1;						
					end
				end
			end else begin
				if (rem_r[33]) begin
					if (op2_i[33]) begin
						rem_o <= $signed(rem_r-op2_n) >>> op2_ld;
						quo_o <= Q_reg+1;								
					end else begin
						rem_o <= $signed(rem_r+op2_n) >>> op2_ld;
						quo_o <= Q_reg-1;						
					end	
				end else begin
					if (|iter) begin
						rem_o <= $signed(rem_r) >>> op2_ld;
						quo_o <= Q_reg;
					end else begin
						rem_o <= $signed(rem_r) >>> op1_s;
						quo_o <= 32'b0;
					end
				end
			end
        end   
	end
end


endmodule


//------------------------ SUBROUTINE ------------------------//

// find leading 1s or 0s
module find_ld_r2 #(parameter WID=8)(op, pos);
input      [WID-1:0] op;
output reg [$clog2(WID)-1:0] pos;
reg  [WID-1:0] op_t;
wire [WID-1:0] pos_oh;	// onehot
integer i;
always @(*) begin
	for(i=0; i<WID; i=i+1) begin
		if(op[WID-1]==1'b0) begin
			op_t[i] = op[WID-1-i];
		end else begin
			op_t[i] = ~op[WID-1-i];
		end
	end
end
assign pos_oh = op_t & (~op_t+1);	// ripple carry
integer j;
always @(*) begin
	for(j=0; j<WID; j=j+1) begin
		if(pos_oh[j]==1) begin
			pos = j-1;
		end
	end
end
// clog2 function
function  integer clog2;
    input integer depth;
    begin
        depth = depth-1;
        for(clog2=0; depth>0; clog2=clog2+1) begin
            depth = depth >> 1;
        end
    end
endfunction
endmodule

// quotien digit selection table
module qds_r2 #(parameter WID=8)(r, sd, q, neg);
input  [WID-1:0] r;
input  sd;				// sign of divisor
output reg q;
output     neg;
always @(*) begin
	if((r[WID-2:WID-4] < 3'b010) | (r[WID-2:WID-4] >= 3'b110)) begin
		q = 1'b0;
	end else begin
		q = 1'b1;
	end
end
assign neg = (q==1'b1) & (sd!=r[WID-1]);
endmodule
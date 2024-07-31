module tlb
#(
    parameter TLBNUM = 16               //only can support 16 TLB entries, index output need to be changed when TLBNUM more than 16
)
(
    input  wire                      clk,
    input  wire                      rstn,

    // search port 0 (for fetch)
    input  wire [              18:0] s0_vppn,
    input  wire                      s0_va_bit12,
    input  wire [               9:0] s0_asid,
    output wire                      s0_found,
    output reg  [$clog2(TLBNUM)-1:0] s0_index,
    output wire [              19:0] s0_ppn,
    output wire [               5:0] s0_ps,
    output wire [               1:0] s0_plv,
    output wire [               1:0] s0_mat,
    output wire                      s0_d,
    output wire                      s0_v,

    // search port 1 (for load/store)
    input  wire [              18:0] s1_vppn,
    input  wire                      s1_va_bit12,
    input  wire [               9:0] s1_asid,
    output wire                      s1_found,
    output reg  [$clog2(TLBNUM)-1:0] s1_index,
    output wire [              19:0] s1_ppn,
    output wire [               5:0] s1_ps,
    output wire [               1:0] s1_plv,
    output wire [               1:0] s1_mat,
    output wire                      s1_d,
    output wire                      s1_v,

    // invtlb opcode
    input  wire                      invtlb_valid,
    input  wire [               4:0] invtlb_op,

    // write port
    input  wire                      we,     //w(rite) e(nable)
    input  wire [$clog2(TLBNUM)-1:0] w_index,
    input  wire                      w_e,
    input  wire [              18:0] w_vppn,
    input  wire [               5:0] w_ps,
    input  wire [               9:0] w_asid,
    input  wire                      w_g,
    input  wire [              19:0] w_ppn0,
    input  wire [               1:0] w_plv0,
    input  wire [               1:0] w_mat0,
    input  wire                      w_d0,
    input  wire                      w_v0,
    input  wire [              19:0] w_ppn1,
    input  wire [               1:0] w_plv1,
    input  wire [               1:0] w_mat1,
    input  wire                      w_d1,
    input  wire                      w_v1,

    // read port
    input  wire [$clog2(TLBNUM)-1:0] r_index,
    output wire                      r_e,
    output wire [              18:0] r_vppn,
    output wire [               5:0] r_ps,
    output wire [               9:0] r_asid,
    output wire                      r_g,
    output wire [              19:0] r_ppn0,
    output wire [               1:0] r_plv0,
    output wire [               1:0] r_mat0,
    output wire                      r_d0,
    output wire                      r_v0,
    output wire [              19:0] r_ppn1,
    output wire [               1:0] r_plv1,
    output wire [               1:0] r_mat1,
    output wire                      r_d1,
    output wire                      r_v1
);

reg  [TLBNUM-1:0] tlb_e;
reg  [TLBNUM-1:0] tlb_ps4MB; //pagesize 1:4MB=>ps=21, 0:4KB=>ps=12
reg  [      18:0] tlb_vppn     [TLBNUM-1:0];
reg  [       9:0] tlb_asid     [TLBNUM-1:0];
reg               tlb_g        [TLBNUM-1:0];
reg  [      19:0] tlb_ppn0     [TLBNUM-1:0];
reg  [       1:0] tlb_plv0     [TLBNUM-1:0];
reg  [       1:0] tlb_mat0     [TLBNUM-1:0];
reg               tlb_d0       [TLBNUM-1:0];
reg               tlb_v0       [TLBNUM-1:0];
reg  [      19:0] tlb_ppn1     [TLBNUM-1:0];
reg  [       1:0] tlb_plv1     [TLBNUM-1:0];
reg  [       1:0] tlb_mat1     [TLBNUM-1:0];
reg               tlb_d1       [TLBNUM-1:0];
reg               tlb_v1       [TLBNUM-1:0];
wire [TLBNUM-1:0] match0,match1            ;

// TLB search logic
genvar i;
generate
    for (i = 0; i < TLBNUM; i = i + 1) begin : match_gen
        assign match0[i] = (s0_vppn[18:10] == tlb_vppn[i][18:10])
                          && (tlb_ps4MB[i] || s0_vppn[9:0] == tlb_vppn[i][9:0])
                          && ((s0_asid == tlb_asid[i]) || tlb_g[i]);
        
        assign match1[i] = (s1_vppn[18:10] == tlb_vppn[i][18:10])
                          && (tlb_ps4MB[i] || s1_vppn[9:0] == tlb_vppn[i][9:0])
                          && ((s1_asid == tlb_asid[i]) || tlb_g[i]);
        
    end
endgenerate

/* genvar j;
generate
    for (j = 0; j < TLBNUM; j = j + 1) begin : index_gen
        assign s0_index = match0[j] ? j : 0;
        assign s1_index = match1[j] ? j : 0;
    end
endgenerate */

assign s0_found = |match0;
assign s1_found = |match1;

always @(*) begin
    case (1'b1)
        match0[0]: s0_index = 0;
        match0[1]: s0_index = 1;
        match0[2]: s0_index = 2;
        match0[3]: s0_index = 3;
        match0[4]: s0_index = 4;
        match0[5]: s0_index = 5;
        match0[6]: s0_index = 6;
        match0[7]: s0_index = 7;
        match0[8]: s0_index = 8;
        match0[9]: s0_index = 9;
        match0[10]: s0_index = 10;
        match0[11]: s0_index = 11;
        match0[12]: s0_index = 12;
        match0[13]: s0_index = 13;
        match0[14]: s0_index = 14;
        match0[15]: s0_index = 15;
        default   : s0_index = 0;
    endcase
end
always @(*) begin
    case (1'b1)
        match1[0]: s1_index = 0;
        match1[1]: s1_index = 1;
        match1[2]: s1_index = 2;
        match1[3]: s1_index = 3;
        match1[4]: s1_index = 4;
        match1[5]: s1_index = 5;
        match1[6]: s1_index = 6;
        match1[7]: s1_index = 7;
        match1[8]: s1_index = 8;
        match1[9]: s1_index = 9;
        match1[10]: s1_index = 10;
        match1[11]: s1_index = 11;
        match1[12]: s1_index = 12;
        match1[13]: s1_index = 13;
        match1[14]: s1_index = 14;
        match1[15]: s1_index = 15;
        default   : s1_index = 0;
    endcase 
end

wire s0_choose_bit = (s0_ps == 6'd21)? s0_vppn[8] : s0_va_bit12;
wire s1_choose_bit = (s1_ps == 6'd21)? s1_vppn[8] : s1_va_bit12;

assign s0_ppn = (s0_choose_bit)? tlb_ppn1[s0_index] : tlb_ppn0[s0_index];
assign s0_ps  = tlb_ps4MB [s0_index]? 6'd21 : 6'd12; 
assign s0_mat = (s0_choose_bit)? tlb_mat1[s0_index] : tlb_mat0[s0_index];
assign s0_d   = (s0_choose_bit)? tlb_d1  [s0_index] : tlb_d0  [s0_index];
assign s0_plv = (s0_choose_bit)? tlb_plv1[s0_index] : tlb_plv0[s0_index];
assign s0_v   = (s0_choose_bit)? tlb_v1  [s0_index] : tlb_v0  [s0_index];

assign s1_ppn = (s1_choose_bit)? tlb_ppn1[s1_index] : tlb_ppn0[s1_index];
assign s1_ps  = tlb_ps4MB [s1_index]? 6'd21 : 6'd12;
assign s1_mat = (s1_choose_bit)? tlb_mat1[s1_index] : tlb_mat0[s1_index];
assign s1_d   = (s1_choose_bit)? tlb_d1  [s1_index] : tlb_d0  [s1_index];
assign s1_plv = (s1_choose_bit)? tlb_plv1[s1_index] : tlb_plv0[s1_index];
assign s1_v   = (s1_choose_bit)? tlb_v1  [s1_index] : tlb_v0  [s1_index];


// TLB write logic
always @(posedge clk) begin
    if (we) begin
        //tlb_e[w_index]     <= w_e;
        tlb_ps4MB[w_index] <= (w_ps == 21) ? 1'b1 : 1'b0;
        tlb_vppn[w_index]  <= w_vppn;
        tlb_asid[w_index]  <= w_asid;
        tlb_g[w_index]     <= w_g;
        tlb_ppn0[w_index]  <= w_ppn0;
        tlb_plv0[w_index]  <= w_plv0;
        tlb_mat0[w_index]  <= w_mat0;
        tlb_d0[w_index]    <= w_d0;
        tlb_v0[w_index]    <= w_v0;
        tlb_ppn1[w_index]  <= w_ppn1;
        tlb_plv1[w_index]  <= w_plv1;
        tlb_mat1[w_index]  <= w_mat1;
        tlb_d1[w_index]    <= w_d1;
        tlb_v1[w_index]    <= w_v1;
    end
end

// TLB read logic
assign r_e      = tlb_e[r_index];
assign r_vppn   = tlb_vppn[r_index];
assign r_ps     = tlb_ps4MB[r_index] ? 6'd21 : 6'd12;
assign r_asid   = tlb_asid[r_index];
assign r_g      = tlb_g[r_index];
assign r_ppn0   = tlb_ppn0[r_index];
assign r_plv0   = tlb_plv0[r_index];
assign r_mat0   = tlb_mat0[r_index];
assign r_d0     = tlb_d0[r_index];
assign r_v0     = tlb_v0[r_index];
assign r_ppn1   = tlb_ppn1[r_index];
assign r_plv1   = tlb_plv1[r_index];
assign r_mat1   = tlb_mat1[r_index];
assign r_d1     = tlb_d1[r_index];
assign r_v1     = tlb_v1[r_index];

// TLB invalidate logic
wire [3:0] cond[TLBNUM-1:0];
genvar i2;
generate for (i2 = 0; i2 < TLBNUM ; i2=i2+1) begin
    assign cond[i2][0] = tlb_g[i2] == 1'b1;
    assign cond[i2][1] = tlb_g[i2] == 1'b0;
    assign cond[i2][2] = s1_asid == tlb_asid[i2];
    assign cond[i2][3] = s1_vppn == tlb_vppn[i2] && !((s1_ps == 6'd21) ^ tlb_ps4MB[i2]);
end
endgenerate

genvar i3;
generate for(i3=0; i3<TLBNUM;i3=i3+1) begin
    always @(posedge clk) begin
        if (!rstn)
            tlb_e[i3] <= 1'b0;
        else if (we && (w_index == i3))
            tlb_e[w_index] <= w_e;
        else if((invtlb_op == 0 || 
                 invtlb_op == 1 || 
                 invtlb_op == 2 &&  cond[i3][0] ||
                 invtlb_op == 3 &&  cond[i3][1] ||
                 invtlb_op == 4 &&  cond[i3][1] && cond[i3][2] ||
                 invtlb_op == 5 &&  cond[i3][1] && cond[i3][2] && cond[i3][3] ||
                 invtlb_op == 6 && (cond[i3][0] || cond[i3][2]) && cond[i3][3] ) && invtlb_valid)
            tlb_e[i3] <= 1'b0;
    end
end
endgenerate

endmodule
 /*------------------------------------------------------------------------------
--------------------------------------------------------------------------------
Copyright (c) 2016, Loongson Technology Corporation Limited.

All rights reserved.

Redistribution and use in source and binary forms, with or without modification,
are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this 
list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice, 
this list of conditions and the following disclaimer in the documentation and/or
other materials provided with the distribution.

3. Neither the name of Loongson Technology Corporation Limited nor the names of 
its contributors may be used to endorse or promote products derived from this 
software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND 
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED 
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE 
DISCLAIMED. IN NO EVENT SHALL LOONGSON TECHNOLOGY CORPORATION LIMITED BE LIABLE
TO ANY PARTY FOR DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR 
CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE 
GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) 
HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT 
LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF
THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
--------------------------------------------------------------------------------
------------------------------------------------------------------------------*/

module cpu_axi_interface
(
    input         clk,
    input         resetn, 

    //inst sram-like 
    input         inst_req     ,
    input         inst_wr      ,
    input  [1 :0] inst_size    ,
    input  [31:0] inst_addr    ,
    input  [31:0] inst_wdata   ,
    output [31:0] inst_rdata   ,
    output        inst_addr_ok ,
    output        inst_data_ok ,
    
    //data sram-like 
    input         data_req     ,
    input         data_wr      ,
    input  [1 :0] data_size    ,
    input  [31:0] data_addr    ,
    input  [31:0] data_wdata   ,
    input  [3 :0] data_wstrb   ,
    output [31:0] data_rdata   ,
    output        data_addr_ok ,
    output reg    data_data_ok ,

    //axi
    //ar
    output reg [3 :0] arid         ,
    output reg [31:0] araddr       ,
    output reg [7 :0] arlen        ,
    output reg [2 :0] arsize       ,
    output reg [1 :0] arburst      ,
    output reg [1 :0] arlock        ,
    output reg [3 :0] arcache      ,
    output reg [2 :0] arprot       ,
    output reg        arvalid      ,
    input             arready      ,
    //r           
    input  [3 :0] rid          ,
    input  [31:0] rdata        ,
    input  [1 :0] rresp        ,
    input         rlast        ,
    input         rvalid       ,
    output        rready       ,
    //aw          
    output [3 :0] awid         ,
    output [31:0] awaddr       ,
    output [7 :0] awlen        ,
    output [2 :0] awsize       ,
    output [1 :0] awburst      ,
    output [1 :0] awlock       ,
    output [3 :0] awcache      ,
    output [2 :0] awprot       ,
    output        awvalid      ,
    input         awready      ,
    //w          
    output [3 :0] wid          ,
    output [31:0] wdata        ,
    output [3 :0] wstrb        ,
    output        wlast        ,
    output        wvalid       ,
    input         wready       ,
    //b           
    input  [3 :0] bid          ,
    input  [1 :0] bresp        ,
    input         bvalid       ,
    output        bready       
);
//addr
//reg do_req;
//reg do_req_or; //req is inst or data;1:data,0:inst
//reg        do_wr_r;
//reg [1 :0] do_size_r;
//reg [31:0] do_addr_r;
//reg [31:0] do_wdata_r;
//wire       data_back;
wire        arvalid_inst;
reg  [31:0] req_inst_addr;
reg         arid_inst;
reg  [31:0] req_data_addr;
reg  [ 1:0] req_data_size;
wire        arvalid_data;
reg  [31:0] awaddr_data;
reg  [ 1:0] awsize_data;
wire        awvalid_data;
wire        wvalid_data;
reg  [31:0] wdata_data;
reg  [ 3:0] wstrb_data;

//assign inst_addr_ok = !do_req&&!data_req;
//assign data_addr_ok = !do_req;
//always @(posedge clk)
//begin
//    do_req     <= !resetn                       ? 1'b0 : 
//                  (arvalid_inst||data_req)&&!do_req ? 1'b1 :
//                  data_back                     ? 1'b0 : do_req;
//    do_req_or  <= !resetn ? 1'b0 : 
//                  !do_req ? data_req : do_req_or;
//
//    do_wr_r    <= data_req&&data_addr_ok ? data_wr :
//                  inst_req&&inst_addr_ok ? inst_wr : do_wr_r;
//    do_size_r  <= data_req&&data_addr_ok ? data_size :
//                  inst_req&&inst_addr_ok ? inst_size : do_size_r;
//    do_addr_r  <= data_req&&data_addr_ok ? data_addr :
//                  arvalid_inst           ? {req_inst_addr[31:4],4'b0} : do_addr_r;
//    do_wdata_r <= data_req&&data_addr_ok ? wdata_data :
//                  inst_req&&inst_addr_ok ? inst_wdata :do_wdata_r;
//end

//inst sram-like
//assign inst_data_ok = do_req&&!do_req_or&&data_back;
//assign data_data_ok = do_req&& do_req_or&&data_back;
//assign inst_rdata   = rdata;
//assign data_rdata   = rdata;

//---axi
//reg addr_rcv;
//reg wdata_rcv;
//
//assign data_back = addr_rcv && (rvalid&&rready||bvalid&&bready);
//always @(posedge clk)
//begin
//    addr_rcv  <= !resetn          ? 1'b0 :
//                 arvalid&&arready ? 1'b1 :
//                 awvalid&&awready ? 1'b1 :
//                 data_back        ? 1'b0 : addr_rcv;
//    wdata_rcv <= !resetn        ? 1'b0 :
//                 wvalid&&wready ? 1'b1 :
//                 data_back      ? 1'b0 : wdata_rcv;
//end
localparam ST_AR_IDLE = 3'b001;
localparam ST_AR_INST = 3'b010;
localparam ST_AR_DATA = 3'b100;
reg [2:0] ar_state_reg;
reg [2:0] ar_state_next;
always @(*) begin
    case (ar_state_reg)
        ST_AR_IDLE : begin
            if (arvalid_inst) begin
                ar_state_next = ST_AR_INST;
            end
            else if (arvalid_data) begin
                ar_state_next = ST_AR_DATA;
            end
            else begin
                ar_state_next = ST_AR_IDLE;
            end
        end
        ST_AR_INST : begin
            if (arready) begin
                ar_state_next = ST_AR_IDLE;
            end
            else begin
                ar_state_next = ST_AR_INST;
            end
        end
        ST_AR_DATA : begin
            if (arready) begin
                ar_state_next = ST_AR_IDLE;
            end
            else begin
                ar_state_next = ST_AR_DATA;
            end
        end
        default   : ar_state_next = ST_AR_IDLE;
    endcase
end
always @(posedge clk) begin
    if (!resetn) begin
        ar_state_reg <= ST_AR_IDLE;
    end
    else begin
        ar_state_reg <= ar_state_next;
    end
end

//ar
always @(*) begin
    if ((ar_state_reg == ST_AR_INST) || (ar_state_next == ST_AR_INST)) begin
        arid   = {2'b01,arid_inst,1'b0};
        araddr = {req_inst_addr[31:4],4'b0};
        arlen  = 8'd3;
        arsize = 3'd2;
        arburst= 2'd1;
        arlock = 2'd0;
        arcache= 4'd0;
        arprot = 3'd0;
        arvalid= arvalid_inst;
    end
    else if ((ar_state_reg == ST_AR_DATA) || (ar_state_next == ST_AR_DATA)) begin
        arid   = 4'b1000;
        araddr = {req_data_addr[31:2],2'b0};
        arlen  = 8'd0;
        arsize = 3'd2;
        arburst= 2'd0;
        arlock = 2'd0;
        arcache= 4'd0;
        arprot = 3'd0;
        arvalid= arvalid_data;
    end
    else begin
        arid   = 4'b0;
        araddr = 32'b0;
        arlen  = 8'd0;
        arsize = 3'd0;
        arburst= 2'd0;
        arlock = 2'd0;
        arcache= 4'd0;
        arprot = 3'd0;
        arvalid= 1'b0;
    end
end
//r
assign rready  = 1'b1;

//aw
assign awid    = 4'd0001;
assign awaddr  = awaddr_data;
assign awlen   = 8'd0;
assign awsize  = awsize_data;
assign awburst = 2'd0;
assign awlock  = 2'd0;
assign awcache = 4'd0;
assign awprot  = 3'd0;
assign awvalid = awvalid_data;
//w
assign wid    = 4'd0001;
assign wdata  = wdata_data;
assign wstrb  = wstrb_data;
assign wlast  = 1'd1;
assign wvalid = wvalid_data;
//b
assign bready  = 1'b1;

// FSM
localparam ST_IDLE = 3'b001;
localparam ST_SRCH = 3'b010;
localparam ST_WAIT = 3'b100;
//localparam ST_IDLE = 3'b001;
localparam ST_SEND = 3'b010;
localparam ST_GET  = 3'b100;

reg [2:0] Ig_state_reg;
reg [2:0] Ig_state_next;
reg [2:0] Is_state_reg;
reg [2:0] Is_state_next;
wire      I_find_miss;
wire      get_new_inst;
always @(*) begin
    case (Ig_state_reg)
        ST_IDLE : begin
            if (I_find_miss) begin
                Ig_state_next = ST_SEND;
            end
            else begin
                Ig_state_next = ST_IDLE;
            end
        end
        ST_SEND : begin
            if (arvalid && arready && (arid == {2'b01,arid_inst,1'b0})) begin
                Ig_state_next = ST_GET;
            end
            else begin
                Ig_state_next = ST_SEND;
            end
        end
        ST_GET : begin
            if (I_find_miss) begin
                Ig_state_next = ST_SEND;
            end
            else if (rlast && (rid == {2'b01,arid_inst,1'b0})) begin
                Ig_state_next = ST_IDLE;
            end
            else begin
                Ig_state_next = ST_GET;
            end
        end
        default : Ig_state_next = ST_IDLE;
    endcase
end
always @(posedge clk) begin
    if (!resetn) begin
        Ig_state_reg <= ST_IDLE;
    end
    else begin
        Ig_state_reg <= Ig_state_next;
    end
end

always @(*) begin
    case (Is_state_reg)
        ST_IDLE : begin
            if (inst_req && inst_addr_ok) begin
                Is_state_next = ST_SRCH;
            end
            else begin
                Is_state_next = ST_IDLE;
            end
        end
        ST_SRCH : begin
            if (I_find_miss) begin
                Is_state_next = ST_WAIT;
            end
            else if (inst_data_ok) begin
                Is_state_next = ST_IDLE;
            end
            else begin
                Is_state_next = ST_SRCH;
            end
        end
        ST_WAIT : begin
            if (get_new_inst) begin
                Is_state_next = ST_SRCH;
            end
            else begin
                Is_state_next = ST_WAIT;
            end
        end
        default :  Is_state_next = ST_IDLE;
    endcase
end
always @(posedge clk) begin
    if (!resetn) begin
        Is_state_reg <= ST_IDLE;
    end
    else begin
        Is_state_reg <= Is_state_next;
    end
end

//inst store
reg  [31:0] first_addr;
reg  [31:0] inst_buff [3:0];
reg  [3:0]  value;
reg  [1:0]  i;

assign inst_addr_ok = (Is_state_reg == ST_IDLE) & inst_req;
always @(posedge clk) begin
    if (!resetn) begin
        req_inst_addr <= 32'b0;
    end
    else if ((Is_state_next == ST_SRCH)&&(Is_state_reg == ST_IDLE)) begin
        req_inst_addr <= inst_addr;
    end
end

assign I_find_miss  = (Is_state_reg == ST_SRCH) && (first_addr[31:4] != req_inst_addr[31:4]);
assign inst_data_ok = (Is_state_reg == ST_SRCH) && !I_find_miss && value[req_inst_addr[3:2]];
assign inst_rdata = inst_buff[req_inst_addr[3:2]];

always @(posedge clk) begin
    if (!resetn) begin
        first_addr <= 32'b0;
        arid_inst  <= 1'b0;
    end
    else if ((Ig_state_next == ST_SEND)&&(Ig_state_reg != ST_SEND)) begin
        first_addr <= {req_inst_addr[31:4],4'b0};
        arid_inst  <= ~arid_inst;
    end
end

assign arvalid_inst = (Ig_state_reg == ST_SEND);
assign get_new_inst = (Ig_state_reg == ST_GET);

always @(posedge clk) begin
    if (!resetn) begin
        value <= 4'b0;
        i            <= 2'b0;
    end
    else if (Ig_state_next == ST_SEND) begin
        value <= 4'b0;
        i            <= 2'b0;
    end
    else if (rvalid && rready && (Ig_state_reg == ST_GET) && (rid == {2'b01,arid_inst,1'b0})) begin
        inst_buff[i] <= rdata;
        value[i]     <= 1'b1;
        i            <= i + 1'b1;
    end
end


//data store
localparam ST_D_IDLE = 4'b0001;
localparam ST_D_SRCH = 4'b0011;
localparam ST_D_SC   = 4'b0010; //send aw
localparam ST_D_LOAD = 4'b0101; //load data
localparam ST_D_SD   = 4'b0100; //send w
localparam ST_D_GET  = 4'b1001; //get data
localparam ST_D_WAIT = 4'b1000; //wait for b
reg  [3:0] D_state_reg;
reg  [3:0] D_state_next;
wire       D_find_miss;

always @(*) begin
    case (D_state_reg)
        ST_D_IDLE : begin
            if (data_addr_ok && data_req && data_wr) begin
                D_state_next = ST_D_SC;
            end
            else if (data_addr_ok && data_req && !data_wr) begin
                D_state_next = ST_D_SRCH;
            end
            else begin
                D_state_next = ST_D_IDLE;
            end
        end
        ST_D_SRCH : begin
            if (D_find_miss) begin
                D_state_next = ST_D_LOAD;
            end
            else if (data_data_ok) begin
                D_state_next = ST_D_IDLE;
            end
            else begin
                D_state_next = ST_D_SRCH;
            end
        end
        ST_D_LOAD : begin
            if (arvalid && arready && (arid == 4'b1000)) begin
                D_state_next = ST_D_GET;
            end
            else begin
                D_state_next = ST_D_LOAD;
            end
        end
        ST_D_GET : begin
            if (rlast && (rid == 4'b1000)) begin
                D_state_next = ST_D_IDLE;
            end
            else begin
                D_state_next = ST_D_GET;
            end
        end
        ST_D_SC : begin
            if (awvalid && awready) begin
                D_state_next = ST_D_SD;
            end
            else begin
                D_state_next = ST_D_SC;
            end
        end
        ST_D_SD : begin
            if (wvalid && wready) begin
                D_state_next = ST_D_WAIT;
            end
            else begin
                D_state_next = ST_D_SD;
            end
        end
        ST_D_WAIT : begin
            if (bvalid && bready) begin
                D_state_next = ST_D_IDLE;
            end
            else begin
                D_state_next = ST_D_WAIT;
            end
        end
        default : D_state_next = ST_D_IDLE; 
    endcase
end
always @(posedge clk) begin
    if (!resetn) begin
        D_state_reg <= ST_D_IDLE;
    end
    else begin
        D_state_reg <= D_state_next;
    end
end

assign data_addr_ok = (D_state_reg == ST_D_IDLE) && data_req;
//data write logic
always @(posedge clk) begin
    if (!resetn) begin
        awaddr_data <= 32'b0;
        awsize_data <= 2'b0;
        wdata_data  <= 32'b0;
        wstrb_data  <= 4'b0;
    end
    else if (D_state_next == ST_D_SC) begin
        awaddr_data <= data_addr;
        awsize_data <= data_size;
        wdata_data  <= data_wdata;
        wstrb_data  <= data_wstrb;
    end
end
assign awvalid_data = (D_state_reg == ST_D_SC);
assign wvalid_data  = (D_state_reg == ST_D_SD);

//data find logic
localparam dataNUM = 16;
reg  [31:0] rf_data_addr [dataNUM-1:0];
reg  [31:0] rf_data      [dataNUM-1:0];
reg  [$clog2(dataNUM)-1:0] tag;
(*max_fanout = 20*)wire [15:0] find_buff;
wire [3:0]  find_index;
wire [31:0] write_data;
generate
    genvar k;
    for (k = 0;k < 4;k=k+1) begin
        assign write_data[k*8+7:k*8] = data_wstrb[k] ? data_wdata[k*8+7:k*8] : rf_data[find_index][k*8+7:k*8];
    end
endgenerate


integer n = 0;
always @(posedge clk) begin
  if (!resetn) begin
    tag <= 'b0;
    for (n = 0;n < dataNUM;n = n + 1) begin
      rf_data_addr[n] <= 32'b0;
      rf_data[n]      <= 32'b0;
    end
  end
  else if (D_state_reg == ST_D_SC) begin
    if (|find_buff) begin
        rf_data[find_index] <= write_data;
    end
    else if (data_size == 2'd2) begin
        tag              <= tag+1;
        rf_data_addr[tag]<= data_addr;
        rf_data[tag]     <= wdata_data;
    end
  end
end

always @(posedge clk) begin
    if (!resetn) begin
        req_data_addr <= 32'b0;
    end
    else if (data_req && data_addr_ok) begin
        req_data_addr <= data_addr;
    end
end

generate
  genvar j;
  for (j = 0; j < dataNUM; j = j + 1) begin
    assign find_buff[j] = (&(rf_data_addr[j][31:2] ^ (~req_data_addr[31:2])));
  end
endgenerate
assign D_find_miss = (D_state_reg == ST_D_SRCH) /* && !(|find_buff)  */&& 1'b1;
assign arvalid_data   = (D_state_reg == ST_D_LOAD);

oneHot2Bin u_oneHot2Bin(.oneHot(find_buff),.bin(find_index));
wire [31:0] data_find_buff = rf_data[find_index];

always @(*) begin
    case (D_state_reg)
        ST_D_SRCH : data_data_ok = !D_find_miss;
        ST_D_WAIT : data_data_ok = bvalid && bready;
        ST_D_GET  : data_data_ok = rlast && (rid == 4'b1000);
        default   : data_data_ok = 1'b0;
    endcase
end
assign data_rdata   = (D_state_reg == ST_D_GET) ? rdata : data_find_buff;
endmodule

module oneHot2Bin (
    input [15:0] oneHot,
    output reg [3:0] bin
);
always @(*) begin
  case (1'b1)
    oneHot[0] : bin = 4'd0;
    oneHot[1] : bin = 4'd1;
    oneHot[2] : bin = 4'd2;
    oneHot[3] : bin = 4'd3;
    oneHot[4] : bin = 4'd4;
    oneHot[5] : bin = 4'd5;
    oneHot[6] : bin = 4'd6;
    oneHot[7] : bin = 4'd7;
    oneHot[8] : bin = 4'd8;
    oneHot[9] : bin = 4'd9;
    oneHot[10]: bin = 4'd10;
    oneHot[11]: bin = 4'd11;
    oneHot[12]: bin = 4'd12;
    oneHot[13]: bin = 4'd13;
    oneHot[14]: bin = 4'd14;
    oneHot[15]: bin = 4'd15;
    default   : bin = 4'd0;
  endcase
end
endmodule
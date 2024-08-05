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
    output [31:0] data_rdata   ,
    output        data_addr_ok ,
    output        data_data_ok ,

    //axi
    //ar
    output [3 :0] arid         ,
    output [31:0] araddr       ,
    output [7 :0] arlen        ,
    output [2 :0] arsize       ,
    output [1 :0] arburst      ,
    output [1 :0] arlock        ,
    output [3 :0] arcache      ,
    output [2 :0] arprot       ,
    output        arvalid      ,
    input         arready      ,
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
reg do_req;
reg do_req_or; //req is inst or data;1:data,0:inst
reg        do_wr_r;
reg [1 :0] do_size_r;
reg [31:0] do_addr_r;
reg [31:0] do_wdata_r;
wire data_back;
wire       arvalid_inst;
reg  [31:0] req_inst_addr;
reg        arid_inst;

//assign inst_addr_ok = !do_req&&!data_req;
assign data_addr_ok = !do_req;
always @(posedge clk)
begin
    do_req     <= !resetn                       ? 1'b0 : 
                  (arvalid_inst||data_req)&&!do_req ? 1'b1 :
                  data_back                     ? 1'b0 : do_req;
    do_req_or  <= !resetn ? 1'b0 : 
                  !do_req ? data_req : do_req_or;

    do_wr_r    <= data_req&&data_addr_ok ? data_wr :
                  inst_req&&inst_addr_ok ? inst_wr : do_wr_r;
    do_size_r  <= data_req&&data_addr_ok ? data_size :
                  inst_req&&inst_addr_ok ? inst_size : do_size_r;
    do_addr_r  <= data_req&&data_addr_ok ? data_addr :
                  arvalid_inst           ? {req_inst_addr[31:4],4'b0} : do_addr_r;
    do_wdata_r <= data_req&&data_addr_ok ? data_wdata :
                  inst_req&&inst_addr_ok ? inst_wdata :do_wdata_r;
end

//inst sram-like
//assign inst_data_ok = do_req&&!do_req_or&&data_back;
assign data_data_ok = do_req&& do_req_or&&data_back;
//assign inst_rdata   = rdata;
assign data_rdata   = rdata;

//---axi
reg addr_rcv;
reg wdata_rcv;

assign data_back = addr_rcv && (rvalid&&rready||bvalid&&bready);
always @(posedge clk)
begin
    addr_rcv  <= !resetn          ? 1'b0 :
                 arvalid&&arready ? 1'b1 :
                 awvalid&&awready ? 1'b1 :
                 data_back        ? 1'b0 : addr_rcv;
    wdata_rcv <= !resetn        ? 1'b0 :
                 wvalid&&wready ? 1'b1 :
                 data_back      ? 1'b0 : wdata_rcv;
end
//ar
assign arid    = arvalid_inst ? {2'b0,arid_inst,1'b0} : 4'b0000;
assign araddr  = do_addr_r;
assign arlen   = arvalid_inst ? 8'd3 : 8'd0;
assign arsize  = do_size_r;
assign arburst = arvalid_inst ? 2'd1 : 2'd0;
assign arlock  = 2'd0;
assign arcache = 4'd0;
assign arprot  = 3'd0;
assign arvalid = do_req&&!do_wr_r&&!addr_rcv;
//r
assign rready  = 1'b1;

//aw
assign awid    = 4'd0001;
assign awaddr  = data_addr;
assign awlen   = 8'd0;
assign awsize  = data_size;
assign awburst = 2'd0;
assign awlock  = 2'd0;
assign awcache = 4'd0;
assign awprot  = 3'd0;
assign awvalid = do_req&&do_wr_r&&!addr_rcv;
//w
assign wid    = 4'd0001;
assign wdata  = do_wdata_r;
assign wstrb  = do_size_r==2'd0 ? 4'b0001<<do_addr_r[1:0] :
                do_size_r==2'd1 ? 4'b0011<<do_addr_r[1:0] : 4'b1111;
assign wlast  = 1'd1;
assign wvalid = do_req&&do_wr_r&&!wdata_rcv;
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
            if (arvalid && arready) begin
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
            else if (rlast) begin
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
    else if (rvalid && rready && (Ig_state_reg == ST_GET) && (rid[1] == arid_inst)) begin
        inst_buff[i] <= rdata;
        value[i]     <= 1'b1;
        i            <= i + 1'b1;
    end
end


endmodule


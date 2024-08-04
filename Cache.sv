`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/07/29 15:42:57
// Design Name: 
// Module Name: Cache
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module Cache(
    input logic clk,
    input logic resetn,


    //inst sram
    input logic         inst_sram_req,
    input logic [1:0]   inst_sram_size,
    input logic [31:0]  inst_sram_addr,
    output logic        inst_sram_addr_ok,
    output logic        inst_sram_data_ok,
    output logic [31:0] inst_sram_rdata,

    //data sram
    input  logic         data_sram_req,
    input  logic         data_sram_wr,
    input  logic [1:0]   data_sram_size,
    input  logic [3:0]   data_sram_wstrb,
    input  logic [31:0]  data_sram_addr,
    output logic         data_sram_addr_ok,
    output logic         data_sram_data_ok,
    input  logic [31:0]  data_sram_wdata,
    output logic [31:0]  data_sram_rdata,

    //axi interface
    // 写地址通道信号
    output logic [3:0]   AWID,
    output logic [31:0]  AWADDR,
    output logic [7:0]   AWLEN,
    output logic [2:0]   AWSIZE,
    output logic [1:0]   AWBURST,
    output logic         AWLOCK,
    output logic [3:0]   AWCACHE,
    output logic [2:0]   AWPROT,
    output logic [3:0]   AWQOS,
    output logic         AWVALID,
    input  logic         AWREADY,

    // 写数据通道信号
    output logic [31:0]  WDATA,
    output logic [3:0]   WSTRB,
    output logic         WLAST,
    output logic         WVALID,
    input  logic         WREADY,

    // 写响应通道信号
    input  logic [3:0]   BID,
    input  logic [1:0]   BRESP,
    input  logic         BVALID,
    output logic         BREADY,

    // 读地址通道信号
    output logic [3:0]   ARID,
    output logic [31:0]  ARADDR,
    output logic [7:0]   ARLEN,
    output logic [2:0]   ARSIZE,
    output logic [1:0]   ARBURST,
    output logic         ARLOCK,
    output logic [3:0]   ARCACHE,
    output logic [2:0]   ARPROT,
    output logic [3:0]   ARQOS,
    output logic         ARVALID,
    input  logic         ARREADY,

    // 读数据通道信号
    input  logic [3:0]   RID,
    input  logic [31:0]  RDATA,
    input  logic [1:0]   RRESP,
    input  logic         RLAST,
    input  logic         RVALID,
    output logic         RREADY
    );
parameter  INCRLEN=7;//inst read len

//寄存器堆
logic [31:0] Icache_addr;
logic [31:0] Dcache_addr;
logic [1:0] Icache_size;
logic [1:0] Dcache_size;
logic ICacheMiss = 0;
logic DCacheMiss = 0;
logic I_Cache_updated;
logic D_Cache_updated;
logic Dcache_wr;
logic [3:0] Dcache_wstrb;
logic [31:0]Dcache_wdata;
logic datastore=0;
logic Icachewrite=0;
logic Dcachewrite=0;

logic [31:0] Icollected_data[INCRLEN:0];// I收集的8个数据
logic        Idata_ready;             // 数据收集完成标志
logic [31:0] Dcollected_data;       // D收集的数据
logic        Ddata_ready;             // 数据收集完成标志

//axi读写使能与地址、数据
logic [31:0]  icache_addr;
logic         icache_valid=0;
logic [31:0]  dcache_raddr;
logic [31:0]  dcache_waddr;
logic [31:0]  dcache_wdata;
logic         dcache_we=0;
logic         dcache_rvalid=0;
logic         dcache_wvalid=0;
logic         icache_ready;
logic         dcache_ready;

//用于单周期ok
logic ICachehit = 0;



//cache定义
    typedef struct packed {
        //有效信号
        logic valid;
        //20位tag
        logic [19:0] CacheTag;  
        //定义4Byte长度为一条line
        logic [31:0] CacheData;
    } Cache_line;
    Cache_line ICache [1023:0];
    Cache_line DCache [1023:0];


    //设定cache偏移、索引、标签
    logic [1:0]  IOffset;
    logic [9:0]  IIndex;
    logic [19:0] ITag;
    logic [31:0] Itagcounter=32'b0;//用于计算写入数据的tag
    assign   IOffset =   Icache_addr[1:0];
    assign   IIndex  =   Icache_addr[11:2];
    assign   ITag    =   Icache_addr[31:12];

    logic [1:0]  DOffset;
    logic [9:0]  DIndex;
    logic [19:0] DTag;
    assign   DOffset =   Dcache_addr[1:0];
    assign   DIndex  =   Dcache_addr[11:2];
    assign   DTag    =   Dcache_addr[31:12];

    //cache初始化
    always_ff @(posedge clk) begin 
      if (!resetn) begin
        for (int i = 0;i<1024;i++) begin
            ICache[i].valid      <=0;
            ICache[i].CacheTag   <=0;
            ICache[i].CacheData   <=0;
            DCache[i].valid      <=0;
            DCache[i].CacheTag   <=0;
            DCache[i].CacheData   <=0;
        end
        inst_sram_addr_ok       <=0;
        inst_sram_data_ok       <=0;
        data_sram_addr_ok       <=0;
        data_sram_data_ok       <=0;
      end
    end

//cache状态
typedef enum logic [1:0] {
  I_IDLE,
  I_DATA,
  I_MEM_READ,
  I_UPDATE_CACHE
} state_I;
state_I I_state,I_next_state;

typedef enum logic [1:0] {
  D_IDLE,
  D_DATA,
  D_MEM_READ,
  D_UPDATE_CACHE
} state_D;
state_D D_state,D_next_state;

//cache状态机状态转换    
always_ff @(posedge clk) begin
  if (!resetn) begin
    I_state<=I_IDLE;
    D_state<=D_IDLE;
  end
  else
  I_state<=I_next_state;
  D_state<=D_next_state;
end


//Icache状态转换
always_comb begin
  I_next_state=I_state;
case (I_state)
  I_IDLE: begin
    if (inst_sram_req) begin
      I_next_state=I_DATA;
    end    
  end 

  I_DATA:begin
   if (ICache[IIndex].valid && ICache[IIndex].CacheTag==ITag) begin
    I_next_state=I_IDLE;
   end
   else if (ICacheMiss) begin
    I_next_state=I_MEM_READ;
   end    
  end

  I_MEM_READ: begin
    if (Idata_ready) begin
    I_next_state=I_UPDATE_CACHE;
    end
  end
  I_UPDATE_CACHE:begin
        I_next_state=I_IDLE;
  end
  default: I_next_state=I_IDLE;
endcase
end
//Icache数据操作
always_ff @(posedge clk)begin
    case (I_state)
    I_IDLE:begin
    Icachewrite<=0;
    inst_sram_data_ok<=0;
    I_Cache_updated<=0;
    Icache_addr<=0;    
    if (inst_sram_req) begin
        Icache_addr<=inst_sram_addr;
        Icache_size<=inst_sram_size;  
        inst_sram_addr_ok<=1;
    end        
    end
    I_DATA:begin
        inst_sram_addr_ok<=0;
        if (ICache[IIndex].valid && ICache[IIndex].CacheTag==ITag) begin
        inst_sram_rdata<=ICache[IIndex].CacheData;
        inst_sram_data_ok<=1;
        end else begin
            ICacheMiss<=1;
        end        
    end
    I_MEM_READ:begin
        ICacheMiss<=0;
        icache_valid<=1;
        icache_addr<=Icache_addr;
        Itagcounter<=Icache_addr;
        end
    I_UPDATE_CACHE:begin
      Icachewrite<=1;
      icache_valid<=0;
      for (int j=0 ;j<INCRLEN+1 ;j++ ) begin
      ICache[IIndex+j].CacheData <=Icollected_data[j];
      ICache[IIndex+j].CacheTag<=Itagcounter[31:12];
      ICache[IIndex+j].valid<=1;
      Itagcounter=Icache_addr+4*j;  
      end
      inst_sram_rdata<=Icollected_data[0];
      inst_sram_data_ok<=1;
    end
    endcase
end


//Dcache状态转换
always_comb begin
  D_next_state=D_state;
case (D_state)
  D_IDLE: begin
    if (data_sram_req) begin
      D_next_state=D_DATA;
    end    
  end 

  D_DATA:begin
   if (DCache[DIndex].valid && DCache[DIndex].CacheTag==DTag) begin
    D_next_state=D_IDLE;
   end
   else if (DCacheMiss) begin
    D_next_state=D_MEM_READ;
   end
   if (Dcache_wr) begin
      D_next_state=D_IDLE;
   end  
  end

  D_MEM_READ: begin
    if (Ddata_ready) begin
    D_next_state=D_UPDATE_CACHE;
    end
  end
  D_UPDATE_CACHE:begin
        D_next_state=D_IDLE;
  end
  default: D_next_state=D_IDLE;
endcase
end

always_ff @(posedge clk)begin
case (D_state)
    D_IDLE: begin
        data_sram_data_ok<=0;
        D_Cache_updated<=0;
        dcache_rvalid<=0;
        dcache_we<=0;
        Dcachewrite<=0;
        dcache_wvalid<=0;
        Dcache_addr<=0;
        Dcache_wr<=0;
        if (data_sram_req) begin
        Dcache_addr<=data_sram_addr;
        Dcache_size<=data_sram_size;
        Dcache_wr<=data_sram_wr;
        Dcache_wstrb<=data_sram_wstrb;
        data_sram_addr_ok<=1;
    end  
    end
    D_DATA:begin
        data_sram_addr_ok<=0;
        if (!Dcache_wr) begin
            if (DCache[DIndex].valid && DCache[DIndex].CacheTag==DTag) begin
                data_sram_rdata<=DCache[DIndex].CacheData;
                data_sram_data_ok<=1;                       
                end
                else begin
            DCacheMiss<=1;
        end
        end
        else if (Dcache_wr) begin
          if (Dcache_size == 2'b00) begin
            if (DOffset==2'b00) begin
            DCache[DIndex].CacheData[7:0]<=data_sram_wdata[7:0];
            DCache[DIndex].valid<=1;
            DCache[DIndex].CacheTag<=DTag;
            end else if (DOffset==2'b01) begin
            DCache[DIndex].CacheData[15:8] <=data_sram_wdata[15:8];
            DCache[DIndex].valid<=1;
            DCache[DIndex].CacheTag<=DTag;
            end else if (DOffset== 2'b10) begin
            DCache[DIndex].CacheData[23:16] <=data_sram_wdata[23:16];
            DCache[DIndex].valid<=1;
            DCache[DIndex].CacheTag<=DTag;  
            end else if (DOffset==2'b11) begin
            DCache[DIndex].CacheData[31:24] <=data_sram_wdata[31:24];
            DCache[DIndex].valid<=1;
            DCache[DIndex].CacheTag<=DTag; 
            end  
          end
          if (Dcache_size == 2'b01) begin
            if (DOffset==2'b00) begin
            DCache[DIndex].CacheData[15:0]<=data_sram_wdata[15:0];
            DCache[DIndex].valid<=1;
            DCache[DIndex].CacheTag<=DTag;
            end
            else if (DOffset== 2'b10) begin
            DCache[DIndex].CacheData[31:16] <=data_sram_wdata[31:16];
            DCache[DIndex].valid<=1;
            DCache[DIndex].CacheTag<=DTag;  
            end
          end
          if (Dcache_size == 2'b10) begin
            DCache[DIndex].CacheData<=data_sram_wdata;
            DCache[DIndex].valid<=1;
            DCache[DIndex].CacheTag<=DTag;
          end
            dcache_wdata<=DCache[DIndex].CacheData;
            dcache_waddr<=Dcache_addr;
            dcache_wvalid<=1;
            dcache_we<=1;
            data_sram_data_ok<=1;
            datastore<=1;
        end
    end
    D_MEM_READ:begin
        DCacheMiss<=0;
        dcache_rvalid<=1;
        dcache_raddr<=Dcache_addr;
    end
    D_UPDATE_CACHE:begin
      Dcachewrite<=1;
      dcache_rvalid<=0;
      DCache[DIndex].CacheData<=Dcollected_data;
      DCache[DIndex].CacheTag<=Dcache_addr[31:12];
      DCache[DIndex].valid<=1;
      D_Cache_updated<=1;
      data_sram_rdata<=Dcollected_data;
      data_sram_data_ok<=1;
    end
endcase    
end

  //读取仲裁信号
    logic icache_selected;
    logic dcache_selected;

    // 仲裁逻辑
    always_ff @(posedge clk) begin
        if (!resetn) begin
            icache_selected <= 1'b0;
            dcache_selected <= 1'b0;
        end else begin
            if (icache_valid && !dcache_rvalid) begin
                icache_selected <= 1'b1;
                dcache_selected <= 1'b0;
            end else if (!icache_valid && dcache_rvalid) begin
                icache_selected <= 1'b0;
                dcache_selected <= 1'b1;
            end else if (icache_valid && dcache_rvalid) begin
                // 简单优先级仲裁：dcache 优先
                icache_selected <= 1'b0;
                dcache_selected <= 1'b1;
            end else begin
                icache_selected <= 1'b0;
                dcache_selected <= 1'b0;
            end
        end
    end




    //写axi总线

    //写入axi寄存器，用于保存地址和数据
    logic [31:0] address;
    logic [31:0] data;
    // 状态机状态
    typedef enum logic [1:0] {
        IDLE,        // 空闲状态
        ADDR_PHASE,  // 地址阶段
        DATA_PHASE,  // 数据阶段
        RESP_PHASE   // 响应阶段
    } state_w;

    state_w wstate, wnext_state;

    // 写地址通道信号
    assign AWID    = 4'b0000; // 示例ID
    assign AWADDR  = address;
    assign AWLEN   = 0;
    assign AWSIZE  = 3'b010; // 4字节（32位） 
    assign AWBURST = 2'b00; // 不突发
    assign AWLOCK  = 1'b0;
    assign AWCACHE = 4'b0011; // 普通非缓存可缓冲
    assign AWPROT  = 3'b000;
    assign AWQOS   = 4'b0000;
    assign AWVALID = (wstate == ADDR_PHASE);

    // 写数据通道信号
    assign WDATA   = data;
    assign WSTRB   = Dcache_size==2'd0 ? 4'b0001<<Dcache_size[1:0] :
                      Dcache_size==2'd1 ? 4'b0011<<Dcache_size[1:0] : 4'b1111; // 所有字节均有效
    assign WLAST   = 1;
    assign WVALID  = (wstate == DATA_PHASE);

    // 写响应通道信号
    assign BREADY  = (wstate == RESP_PHASE);


        // 状态机
    always_ff @(posedge clk) begin
        if (!resetn) begin
            wstate <= IDLE;
        end else begin
            wstate <= wnext_state;
        end
    end

    always_comb begin
        wnext_state = wstate;
        case (wstate)
            IDLE: begin
                if (dcache_wvalid) begin
                    address   = dcache_waddr; 
                    data      = dcache_wdata; 
                    wnext_state = ADDR_PHASE;
                end
            end
            ADDR_PHASE: begin
                if (AWREADY) begin
                    wnext_state = DATA_PHASE;
                end
            end
            DATA_PHASE: begin
                if (WREADY) begin
                    wnext_state = RESP_PHASE;
                end
            end
            RESP_PHASE: begin
                if (BVALID) begin
                    wnext_state = IDLE;
                end
            end
        endcase
    end


//读axi总线

    // 寄存器用于保存地址和数据
    logic [31:0] raddress;
    logic [7:0]  rburst_len;
    logic [1:0]  rburst;

    // 读axi状态机状态
    typedef enum logic [1:0] {
        RIDLE,        // 空闲状态
        RADDR_PHASE,  // 地址阶段
        RDATA_PHASE,   // 数据阶段
        RSTALL
    } state_r;
    state_r rstate, rnext_state;

        // 读地址通道信号
    assign ARID    = 4'b0000; // 示例ID
    assign ARADDR  = raddress;
    assign ARLEN   = rburst_len;
    assign ARSIZE  = 3'b010; // 4字节（32位）
    assign ARBURST = rburst; // INCR突发
    assign ARLOCK  = 1'b0;
    assign ARCACHE = 4'b0000; // 普通非缓存可缓冲
    assign ARPROT  = 3'b000;
    assign ARQOS   = 4'b0000;
    assign ARVALID = (rstate == RADDR_PHASE);

    // 读数据通道信号
    assign RREADY  = (rstate == RDATA_PHASE);


    //有效信号
  logic DVALID;
  logic IVALID;
  logic [INCRLEN:0] counter;

     // 状态机
    always_ff @(posedge clk) begin
        if (!resetn) begin
            rstate <= RIDLE;
            counter<=0;
        end else begin
            rstate <= rnext_state;
            if (rstate == RSTALL) begin
              counter<=0;
            end
            if (rstate == RDATA_PHASE && RVALID && IVALID) begin
            Icollected_data[counter]<=RDATA;
            counter<=counter+1;
            end
            if (rstate == RDATA_PHASE && RVALID && DVALID) begin
            Dcollected_data<=RDATA;
            end
        end
    end



    always_comb begin
        rnext_state = rstate;
        Idata_ready = 1'b0;
        Ddata_ready =1'b0;  
        case (rstate)
            RIDLE: begin
                if (icache_valid || dcache_rvalid) begin
                  if (icache_selected) begin
                    raddress   = icache_addr;
                    rburst =2'b01;
                    rburst_len = INCRLEN;
                    rnext_state = RADDR_PHASE;
                    IVALID = 1;
                    DVALID = 0;                    
                  end
                  else if (dcache_selected) begin
                    raddress   = dcache_raddr;
                    rburst_len = 0;
                    rburst =2'b00;
                    rnext_state = RADDR_PHASE;
                    IVALID = 0;
                    DVALID = 1;  
                  end
                end
            end
            RADDR_PHASE: begin
                if (ARREADY) begin
                    rnext_state = RDATA_PHASE;
                end
            end
            RDATA_PHASE: begin
                if (RVALID && RLAST) begin
                  if (IVALID) begin
                    Idata_ready = 1'b1;
                  end
                  if (DVALID) begin
                    Ddata_ready =1'b1;
                  end
                    rnext_state = RSTALL;  
                end
            end
            RSTALL:begin
              rnext_state = RIDLE;
            end
        endcase
    end

endmodule


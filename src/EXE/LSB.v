// `include "/mnt/d/Coding/RISCV-CPU/riscv/src/defines.v"
`include "../src/defines.v"

// `include "D:/Coding/RISCV-CPU/riscv/src/defines.v"

// Load & Store Buffer
module LSB(
    input wire clk_in,
  	input wire rst_in,
  	input wire rdy_in,

    // dispatcher
    input wire en_signal_from_dispatcher,
    input wire [5:0] inst_name_from_dispatcher,
    input wire [4:0] Q1_from_dispatcher,
    input wire [4:0] Q2_from_dispatcher,
    input wire [31:0] V1_from_dispatcher,
    input wire [31:0] V2_from_dispatcher,
    input wire [31:0] imm_from_dispatcher,
    input wire [4:0] rob_id_from_dispatcher,

    // send to LSU
    output reg en_signal_to_lsu,
    output reg [5:0] inst_name_to_lsu,
    output reg [31:0] store_value_to_lsu,
    output reg [31:0] mem_addr_to_lsu,

    // send it to execute
    output reg [4:0] rob_id_to_exe,

    // ALU
    input wire valid_from_alu,
    input wire [31:0] result_from_alu,
    input wire [4:0] rob_id_from_alu,

    // LSU
    input wire busy_from_lsu,
    input wire valid_from_lsu,
    input wire [31:0] result_from_lsu,
    input wire [4:0] rob_id_from_lsu,

    // RoB
    input wire commit_flag_from_rob,
    input wire [4:0] rob_id_from_rob,
    input wire [4:0] head_io_rob_id_from_rob,

    // specify i/o
    output wire [4:0] io_rob_id_to_rob,

    // fetcher
    output wire full_to_fetcher,

    input wire rollback_flag_from_rob
);

localparam LSB_SIZE = 16;
`define LSBLen LSB_SIZE - 1 : 0

// store_tail 表示 store 类指令的 tail，会修改 mem
reg [4:0] head, tail, store_tail;
wire [4:0] next_head = (head == LSB_SIZE - 1) ? 0 : head + 1, next_tail = (tail == LSB_SIZE - 1) ? 0 : tail + 1;

integer i;

// LSB Node
reg [`LSBLen] busy;
reg [5:0] inst_name [`LSBLen];
reg [4:0] Q1 [`LSBLen];
reg [4:0] Q2 [`LSBLen];
reg [31:0] V1 [`LSBLen];
reg [31:0] V2 [`LSBLen];
reg [4:0] rob_id [`LSBLen];  // inst destination
reg [`LSBLen] is_committed;

reg [31:0] imm [`LSBLen];

wire [31:0] head_addr = V1[head] + imm[head];   // 提前计算 ls指令的目标地址
assign io_rob_id_to_rob = (head_addr == `RAM_IO_PORT) ? rob_id[head] : 0;

reg [3:0] element_cnt;
assign full_to_fetcher = (element_cnt >= LSB_SIZE - `FULL_WARNING);     // optimization
wire [31:0] insert_cnt = en_signal_from_dispatcher ? 1 : 0;
wire [31:0] issue_cnt = (((busy[head] && !busy_from_lsu && Q1[head] == 0 && Q2[head] == 0) && ((inst_name[head] <= `LHU && (head_addr != `RAM_IO_PORT || head_io_rob_id_from_rob == rob_id[head])) || (is_committed[head]))) ? -1 : 0);


// query Q/V again
// alu -> lsu
wire [4:0] real_Q1 = (valid_from_alu && Q1_from_dispatcher == rob_id_from_alu) ? 0 : ((valid_from_lsu && Q1_from_dispatcher == rob_id_from_lsu) ? 0 : Q1_from_dispatcher);
wire [4:0] real_Q2 = (valid_from_alu && Q2_from_dispatcher == rob_id_from_alu) ? 0 : ((valid_from_lsu && Q2_from_dispatcher == rob_id_from_lsu) ? 0 : Q2_from_dispatcher);
wire [31:0] real_V1 = (valid_from_alu && Q1_from_dispatcher == rob_id_from_alu) ? result_from_alu : ((valid_from_lsu && Q1_from_dispatcher == rob_id_from_lsu) ? result_from_lsu : V1_from_dispatcher);
wire [31:0] real_V2 = (valid_from_alu && Q2_from_dispatcher == rob_id_from_alu) ? result_from_alu : ((valid_from_lsu && Q2_from_dispatcher == rob_id_from_lsu) ? result_from_lsu : V2_from_dispatcher);


// for debug
integer debug_is_commit_now = -1;
assign debug_V1_head = V1[head];
assign debug_V2_head = V2[head];
assign debug_V1_tail = V1[tail];
assign debug_V2_tail = V2[tail];
assign debug_Q1_head = Q1[head];
assign debug_Q2_head = Q2[head];
assign debug_Q1_tail = Q1[tail];
assign debug_Q2_head = Q2[tail];
assign debug_imm_head = imm[head];
assign debug_imm_tail = imm[tail];

always @(posedge clk_in) begin
    if (rst_in || (rollback_flag_from_rob && store_tail == LSB_SIZE)) begin
        // store_tail 越界 & rollback_flag
        element_cnt <= 0;
        head <= 0;
        tail <= 0;
        store_tail <= LSB_SIZE; //
        en_signal_to_lsu <= 0;
        for (i = 0; i < LSB_SIZE; i = i + 1) begin
            busy[i] <= 0;
            inst_name[i] <= 0;
            Q1[i] <= 0;
            Q2[i] <= 0;
            V1[i] <= 0;
            V2[i] <= 0;
            rob_id[i] <= 0;
            imm[i] <= 0;
            is_committed[i] <= 0;
        end
    end
    else if (!rdy_in) begin
    end
    else begin
        if (rollback_flag_from_rob) begin
            tail <= (store_tail == LSB_SIZE - 1) ? 0 : (store_tail + 1);
            element_cnt <= (store_tail > head) ? store_tail - head + 1 : LSB_SIZE - head + store_tail + 1;
            for (i = 0; i < LSB_SIZE; i = i + 1) 
                if (!is_committed[i] || inst_name[i] <= `LHU) busy[i] <= 0;
        end
        else begin
            en_signal_to_lsu <= 0;
            element_cnt <= element_cnt + insert_cnt + issue_cnt;

            // execute
            if (busy[head] && !busy_from_lsu && Q1[head] == 0 && Q2[head] == 0) begin
                // load
                if (inst_name[head] <= `LHU) begin  
                    if (head_addr != `RAM_IO_PORT || head_io_rob_id_from_rob == rob_id[head]) begin
                        busy[head] <= 0;
                        rob_id[head] <= 0;
                        is_committed[head] <= 0;
                        
                        en_signal_to_lsu <= 1;
                        inst_name_to_lsu <= inst_name[head];
                        mem_addr_to_lsu <= head_addr;
                        rob_id_to_exe <= rob_id[head];
                        
                        head <= next_head;
                    end
                end
                // store
                else begin
                    if (is_committed[head]) begin
                        busy[head] <= 0;
                        rob_id[head] <= 0;
                        is_committed[head] <= 0;

                        en_signal_to_lsu <= 1;
                        inst_name_to_lsu <= inst_name[head];
                        mem_addr_to_lsu <= head_addr;
                        store_value_to_lsu <= V2[head];
                        rob_id_to_exe <= rob_id[head];

                        // store_tail is invalid
                        // it's an empty queue for store
                        if (head == store_tail) store_tail <= LSB_SIZE;
                        head <= next_head;
                    end
                end
            end

            // update when commit
            if (commit_flag_from_rob) begin
                for (i = 0; i < LSB_SIZE; i = i + 1) begin
                    if (busy[i] && rob_id[i] == rob_id_from_rob && !is_committed[i]) begin
                        is_committed[i] <= 1;
                        // get store_tail
                        if (inst_name[i] >= `SB) store_tail <= i;
                    end
                end
            end

            // update
            if (valid_from_alu) begin
                for (i = 0; i < LSB_SIZE; i = i + 1) begin
                    if (Q1[i] == rob_id_from_alu) begin
                        V1[i] <= result_from_alu;
                        Q1[i] <= 0;
                    end
                    if (Q2[i] == rob_id_from_alu) begin
                        V2[i] <= result_from_alu;
                        Q2[i] <= 0;
                    end
                end
            end
            if (valid_from_lsu) begin
                for (i = 0; i < LSB_SIZE; i = i + 1) begin
                    if (Q1[i] == rob_id_from_lsu) begin
                        V1[i] <= result_from_lsu;
                        Q1[i] <= 0;
                    end
                    if (Q2[i] == rob_id_from_lsu) begin
                        V2[i] <= result_from_lsu;
                        Q2[i] <= 0;
                    end
                end
            end

            // insert
            if (en_signal_from_dispatcher) begin
                busy[tail] <= 1;
                inst_name[tail] <= inst_name_from_dispatcher;
                Q1[tail] <= real_Q1;
                Q2[tail] <= real_Q2;
                V1[tail] <= real_V1;
                V2[tail] <= real_V2;
                imm[tail] <= imm_from_dispatcher;
                rob_id[tail] <= rob_id_from_dispatcher;
                is_committed[tail] <= 0;
                
                tail <= next_tail;
            end
        end
    end
end

endmodule
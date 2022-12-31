// `include "/mnt/d/Coding/RISCV-CPU/riscv/src/defines.v"
`include "../src/defines.v"

// `include "D:/Coding/RISCV-CPU/riscv/src/defines.v"

// Reservation Rtation
module RS(
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
    input wire [31:0] pc_from_dispatcher,
    input wire [31:0] imm_from_dispatcher,
    input wire [4:0] rob_id_from_dispatcher,    // real id

    // send to ALU
    output reg [5:0] inst_name_to_alu,
    output reg [31:0] V1_to_alu,
    output reg [31:0] V2_to_alu,
    output reg [31:0] pc_to_alu,
    output reg [31:0] imm_to_alu,

    // send it to execute
    output reg [4:0] rob_id_to_exe,

    // ALU
    input wire valid_from_alu,
    input wire [31:0] result_from_alu,
    input wire [4:0] rob_id_from_alu,

    // LSU
    input wire valid_from_lsu,
    input wire [31:0] result_from_lsu,
    input wire [4:0] rob_id_from_lsu,

    // fetcher
    output wire full_to_fetcher,
    // rob
    input wire rollback_flag_from_rob
);

// Reservation Station, a buffer for instruction in EXE

localparam RS_SIZE = 16;
`define RSLen RS_SIZE - 1 : 0

// RS Node
reg [`RSLen] busy;
reg [5:0] inst_name [`RSLen];
reg [4:0] Q1 [`RSLen];      // V1 will be updated by the Q1 inst in RoB
reg [4:0] Q2 [`RSLen];
reg [31:0] V1 [`RSLen];     // rs1 data
reg [31:0] V2 [`RSLen];
reg [31:0] pc [`RSLen];
reg [4:0] rob_id [`RSLen];  // currnet inst's id in RoB

reg [31:0] imm [`RSLen];

// query Q/V again
// updated by alu -> lsu
wire [4:0] real_Q1 = (valid_from_alu && Q1_from_dispatcher == rob_id_from_alu) ? 0 : ((valid_from_lsu && Q1_from_dispatcher == rob_id_from_lsu) ? 0 : Q1_from_dispatcher);
wire [4:0] real_Q2 = (valid_from_alu && Q2_from_dispatcher == rob_id_from_alu) ? 0 : ((valid_from_lsu && Q2_from_dispatcher == rob_id_from_lsu) ? 0 : Q2_from_dispatcher);
wire [31:0] real_V1 = (valid_from_alu && Q1_from_dispatcher == rob_id_from_alu) ? result_from_alu : ((valid_from_lsu && Q1_from_dispatcher == rob_id_from_lsu) ? result_from_lsu : V1_from_dispatcher);
wire [31:0] real_V2 = (valid_from_alu && Q2_from_dispatcher == rob_id_from_alu) ? result_from_alu : ((valid_from_lsu && Q2_from_dispatcher == rob_id_from_lsu) ? result_from_lsu : V2_from_dispatcher);

integer i;
wire [4:0] empty_index;   // 压位成一个表示状态的5位二进制数
wire [4:0] exe_index;
// if index == RS_SIZE, then it's invalid
assign full_to_fetcher = (empty_index == RS_SIZE - `FULL_WARNING);

assign empty_index = ~busy[0] ? 0 : (~busy[1] ? 1 : (~busy[2] ? 2 : (~busy[3] ? 3 :
                    (~busy[4] ? 4 : (~busy[5] ? 5 : (~busy[6] ? 6 : (~busy[7] ? 7 :
                    (~busy[8] ? 8 : (~busy[9] ? 9 : (~busy[10] ? 10 : (~busy[11] ? 11 :
                    (~busy[12] ? 12 : (~busy[13] ? 13 : (~busy[14] ? 14 : (~busy[15] ? 15 :
                    RS_SIZE)))))))))))))));
assign exe_index = (busy[0] && Q1[0] == 0 && Q2[0] == 0) ? 0 :
                    ((busy[1] && Q1[1] == 0 && Q2[1] == 0) ? 1 :
                    ((busy[2] && Q1[2] == 0 && Q2[2] == 0) ? 2 :
                    ((busy[3] && Q1[3] == 0 && Q2[3] == 0) ? 3 :
                    ((busy[4] && Q1[4] == 0 && Q2[4] == 0) ? 4 :
                    ((busy[5] && Q1[5] == 0 && Q2[5] == 0) ? 5 :
                    ((busy[6] && Q1[6] == 0 && Q2[6] == 0) ? 6 :
                    ((busy[7] && Q1[7] == 0 && Q2[7] == 0) ? 7 :
                    ((busy[8] && Q1[8] == 0 && Q2[8] == 0) ? 8 :
                    ((busy[9] && Q1[9] == 0 && Q2[9] == 0) ? 9 :
                    ((busy[10] && Q1[10] == 0 && Q2[10] == 0) ? 10 :
                    ((busy[11] && Q1[11] == 0 && Q2[11] == 0) ? 11 :
                    ((busy[12] && Q1[12] == 0 && Q2[12] == 0) ? 12 :
                    ((busy[13] && Q1[13] == 0 && Q2[13] == 0) ? 13 :
                    ((busy[14] && Q1[14] == 0 && Q2[14] == 0) ? 14 :
                    ((busy[15] && Q1[15] == 0 && Q2[15] == 0) ? 15 :
                    RS_SIZE)))))))))))))));  
// 能执行的就先执行，实现 '乱序'

always @(posedge clk_in) begin
    if (rst_in || rollback_flag_from_rob) begin     // remember to clear RS when rollback
        for (i = 0;i < RS_SIZE; i = i + 1) begin
            busy[i] <= 0;
            inst_name[i] <= `NOP;
            Q1[i] <= 0;
            Q2[i] <= 0;
            V1[i] <= 0;
            V2[i] <= 0;
            pc[i] <= 0;
            rob_id[i] <= 0;
            imm[i] <= 0;
        end
    end
    else if (!rdy_in) begin
    end
    else begin
        // no busy inst
        if (exe_index == RS_SIZE) begin
            inst_name_to_alu = `NOP;
        end
        else begin
            // issue(send) the value to alu
            busy[exe_index] <= 0;
            inst_name_to_alu <= inst_name[exe_index];
            V1_to_alu <= V1[exe_index];
            V2_to_alu <= V2[exe_index];
            pc_to_alu <= pc[exe_index];
            imm_to_alu <= imm[exe_index];
            
            rob_id_to_exe <= rob_id[exe_index];
        end

        // update
        if (valid_from_alu) begin
            for (i = 0; i < RS_SIZE; i = i + 1) begin
                if (Q1[i] == rob_id_from_alu) begin
                    V1[i] <= result_from_alu;
                    Q1[i] <= 0;         // the data(V) is ready
                end
                if (Q2[i] == rob_id_from_alu) begin
                    V2[i] <= result_from_alu;
                    Q2[i] <= 0;
                end
            end
        end
        if (valid_from_lsu) begin
            for (i = 0; i < RS_SIZE; i = i + 1) begin
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
        if (en_signal_from_dispatcher && empty_index != RS_SIZE) begin
            busy[empty_index] <= 1;
            inst_name[empty_index] <= inst_name_from_dispatcher;
            Q1[empty_index] <= real_Q1;
            Q2[empty_index] <= real_Q2;
            V1[empty_index] <= real_V1;
            V2[empty_index] <= real_V2;
            pc[empty_index] <= pc_from_dispatcher;
            imm[empty_index] <= imm_from_dispatcher;
            rob_id[empty_index] <= rob_id_from_dispatcher;
        end
    end
end

endmodule
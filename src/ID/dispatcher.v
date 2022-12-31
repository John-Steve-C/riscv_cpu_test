// `include "/mnt/d/Coding/RISCV-CPU/riscv/src/ID/decoder.v"

// `include "/mnt/d/Coding/RISCV-CPU/riscv/src/defines.v"
`include "../src/defines.v"     // 似乎 vscode 的插件无法识别相对路径?

// `include "D:/Coding/RISCV-CPU/riscv/src/defines.v"

// transfer the data and signals
module dispatcher (
    input wire clk_in,
  	input wire rst_in,
  	input wire rdy_in,

    // fetcher
    input wire [31:0] pc_from_fetcher,
	input wire [31:0] rollback_pc_from_fetcher,
    input wire [31:0] inst_from_fetcher,
	input wire ok_flag_from_fetcher,
	input wire predicted_jump_from_fetcher,

    // RoB
    output reg en_signal_to_rob,
    output reg [4:0] rd_to_rob,
    output reg is_jump_to_rob,
    output reg is_store_to_rob,
    output reg predicted_jump_to_rob,
    output reg [31:0] pc_to_rob,
    
    input wire [4:0] rob_id_from_rob,
    output reg [31:0] rollback_pc_to_rob,

    // query V(data) from RoB to speed up
    output wire [4:0] Q1_to_rob,
    output wire [4:0] Q2_to_rob,
    input wire Q1_ready_from_rob,
    input wire Q2_ready_from_rob,
    input wire [31:0] data1_from_rob,
    input wire [31:0] data2_from_rob,
    input wire rollback_flag_from_rob,

    // RegFile
    output reg en_signal_to_reg,
    output reg [4:0] rd_to_reg,
    output wire [4:0] Q_to_reg,

    output wire [4:0] rs1_to_reg,
    output wire [4:0] rs2_to_reg,
    input wire [4:0] Q1_from_reg,
    input wire [4:0] Q2_from_reg,
    input wire [31:0] V1_from_reg,
    input wire [31:0] V2_from_reg,

    // RS
    output reg en_signal_to_rs,
    output reg [5:0] inst_name_to_rs,
    output reg [4:0] Q1_to_rs,
    output reg [4:0] Q2_to_rs,
    output reg [31:0] V1_to_rs,
    output reg [31:0] V2_to_rs,
    output reg [31:0] imm_to_rs,
    output reg [31:0] pc_to_rs,
    output wire [4:0] rob_id_to_rs,     // pass rob_id

    // LSB
    output reg en_signal_to_lsb,
    output reg [5:0] inst_name_to_lsb,
    output reg [4:0] Q1_to_lsb,
    output reg [4:0] Q2_to_lsb,
    output reg [31:0] V1_to_lsb,
    output reg [31:0] V2_to_lsb,
    output reg [31:0] imm_to_lsb,
    output wire [4:0] rob_id_to_lsb,

    // ALU
    input wire valid_from_alu,
    input wire [31:0] result_from_alu,
    input wire [4:0] rob_id_from_alu,

    // LSU
    input wire valid_from_lsu,
    input wire [31:0] result_from_lsu,
    input wire [4:0] rob_id_from_lsu
);

wire jump_from_decoder, store_from_decoder;
wire [5:0] inst_name_from_decoder;
wire [4:0] rd_from_decoder, rs1_from_decoder, rs2_from_decoder;
wire [31:0] imm_from_decoder;

decoder dec(
    .inst(inst_from_fetcher),

    .jump(jump_from_decoder),
    .is_store(store_from_decoder),
    .inst_name(inst_name_from_decoder),
    .rd(rd_from_decoder),
    .rs1(rs1_from_decoder),
    .rs2(rs2_from_decoder),
    .imm(imm_from_decoder)
);

assign Q1_to_rob = Q1_from_reg;
assign Q2_to_rob = Q2_from_reg;

assign rs1_to_reg = rs1_from_decoder;
assign rs2_to_reg = rs2_from_decoder;

assign Q_to_reg = rob_id_from_rob;
assign rob_id_to_rs = rob_id_from_rob;
assign rob_id_to_lsb = rob_id_from_rob;

// get real(newest) Q and V
// query V in ALU/LSU first, then RoB, last Reg
wire [4:0] real_Q1 = (valid_from_alu && Q1_from_reg == rob_id_from_alu) ? 0 : ((valid_from_lsu && Q1_from_reg == rob_id_from_lsu) ? 0 : (Q1_ready_from_rob ? 0 : Q1_from_reg));
wire [4:0] real_Q2 = (valid_from_alu && Q2_from_reg == rob_id_from_alu) ? 0 : ((valid_from_lsu && Q2_from_reg == rob_id_from_lsu) ? 0 :(Q2_ready_from_rob ? 0 : Q2_from_reg));
wire [31:0] real_V1 = (valid_from_alu && Q1_from_reg == rob_id_from_alu) ? result_from_alu : ((valid_from_lsu && Q1_from_reg == rob_id_from_lsu) ? result_from_lsu :(Q1_ready_from_rob ? data1_from_rob : V1_from_reg));
wire [31:0] real_V2 = (valid_from_alu && Q2_from_reg == rob_id_from_alu) ? result_from_alu : ((valid_from_lsu && Q2_from_reg == rob_id_from_lsu) ? result_from_lsu :(Q2_ready_from_rob ? data2_from_rob : V2_from_reg));

always @(posedge clk_in) begin
    if (rst_in || !rdy_in || inst_name_from_decoder == `NOP || !ok_flag_from_fetcher || rollback_flag_from_rob) begin
        en_signal_to_rob <= 0;
        en_signal_to_lsb <= 0;
        en_signal_to_rs <= 0;
        en_signal_to_reg <= 0;
    end
    else begin
        // rs
        inst_name_to_rs <= inst_name_from_decoder;
        pc_to_rs <= pc_from_fetcher;
        imm_to_rs <= imm_from_decoder;
        Q1_to_rs <= real_Q1;
        Q2_to_rs <= real_Q2;
        V1_to_rs <= real_V1;
        V2_to_rs <= real_V2;

        // lsb
        inst_name_to_lsb <= inst_name_from_decoder;
        imm_to_lsb <= imm_from_decoder;
        Q1_to_lsb <= real_Q1;
        Q2_to_lsb <= real_Q2;
        V1_to_lsb <= real_V1;
        V2_to_lsb <= real_V2;

        // reg
        rd_to_reg <= rd_from_decoder;

        // rob
        rd_to_rob <= rd_from_decoder;
        is_jump_to_rob <= jump_from_decoder;
        is_store_to_rob <= store_from_decoder;
        predicted_jump_to_rob <= predicted_jump_from_fetcher;
        pc_to_rob <= pc_from_fetcher;
        rollback_pc_to_rob <= rollback_pc_from_fetcher;

        // modify en_signals
        // 保证必须有具体值，防止 latch
        en_signal_to_rob <= 0;
        en_signal_to_lsb <= 0;
        en_signal_to_rs <= 0;
        en_signal_to_reg <= 0;      
        if (ok_flag_from_fetcher) begin
            en_signal_to_rob <= 1;
            en_signal_to_reg <= 1;
            if (inst_name_from_decoder >= `LB && inst_name_from_decoder <= `SW) en_signal_to_lsb <= 1;
            else en_signal_to_rs <= 1;
        end
    end
end


endmodule
// `include "/mnt/d/Coding/RISCV-CPU/riscv/src/defines.v"
`include "../src/defines.v"

// `include "D:/Coding/RISCV-CPU/riscv/src/defines.v"

module ALU(
    // input wire clk_in,
    // input wire rst_in,

    input wire [5:0] inst_name,
    input wire [31:0] V1,
    input wire [31:0] V2,
    input wire [31:0] imm,
    input wire [31:0] pc,

    output reg [31:0] result,
    output reg [31:0] target_pc,
    output reg jump,
    output reg valid
);
// the EXE of RS
// can be implemented by non-blocking evaluation? is there any difference?
// 直接用组合逻辑实现

always @(*) begin
    valid = inst_name == `NOP ? 0 : 1;
    jump = 0;
    target_pc = 0;
    result = 0;

    case (inst_name)
        `LUI : begin
            result = imm;
        end
        `AUIPC : begin
            result = pc + imm;
        end
        `JAL : begin
            target_pc = pc + imm;
            result = pc + 4;
            jump = 1;
        end    
        `JALR : begin
            target_pc = V1 + imm;
            result = pc + 4;
            jump = 1;
        end
        `BEQ : begin
            target_pc = pc + imm;
            jump = (V1 == V2);
        end    
        `BNE : begin
            target_pc = pc + imm;
            jump = (V1 != V2);   
        end     
        `BLT : begin
            target_pc = pc + imm;
            jump = ($signed(V1) < $signed(V2));
        end    
        `BGE : begin
            target_pc = pc + imm;
            jump = ($signed(V1) >= $signed(V2));
        end    
        `BLTU : begin
            target_pc = pc + imm;
            jump = (V1 < V2);
        end    
        `BGEU : begin
            target_pc = pc + imm;
            jump = (V1 >= V2);
        end    
        `ADD : begin
            result = V1 + V2;
        end
        `SUB : begin
            result = V1 - V2;
        end
        `SLL : begin
            result = (V1 << V2);
        end
        `SLT : begin
            result = ($signed(V1) < $signed(V2));
        end
        `SLTU : begin
            result = (V1 < V2);
        end
        `XOR : begin
            result = V1 ^ V2;
        end
        `SRL : begin
            result = (V1 >> V2);
        end
        `SRA : begin
            result = (V1 >>> V2);
        end
        `OR : begin
            result = (V1 | V2);
        end
        `AND : begin
            result = (V1 & V2);
        end
        `ADDI : begin
            result = V1 + imm;
        end
        `SLLI : begin
            result = (V1 << imm);
        end
        `SLTI : begin
            result = ($signed(V1) < $signed(imm));
        end
        `SLTIU : begin
            result = (V1 < imm);  
        end
        `XORI : begin
            result = V1 ^ imm;
        end     
        `SRLI : begin
            result = (V1 >> imm);
        end
        `SRAI : begin  
            result = (V1 >>> imm);
        end
        `ORI : begin
            result = (V1 | imm);
        end
        `ANDI : begin
            result = (V1 & imm);
        end
    endcase

    // modify branch result
    if (inst_name >= `BEQ && inst_name <= `BGEU) result = jump;
end

endmodule
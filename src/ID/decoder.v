// `include "/mnt/d/Coding/RISCV-CPU/riscv/src/defines.v"
`include "../src/defines.v"

// `include "D:/Coding/RISCV-CPU/riscv/src/defines.v"

module decoder(
    input wire [31:0] inst,

    output reg jump,
    output reg is_store,
    output reg [5:0] inst_name,
    output reg [4:0] rd,
    output reg [4:0] rs1,
    output reg [4:0] rs2,
    output reg [31:0] imm
);

localparam OPCODE_LUI = 7'b0110111, OPCODE_AUIPC = 7'b0010111, OPCODE_JAL =  7'b1101111, OPCODE_JALR = 7'b1100111, OPCODE_BR = 7'b1100011, 
        OPCODE_L = 7'b0000011, OPCODE_S = 7'b0100011, OPCODE_ARITHI = 7'b0010011, OPCODE_ARITH = 7'b0110011;

localparam FUNC3_JALR = 3'b000, FUNC3_BEQ = 3'b000, FUNC3_BNE = 3'b001, FUNC3_BLT = 3'b100, FUNC3_BGE = 3'b101, FUNC3_BLTU = 3'b110, FUNC3_BGEU = 3'b111,
        FUNC3_LB = 3'b000, FUNC3_LH = 3'b001, FUNC3_LW = 3'b010, FUNC3_LBU = 3'b100, FUNC3_LHU = 3'b101, FUNC3_SB = 3'b000, FUNC3_SH = 3'b001, FUNC3_SW = 3'b010, 
        FUNC3_ADDI = 3'b000, FUNC3_SLTI = 3'b010, FUNC3_SLTIU = 3'b011, FUNC3_XORI = 3'b100, FUNC3_ORI = 3'b110, FUNC3_ANDI = 3'b111, FUNC3_SLLI = 3'b001, 
        FUNC3_SRLI = 3'b101, FUNC3_SRAI = 3'b101, FUNC3_ADD = 3'b000, FUNC3_SUB = 3'b000, FUNC3_SLL = 3'b001, FUNC3_SLT = 3'b010, FUNC3_SLTU = 3'b011, 
        FUNC3_XOR = 3'b100, FUNC3_SRL = 3'b101, FUNC3_SRA = 3'b101, FUNC3_OR = 3'b110, FUNC3_AND = 3'b111;

localparam FUNC7_SPEC = 7'b0100000;

always @(*) begin
    inst_name = `NOP;
    rd = inst[11:7];
    rs1 = inst[19:15];
    rs2 = inst[24:20];
    imm = 0;
    jump = 0;
    is_store = 0;

    case (inst[6:0])
        OPCODE_LUI, OPCODE_AUIPC: begin  
            imm = {inst[31:12], 12'b0}; // 数值直接拼接, 且 imm 需要补全到 32位
            if (inst[6:0] == OPCODE_LUI) inst_name = `LUI;
            else inst_name = `AUIPC;
        end

        OPCODE_JAL: begin
            imm = {{12{inst[31]}}, inst[19:12], inst[20], inst[30:21], 1'b0};
            inst_name = `JAL;
            jump = 1;
        end

        OPCODE_JALR, OPCODE_L, OPCODE_ARITHI: begin
            imm = {{21{inst[31]}}, inst[30:20]};
            case (inst[6:0])
                OPCODE_JALR : begin
                    inst_name = `JALR;
                    jump = 1;
                end

                OPCODE_L : begin
                    case (inst[14:12])
                        FUNC3_LB : inst_name = `LB;
                        FUNC3_LH : inst_name = `LH;
                        FUNC3_LW : inst_name = `LW;
                        FUNC3_LBU : inst_name = `LBU;
                        FUNC3_LHU : inst_name = `LHU;
                    endcase
                end

                OPCODE_ARITHI : begin
                    if (inst[14:12] == FUNC3_SRAI && inst[31:25] == FUNC7_SPEC) inst_name = `SRAI;
                    else begin
                        case (inst[14:12])
                            FUNC3_ADDI : inst_name = `ADDI;
                            FUNC3_SLTI : inst_name = `SLTI;
                            FUNC3_SLTIU : inst_name = `SLTIU;
                            FUNC3_XORI : inst_name = `XORI;
                            FUNC3_ORI : inst_name = `ORI;
                            FUNC3_ANDI : inst_name = `ANDI;
                            FUNC3_SLLI : inst_name = `SLLI;
                            FUNC3_SRLI : inst_name = `SRLI;
                        endcase
                    end
                    // shamt
                    if (inst_name == `SLLI || inst_name == `SRLI || inst_name == `SRAI) imm = imm[4:0];
                end
            endcase
        end

        OPCODE_BR: begin
            rd = 0;
            imm = {{20{inst[31]}}, inst[7:7], inst[30:25], inst[11:8], 1'b0};
            jump = 1;
            case (inst[14:12])
                FUNC3_BEQ : inst_name = `BEQ;
                FUNC3_BNE : inst_name = `BNE;
                FUNC3_BLT : inst_name = `BLT;
                FUNC3_BGE : inst_name = `BGE;
                FUNC3_BLTU : inst_name = `BLTU;
                FUNC3_BGEU : inst_name = `BGEU;
            endcase
        end

        OPCODE_S: begin
            rd = 0;
            imm = {{21{inst[31]}}, inst[30:25], inst[11:7]};
            is_store = 1;
            case (inst[14:12])
                FUNC3_SB : inst_name = `SB;
                FUNC3_SH : inst_name = `SH;
                FUNC3_SW : inst_name = `SW;
            endcase
        end

        OPCODE_ARITH: begin
            if (inst[14:12] == FUNC3_SUB && inst[31:25] == FUNC7_SPEC) inst_name = `SUB;
            else if (inst[14:12] == FUNC3_SRAI && inst[31:25] == FUNC7_SPEC) inst_name = `SRA;
            else begin
                case (inst[14:12])
                    FUNC3_ADD : inst_name = `ADD;
                    FUNC3_SLT : inst_name = `SLT;
                    FUNC3_SLTU : inst_name = `SLTU;
                    FUNC3_XOR : inst_name = `XOR;
                    FUNC3_OR : inst_name = `OR;
                    FUNC3_AND : inst_name = `AND;
                    FUNC3_SLL : inst_name = `SLL;
                    FUNC3_SRL : inst_name = `SRL;
                endcase
            end  
        end
    endcase

end

endmodule
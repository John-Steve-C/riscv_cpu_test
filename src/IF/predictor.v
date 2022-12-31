module predictor(
    input wire clk_in,
  	input wire rst_in,
  	input wire rdy_in,

    // query
    input wire [31:0] query_pc,
    input wire [31:0] query_inst,

    output wire [31:0] predict_imm,
    output wire jump,

    // update from rob
    input wire [31:0] pc_from_rob,
    input wire en_signal_from_rob,
    input wire hit_from_rob
);

localparam STRONG_NOT = 0, WEAK_NOT = 1, WEAK_JUMP = 2, STRONG_JUMP = 3;
localparam BHT_SIZE = 256;
localparam JAL_TYPE = 7'b1101111, BR_TYPE = 7'b1100011;

wire [9:2] cut_pc = pc_from_rob [9:2];   // pc += 4 (100 in binary) , so pc[1:0] is always 0, use [9:2] as identifier
reg [1:0] predict_table [BHT_SIZE - 1 : 0];   // 256 = 1 << 8

wire [31:0] J_inst_imm = {{12{query_inst[31]}}, query_inst[19:12], query_inst[20], query_inst[30:21], 1'b0};
wire [31:0] B_inst_imm = {{20{query_inst[31]}}, query_inst[7:7], query_inst[30:25], query_inst[11:8], 1'b0};

// predict jump and new pc(+= imm)
assign jump = (query_inst [6:0] == JAL_TYPE) ? 1 : (
                (query_inst [6:0] == BR_TYPE) ? (predict_table[query_pc [9:2]] > WEAK_NOT) : 0);
assign predict_imm = (query_inst [6:0] == JAL_TYPE) ? J_inst_imm : B_inst_imm;

integer i;

always @(posedge clk_in) begin
    if (rst_in) begin
        for (i = 0;i < BHT_SIZE; i = i + 1) begin
            predict_table[i] <= WEAK_NOT;
        end
    end
    else begin
        // update the predict table
        if (en_signal_from_rob) begin
            if (hit_from_rob) begin     
                // correct predict
                case (predict_table[cut_pc])
                    STRONG_JUMP, WEAK_JUMP: begin
                        predict_table[cut_pc] <= STRONG_JUMP;
                    end
                    WEAK_NOT: begin
                        predict_table[cut_pc] <= WEAK_JUMP;
                    end
                    STRONG_NOT: begin
                        predict_table[cut_pc] <= WEAK_NOT;
                    end
                endcase
            end
            else begin
                // fail
                case (predict_table[cut_pc])
                    STRONG_JUMP: begin
                        predict_table[cut_pc] <= WEAK_JUMP;
                    end
                    WEAK_JUMP: begin
                        predict_table[cut_pc] <= WEAK_NOT;
                    end
                    WEAK_NOT, STRONG_NOT: begin
                        predict_table[cut_pc] <= STRONG_NOT;
                    end
                endcase
            end
        end
    end
end

endmodule
// `include "/mnt/d/Coding/RISCV-CPU/riscv/src/defines.v"
`include "../src/defines.v"

// `include "D:/Coding/RISCV-CPU/riscv/src/defines.v"

module LSU(
    input wire clk_in,
    input wire rst_in,
    input wire rdy_in,

    input wire enable_signal,
    input wire [5:0] inst_name,
    input wire [31:0] mem_addr,
    input wire [31:0] store_value,
    
    output reg valid,
    output reg [31:0] result,

    // mem_store
    output reg en_signal_to_mem,
    output reg [31:0] addr_to_mem,
    output reg [31:0] data_to_mem,
    output reg rw_flag_to_mem,
    output reg [2:0] size_to_mem,
    // mem_load
    input wire ok_flag_from_mem,
    input wire [31:0] data_from_mem,

    // LSB
    output wire busy_to_lsb,

    // rob
    input wire rollback_flag_from_rob
);
// the EXE of LSB

localparam IDLE = 0, LB = 1, LH = 2, LW = 3, LBU = 4, LHU = 5, STORE = 6;
reg [2:0] status;
assign busy_to_lsb = (status != IDLE || enable_signal);

always @(posedge clk_in) begin
    if (rst_in) begin
        en_signal_to_mem <= 0;
        valid <= 0;
        status <= IDLE;
    end
    else if (!rdy_in) begin
    end
    else begin
        if (status != IDLE) begin
            en_signal_to_mem <= 0;
            if (rollback_flag_from_rob && status != STORE) status <= IDLE;
            else begin
                if (ok_flag_from_mem) begin
                    if (status != STORE) begin
                        valid <= 1;
                        case (status)
                            LB: result <= {{25{data_from_mem[7]}}, data_from_mem[6:0]};
                            LH: result <= {{17{data_from_mem[15]}}, data_from_mem[14:0]};
                            LW: result <= data_from_mem;
                            LBU: result <= {24'b0, data_from_mem[7:0]};
                            LHU: result <= {16'b0, data_from_mem[15:0]};
                        endcase
                    end
                    status <= IDLE;
                end
            end
        end
        // IDLE status
        else begin
            valid <= 0;
            if (!enable_signal || inst_name == `NOP) en_signal_to_mem <= 0;
            else begin
                en_signal_to_mem <= 1;
                case (inst_name)
                    `LB: begin
                        addr_to_mem <= mem_addr;
                        rw_flag_to_mem <= `READ_FLAG;
                        size_to_mem <= 1;
                        status <= LB;
                    end
                    `LH: begin
                        addr_to_mem <= mem_addr;
                        rw_flag_to_mem <= `READ_FLAG;
                        size_to_mem <= 2;
                        status <= LH;
                    end
                    `LW: begin
                        addr_to_mem <= mem_addr;
                        rw_flag_to_mem <= `READ_FLAG;
                        size_to_mem <= 4;
                        status <= LW;
                    end
                    `LBU: begin
                        addr_to_mem <= mem_addr;
                        rw_flag_to_mem <= `READ_FLAG;
                        size_to_mem <= 1;
                        status <= LBU;
                    end
                    `LHU : begin
                        addr_to_mem <= mem_addr;
                        rw_flag_to_mem <= `READ_FLAG;
                        size_to_mem <= 2;
                        status <= LHU;
                    end
                    `SB: begin
                       addr_to_mem <= mem_addr;
                       data_to_mem <= store_value;
                       rw_flag_to_mem <= `WRITE_FLAG;
                       size_to_mem <= 1;
                       status <= STORE;
                    end
                    `SH: begin
                       addr_to_mem <= mem_addr;
                       data_to_mem <= store_value;
                       rw_flag_to_mem <= `WRITE_FLAG;
                       size_to_mem <= 2;
                       status <= STORE;
                    end
                    `SW: begin
                       addr_to_mem <= mem_addr;
                       data_to_mem <= store_value;
                       rw_flag_to_mem <= `WRITE_FLAG;
                       size_to_mem <= 4;
                       status <= STORE;
                    end
                endcase
            end
        end
    end
end

endmodule
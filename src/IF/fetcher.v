module fetcher (
  	input wire clk_in,
  	input wire rst_in,
  	input wire rdy_in,

	input wire global_full,

	// memctrl
	output reg [31:0] pc_send_to_mem,
	input wire [31:0] inst_from_mem,
	output reg en_signal_to_mem,
	output reg drop_flag_to_mem,
	input wire ok_flag_from_mem,

	// predictor
	output wire [31:0] query_pc_in_predictor,
	output wire [31:0] query_inst_in_predictor,
	input wire [31:0] predicted_imm,
	input wire predicted_jump_from_predictor,

	// decoder (belongs to dispatcher)
	output reg [31:0] inst_to_decoder,

	// dispatcher
	output reg [31:0] pc_send_to_dispatcher,
	output reg [31:0] rollback_pc_to_dispatcher,
	output reg ok_flag_to_dispatcher,
	output reg predicted_jump_to_dispatcher,

	// RoB
	input wire [31:0] target_pc_from_RoB,
	input wire rollback_flag_from_RoB
);

integer i;

localparam IDLE = 0, FETCH = 1;		// status

reg [31:0] pc, mem_pc;	// mem_pc cope with icache and memory
reg status;

// INDEX/TAG RANGE is based on memory (pc)
`define ICACHE_SIZE 256
`define INDEX_RANGE 9:2
`define TAG_RANGE 31:10

// a direct-map i-cache
reg valid [`ICACHE_SIZE - 1 : 0];
reg [`TAG_RANGE] tag_store [`ICACHE_SIZE - 1 : 0];
reg [31:0] data_store [`ICACHE_SIZE - 1 : 0];	// block behind the tag
// the block size = 2^5, a block store one instruction

// 判断 cache 是否 hit
wire hit = valid[pc[`INDEX_RANGE]] && (tag_store[pc[`INDEX_RANGE]] == pc[`TAG_RANGE]);
wire [31:0] get_inst = hit ? data_store[pc[`INDEX_RANGE]] : 0;

// branch predict must go ahead of fetch, so it should be a wire 
// work when signal changes
assign query_pc_in_predictor = pc;
assign query_inst_in_predictor = get_inst;

always @(posedge clk_in) begin
    if (rst_in) begin
        pc <= 0;
		mem_pc <= 0;
		status <= IDLE;

		en_signal_to_mem <= 0;
		pc_send_to_mem <= 0;
		drop_flag_to_mem <= 0;

		inst_to_decoder <= 0;

		pc_send_to_dispatcher <= 0;
		ok_flag_to_dispatcher <= 0;

		for (i = 0; i < `ICACHE_SIZE; i = i + 1) begin
			valid[i] <= 0;
			tag_store[i] <= 0;
			data_store[i] <= 0;
		end
    end
    else if (!rdy_in) begin
    end
    else begin
		if (rollback_flag_from_RoB) begin
			ok_flag_to_dispatcher <= 0;
			pc <= target_pc_from_RoB;
			mem_pc <= target_pc_from_RoB;
			status <= IDLE;
			en_signal_to_mem <= 0;
			drop_flag_to_mem <= 1;
		end 
		else begin 
			if (hit && !global_full) begin
				// update pc
				pc <= pc + (predicted_jump_from_predictor ? predicted_imm : 4); 
				
				// get inst from icache and send to decoder
				inst_to_decoder <= get_inst;
				
				// update dispatcher
				pc_send_to_dispatcher <= pc;
				predicted_jump_to_dispatcher <= predicted_jump_from_predictor; 
				rollback_pc_to_dispatcher <= pc + 4;	// no jump
				ok_flag_to_dispatcher <= 1;
			end 
			else ok_flag_to_dispatcher <= 0;

			drop_flag_to_mem <= 0;
			en_signal_to_mem <= 0;

			// ready to fetch 
			if (status == IDLE) begin
				en_signal_to_mem <= 1;
				pc_send_to_mem <= mem_pc;
				status <= FETCH;
			end 
			else if (ok_flag_from_mem) begin
				// icache store
				mem_pc <= (mem_pc == pc) ? mem_pc + 4 : pc;
				status <= IDLE;
				valid[mem_pc[`INDEX_RANGE]] <= 1;
				tag_store[mem_pc[`INDEX_RANGE]] <= mem_pc[`TAG_RANGE];
				data_store[mem_pc[`INDEX_RANGE]] <= inst_from_mem;
			end
		end
		// $display("%d", pc);
    end
end

endmodule
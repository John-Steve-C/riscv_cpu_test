// RISCV32I CPU top module
// port modification allowed for debugging purposes


// 采用 Makefile 进行编译, 不需要手动 include

// `include "/mnt/d/Coding/RISCV-CPU/riscv/src/IF/fetcher.v"
// `include "/mnt/d/Coding/RISCV-CPU/riscv/src/IF/predictor.v"
// `include "/mnt/d/Coding/RISCV-CPU/riscv/src/memCtrl.v"
// `include "/mnt/d/Coding/RISCV-CPU/riscv/src/RoB.v"
// `include "/mnt/d/Coding/RISCV-CPU/riscv/src/RegFile.v"
// `include "/mnt/d/Coding/RISCV-CPU/riscv/src/ID/dispatcher.v"
// `include "/mnt/d/Coding/RISCV-CPU/riscv/src/EXE/ALU.v"
// `include "/mnt/d/Coding/RISCV-CPU/riscv/src/EXE/RS.v"
// `include "/mnt/d/Coding/RISCV-CPU/riscv/src/EXE/LSU.v"
// `include "/mnt/d/Coding/RISCV-CPU/riscv/src/EXE/LSB.v"


module cpu(
    input  wire                 clk_in,			// system clock signal
    input  wire                 rst_in,			// reset signal
	input  wire					rdy_in,			// ready signal, pause cpu when low

    input  wire [ 7:0]          mem_din,		// data input bus
    output wire [ 7:0]          mem_dout,		// data output bus
    output wire [31:0]          mem_a,			// address bus (only 17:0 is used)
    output wire                 mem_wr,			// write/read signal (1 for write)
	
	input  wire                 io_buffer_full, // 1 if uart buffer is full
	
	output wire [31:0]			dbgreg_dout		// cpu register output (debugging demo)
);

// implementation goes here

// Specifications:
// - Pause cpu(freeze pc, registers, etc.) when rdy_in is low
// - Memory read result will be returned in the next cycle. Write takes 1 cycle(no need to wait)
// - Memory is of size 128KB, with valid address ranging from 0x0 to 0x20000
// - I/O port is mapped to address higher than 0x30000 (mem_a[17:16]==2'b11)
// - 0x30000 read: read a byte from input
// - 0x30000 write: write a byte to output (write 0x00 is ignored)
// - 0x30004 read: read clocks passed since cpu starts (in dword, 4 bytes)
// - 0x30004 write: indicates program stop (will output '\0' through uart tx)


//---------------------------------------------------------------------fetcher

// wire connect memCtrl
wire [31:0] pc_between_fetcher_mem;
wire [31:0] inst_between_fetcher_mem;
wire en_signal_between_fetcher_mem, ok_flag_between_fetcher_mem, drop_flag_between_fetcher_mem;

// connect predictor
wire [31:0] query_pc_between_fetcher_predictor;
wire [31:0] query_inst_between_fetcher_predictor;
wire predicted_jump_between_fetcher_predictor;
wire [31:0] predicted_imm_between_fetcher_predictor;

// connect dispatcher
wire ok_flag_between_fetcher_dispatcher;
wire [31:0] inst_between_fetcher_dispatcher;
wire [31:0] pc_between_fetcher_dispatcher;
wire [31:0] rollback_pc_between_fetcher_dispatcher;
wire predicted_jump_between_fetcher_dispatcher;

// connect rob
wire [31:0] target_pc_between_fetcher_rob;

// other wires to fetcher
wire full_from_rs, full_from_lsb, full_from_rob;
wire global_full = (full_from_rs || full_from_lsb || full_from_rob) ? 1 : 0;

//---------------------------------------------------------------------dispatcher

// connect rs
wire en_signal_between_dispatcher_rs;
wire [5:0] inst_name_between_dispatcher_rs;
wire [31:0] pc_between_dispatcher_rs;
wire [31:0] imm_between_dispatcher_rs;
wire [31:0] V1_between_dispatcher_rs;
wire [31:0] V2_between_dispatcher_rs;
wire [4:0] Q1_between_dispatcher_rs;
wire [4:0] Q2_between_dispatcher_rs;
wire [4:0] rob_id_between_dispatcher_rs;

// connect lsb
wire en_signal_between_dispatcher_lsb;
wire [5:0] inst_name_between_dispatcher_lsb;
wire [31:0] imm_between_dispatcher_lsb;
wire [31:0] V1_between_dispatcher_lsb;
wire [31:0] V2_between_dispatcher_lsb;
wire [4:0] Q1_between_dispatcher_lsb;
wire [4:0] Q2_between_dispatcher_lsb;
wire [4:0] rob_id_between_dispatcher_lsb;

// connect rob
wire en_signal_between_dispatcher_rob;
wire [4:0] rd_between_dispatcher_rob;
wire is_jump_between_dispatcher_rob;
wire is_store_between_dispatcher_rob;
wire predicted_jump_between_dispatcher_rob;
wire [31:0] pc_between_dispatcher_rob;
wire [31:0] rollback_pc_between_dispatcher_rob;

wire [4:0] rob_id_between_dispatcher_rob;
wire [4:0] Q1_between_dispatcher_rob;
wire [4:0] Q2_between_dispatcher_rob;
wire Q1_ready_between_dispatcher_rob;
wire Q2_ready_between_dispatcher_rob;
wire [31:0] data1_between_dispatcher_rob;
wire [31:0] data2_between_dispatcher_rob;

// connect reg
wire en_signal_between_dispatcher_reg;
wire [4:0] rs1_between_dispatcher_reg;
wire [4:0] rs2_between_dispatcher_reg;
wire [31:0] V1_between_dispatcher_reg;
wire [31:0] V2_between_dispatcher_reg;
wire [4:0] Q1_between_dispatcher_reg;
wire [4:0] Q2_between_dispatcher_reg;
wire [4:0] rd_between_dispatcher_reg;
wire [4:0] Q_between_dispatcher_reg;

//---------------------------------------------------------------------rob

// commit
wire commit_flag_bus;
wire rollback_flag_bus;

// connect reg
wire [4:0] rd_between_rob_reg;
wire [4:0] Q_between_rob_reg;
wire [31:0] V_between_rob_reg;

// connect lsb
wire [4:0] rob_id_between_rob_lsb;
wire [4:0] io_rob_id_between_rob_lsb;
wire [4:0] head_io_rob_id_between_rob_lsb;

// connect predictor
wire en_signal_between_rob_predictor;
wire hit_between_rob_predictor;
wire [31:0] pc_between_rob_predictor;

//---------------------------------------------------------------------rs

// connect alu
wire [5:0] inst_name_between_rs_alu;
wire [31:0] pc_between_rs_alu;
wire [31:0] V1_between_rs_alu;
wire [31:0] V2_between_rs_alu;
wire [31:0] imm_between_rs_alu;

//---------------------------------------------------------------------alu

// can output to many units
wire valid_alu;
wire jump_flag_alu;
wire [4:0] rob_id_alu;
wire [31:0] result_alu;
wire [31:0] target_pc_alu;

//---------------------------------------------------------------------lsb

//connect lsu
wire en_signal_between_lsb_lsu;
wire busy_between_lsb_lsu;
wire [5:0] inst_name_between_lsb_lsu;
wire [31:0] mem_addr_between_lsb_lsu;
wire [31:0] store_value_between_lsb_lsu;


//---------------------------------------------------------------------lsu

// can output to many units like alu
wire valid_lsu;
wire [4:0] rob_id_lsu;
wire [31:0] result_lsu;

// connect memCtrl
wire en_signal_between_lsu_mem;
wire [31:0] addr_between_lsu_mem;
wire [31:0] data_from_ex_to_mem;
wire rw_flag_between_lsu_mem;
wire ok_flag_between_lsu_mem;
wire [31:0] data_from_mem_to_ex;
wire [2:0] size_between_lsu_mem;

//---------------------------------------------------------------------


// connect units with wires

memCtrl memCtrl_entity (
    .clk_in(clk_in),
    .rst_in(rst_in),
    .rdy_in(rdy_in),

    // cope with ram
    .uart_full_from_ram(io_buffer_full),  // check if io_buffer is full
    .data_from_ram(mem_din), // input
    .data_to_ram(mem_dout),   // output
    .rw_flag_to_ram(mem_wr),
    .addr_to_ram(mem_a),

    // fetcher
    .pc_from_fetcher(pc_between_fetcher_mem),
    .en_signal_from_fetcher(en_signal_between_fetcher_mem),   //chip enable signal
    .drop_flag_from_fetcher(drop_flag_between_fetcher_mem),
    .ok_flag_to_fetcher(ok_flag_between_fetcher_mem),
    .inst_to_fetcher(inst_between_fetcher_mem),

    // lsu
    .addr_from_lsu(addr_between_lsu_mem),
    .write_data_from_lsu(data_from_ex_to_mem),
    .en_signal_from_lsu(en_signal_between_lsu_mem),
    .rw_flag_from_lsu(rw_flag_between_lsu_mem),
    .size_from_lsu(size_between_lsu_mem),
    .ok_flag_to_lsu(ok_flag_between_lsu_mem),
    .load_data_to_lsu(data_from_mem_to_ex)
);

RegFile regFile_entity (
    .clk_in(clk_in),
  	.rst_in(rst_in),
  	.rdy_in(rdy_in),

	// call-back
    // dispatcher
	.en_signal_from_dispatcher(en_signal_between_dispatcher_reg),
    .rd_from_dispatcher(rd_between_dispatcher_reg),
    .Q_from_dispatcher(Q_between_dispatcher_reg),

    .rs1_from_dispatcher(rs1_between_dispatcher_reg),
    .rs2_from_dispatcher(rs2_between_dispatcher_reg),
    .V1_to_dispatcher(V1_between_dispatcher_reg),
    .V2_to_dispatcher(V2_between_dispatcher_reg),
    .Q1_to_dispatcher(Q1_between_dispatcher_reg),
    .Q2_to_dispatcher(Q2_between_dispatcher_reg),

    // commit from rob
    .commit_flag_from_rob(commit_flag_bus),
    .rollback_flag_from_rob(rollback_flag_bus),
    .rd_from_rob(rd_between_rob_reg),
    .Q_from_rob(Q_between_rob_reg),
    .V_from_rob(V_between_rob_reg)
);

fetcher fetcher_entity (
    .clk_in(clk_in),
    .rst_in(rst_in),
    .rdy_in(rdy_in),

	.global_full(global_full),

	// memctrl
	.pc_send_to_mem(pc_between_fetcher_mem),
	.inst_from_mem(inst_between_fetcher_mem),
	.en_signal_to_mem(en_signal_between_fetcher_mem),
	.drop_flag_to_mem(drop_flag_between_fetcher_mem),
	.ok_flag_from_mem(ok_flag_between_fetcher_mem),

	// predictor
	.query_pc_in_predictor(query_pc_between_fetcher_predictor),
	.query_inst_in_predictor(query_inst_between_fetcher_predictor),
	.predicted_imm(predicted_imm_between_fetcher_predictor),
	.predicted_jump_from_predictor(predicted_jump_between_fetcher_predictor),

	// decoder (belongs to dispatcher)
	.inst_to_decoder(inst_between_fetcher_dispatcher),

	// dispatcher
	.pc_send_to_dispatcher(pc_between_fetcher_dispatcher),
	.rollback_pc_to_dispatcher(rollback_pc_between_fetcher_dispatcher),
	.ok_flag_to_dispatcher(ok_flag_between_fetcher_dispatcher),
	.predicted_jump_to_dispatcher(predicted_jump_between_fetcher_dispatcher),

	// RoB
	.target_pc_from_RoB(target_pc_between_fetcher_rob),
	.rollback_flag_from_RoB(rollback_flag_bus)
);

predictor predictor_entity(
    .clk_in(clk_in),
  	.rst_in(rst_in),
  	.rdy_in(rdy_in),

    // query
    .query_pc(query_pc_between_fetcher_predictor),
    .query_inst(query_inst_between_fetcher_predictor),

    // output to fetcher
    .predict_imm(predicted_imm_between_fetcher_predictor),
    .jump(predicted_jump_between_fetcher_predictor),

    // update from rob
    .pc_from_rob(pc_between_rob_predictor),
    .en_signal_from_rob(en_signal_between_rob_predictor),
    .hit_from_rob(hit_between_rob_predictor)
);

dispatcher dispatcher_entity (
    .clk_in(clk_in),
    .rst_in(rst_in),
    .rdy_in(rdy_in),

    // fetcher
    .pc_from_fetcher(pc_between_fetcher_dispatcher),
	.rollback_pc_from_fetcher(rollback_pc_between_fetcher_dispatcher),
    .inst_from_fetcher(inst_between_fetcher_dispatcher),
	.ok_flag_from_fetcher(ok_flag_between_fetcher_dispatcher),
	.predicted_jump_from_fetcher(predicted_jump_between_fetcher_dispatcher),

    // RoB
    .en_signal_to_rob(en_signal_between_dispatcher_rob),
    .rd_to_rob(rd_between_dispatcher_rob),
    .is_jump_to_rob(is_jump_between_dispatcher_rob),
    .is_store_to_rob(is_store_between_dispatcher_rob),
    .predicted_jump_to_rob(predicted_jump_between_dispatcher_rob),
    .pc_to_rob(pc_between_dispatcher_rob),

    .rob_id_from_rob(rob_id_between_dispatcher_rob),
    .rollback_pc_to_rob(rollback_pc_between_dispatcher_rob),

    // query V(data) from RoB to speed up
    .Q1_to_rob(Q1_between_dispatcher_rob),
    .Q2_to_rob(Q2_between_dispatcher_rob),
    .Q1_ready_from_rob(Q1_ready_between_dispatcher_rob),
    .Q2_ready_from_rob(Q2_ready_between_dispatcher_rob),
    .data1_from_rob(data1_between_dispatcher_rob),
    .data2_from_rob(data2_between_dispatcher_rob),
    .rollback_flag_from_rob(rollback_flag_bus),

    // RegFile
    .en_signal_to_reg(en_signal_between_dispatcher_reg),
    .rd_to_reg(rd_between_dispatcher_reg),
    .Q_to_reg(Q_between_dispatcher_reg),

    .rs1_to_reg(rs1_between_dispatcher_reg),
    .rs2_to_reg(rs2_between_dispatcher_reg),
    .Q1_from_reg(Q1_between_dispatcher_reg),
    .Q2_from_reg(Q2_between_dispatcher_reg),
    .V1_from_reg(V1_between_dispatcher_reg),
    .V2_from_reg(V2_between_dispatcher_reg),

    // RS
    .en_signal_to_rs(en_signal_between_dispatcher_rs),
    .inst_name_to_rs(inst_name_between_dispatcher_rs),
    .Q1_to_rs(Q1_between_dispatcher_rs),
    .Q2_to_rs(Q2_between_dispatcher_rs),
    .V1_to_rs(V1_between_dispatcher_rs),
    .V2_to_rs(V2_between_dispatcher_rs),
    .imm_to_rs(imm_between_dispatcher_rs),
    .pc_to_rs(pc_between_dispatcher_rs),
    .rob_id_to_rs(rob_id_between_dispatcher_rs),

    // LSB
    .en_signal_to_lsb(en_signal_between_dispatcher_lsb),
    .inst_name_to_lsb(inst_name_between_dispatcher_lsb),
    .Q1_to_lsb(Q1_between_dispatcher_lsb),
    .Q2_to_lsb(Q2_between_dispatcher_lsb),
    .V1_to_lsb(V1_between_dispatcher_lsb),
    .V2_to_lsb(V2_between_dispatcher_lsb),
    .imm_to_lsb(imm_between_dispatcher_lsb),
    .rob_id_to_lsb(rob_id_between_dispatcher_lsb),

    // ALU
    .valid_from_alu(valid_alu),
    .result_from_alu(result_alu),
    .rob_id_from_alu(rob_id_alu),

    // LSU
    .valid_from_lsu(valid_lsu),
    .result_from_lsu(result_lsu),
    .rob_id_from_lsu(rob_id_lsu)
);

RS rs_entity (
    .clk_in(clk_in),
    .rst_in(rst_in),
    .rdy_in(rdy_in),

    // dispatcher
    .en_signal_from_dispatcher(en_signal_between_dispatcher_rs),
    .inst_name_from_dispatcher(inst_name_between_dispatcher_rs),
    .Q1_from_dispatcher(Q1_between_dispatcher_rs),
    .Q2_from_dispatcher(Q2_between_dispatcher_rs),
    .V1_from_dispatcher(V1_between_dispatcher_rs),
    .V2_from_dispatcher(V2_between_dispatcher_rs),
    .pc_from_dispatcher(pc_between_dispatcher_rs),
    .imm_from_dispatcher(imm_between_dispatcher_rs),
    .rob_id_from_dispatcher(rob_id_between_dispatcher_rs),

    // alu
    .inst_name_to_alu(inst_name_between_rs_alu),
    .V1_to_alu(V1_between_rs_alu),
    .V2_to_alu(V2_between_rs_alu),
    .pc_to_alu(pc_between_rs_alu),
    .imm_to_alu(imm_between_rs_alu),

    .rob_id_to_exe(rob_id_alu),

    .valid_from_alu(valid_alu),
    .result_from_alu(result_alu),
    .rob_id_from_alu(rob_id_alu),

    // lsu
    .valid_from_lsu(valid_lsu),
    .result_from_lsu(result_lsu),
    .rob_id_from_lsu(rob_id_lsu),

    // fetcher
    .full_to_fetcher(full_from_rs),

    .rollback_flag_from_rob(rollback_flag_bus)
);

ALU alu_entity (
    // from rs
    .inst_name(inst_name_between_rs_alu),
    .V1(V1_between_rs_alu),
    .V2(V2_between_rs_alu),
    .imm(imm_between_rs_alu),
    .pc(pc_between_rs_alu),

    // to rs
    .result(result_alu),
    .target_pc(target_pc_alu),
    .jump(jump_flag_alu),
    .valid(valid_alu)
);

LSB lsb_entity (
    .clk_in(clk_in),
    .rst_in(rst_in),
    .rdy_in(rdy_in),

    // dispatcher
    .en_signal_from_dispatcher(en_signal_between_dispatcher_lsb),
    .inst_name_from_dispatcher(inst_name_between_dispatcher_lsb),
    .Q1_from_dispatcher(Q1_between_dispatcher_lsb),
    .Q2_from_dispatcher(Q2_between_dispatcher_lsb),
    .V1_from_dispatcher(V1_between_dispatcher_lsb),
    .V2_from_dispatcher(V2_between_dispatcher_lsb),
    .imm_from_dispatcher(imm_between_dispatcher_lsb),
    .rob_id_from_dispatcher(rob_id_between_dispatcher_lsb),

    // lsu
    .en_signal_to_lsu(en_signal_between_lsb_lsu),
    .inst_name_to_lsu(inst_name_between_lsb_lsu),
    .store_value_to_lsu(store_value_between_lsb_lsu),
    .mem_addr_to_lsu(mem_addr_between_lsb_lsu),

    .rob_id_to_exe(rob_id_lsu),

    // alu
    .valid_from_alu(valid_alu),
    .result_from_alu(result_alu),
    .rob_id_from_alu(rob_id_alu),

    // get from lsu
    .busy_from_lsu(busy_between_lsb_lsu),
    .valid_from_lsu(valid_lsu),
    .result_from_lsu(result_lsu),
    .rob_id_from_lsu(rob_id_lsu),

    // rob
    .commit_flag_from_rob(commit_flag_bus),
    .rob_id_from_rob(rob_id_between_rob_lsb),
    .head_io_rob_id_from_rob(head_io_rob_id_between_rob_lsb),

    .io_rob_id_to_rob(io_rob_id_between_rob_lsb),

    // fetcher
    .full_to_fetcher(full_from_lsb),

    .rollback_flag_from_rob(rollback_flag_bus)
);

LSU lsu_entity (
    .clk_in(clk_in),
    .rst_in(rst_in),
    .rdy_in(rdy_in),

    .enable_signal(en_signal_between_lsb_lsu),
    .inst_name(inst_name_between_lsb_lsu),
    .mem_addr(mem_addr_between_lsb_lsu),
    .store_value(store_value_between_lsb_lsu),
    
    .valid(valid_lsu),
    .result(result_lsu),

    // mem_store
    .en_signal_to_mem(en_signal_between_lsu_mem),
    .addr_to_mem(addr_between_lsu_mem),
    .data_to_mem(data_from_ex_to_mem),
    .rw_flag_to_mem(rw_flag_between_lsu_mem),
    .size_to_mem(size_between_lsu_mem),
    // mem_load
    .ok_flag_from_mem(ok_flag_between_lsu_mem),
    .data_from_mem(data_from_mem_to_ex),

    // LSB
    .busy_to_lsb(busy_between_lsb_lsu),

    // rob
    .rollback_flag_from_rob(rollback_flag_bus)
);

RoB rob_entity (
    .clk_in(clk_in),
    .rst_in(rst_in),
    .rdy_in(rdy_in),

    // dispatcher
    .Q1_from_dispatcher(Q1_between_dispatcher_rob),
    .Q2_from_dispatcher(Q2_between_dispatcher_rob),
    .Q1_ready_to_dispatcher(Q1_ready_between_dispatcher_rob),
    .Q2_ready_to_dispatcher(Q2_ready_between_dispatcher_rob),
    .data1_to_dispatcher(data1_between_dispatcher_rob),
    .data2_to_dispatcher(data2_between_dispatcher_rob),

    .rob_id_to_dispatcher(rob_id_between_dispatcher_rob),

    .en_signal_from_dispatcher(en_signal_between_dispatcher_rob),
    .jump_from_dispatcher(is_jump_between_dispatcher_rob),
    .is_store_from_dispatcher(is_store_between_dispatcher_rob),
    .rd_from_dispatcher(rd_between_dispatcher_rob),
    .predicted_jump_from_dispatcher(predicted_jump_between_dispatcher_rob),
    .pc_from_dispatcher(pc_between_dispatcher_rob),
    .rollback_pc_from_dispatcher(rollback_pc_between_dispatcher_rob),

    .commit_flag(commit_flag_bus), 

    // fetcher
    .rollback_flag(rollback_flag_bus),
    .target_pc_to_fetcher(target_pc_between_fetcher_rob),
    .full_to_fetcher(full_from_rob),

    // predictor
    .en_signal_to_predictor(en_signal_between_rob_predictor),
    .hit_to_predictor(hit_between_rob_predictor),
    .pc_to_predictor(pc_between_rob_predictor),

    // alu
    .valid_from_alu(valid_alu),
    .jump_flag_from_alu(jump_flag_alu),
    .rob_id_from_alu(rob_id_alu),
    .result_from_alu(result_alu),
    .target_pc_from_alu(target_pc_alu),

    // lsu
    .valid_from_lsu(valid_lsu),
    .rob_id_from_lsu(rob_id_lsu),
    .result_from_lsu(result_lsu),

    // lsb
    .io_rob_id_from_lsb(io_rob_id_between_rob_lsb),
    .rob_id_to_lsb(rob_id_between_rob_lsb),
    .head_io_rob_id_to_lsb(head_io_rob_id_between_rob_lsb),

    // regFile
    .rd_to_reg(rd_between_rob_reg),
    .Q_to_reg(Q_between_rob_reg),
    .V_to_reg(V_between_rob_reg)
);


endmodule
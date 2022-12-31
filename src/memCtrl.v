// `include "/mnt/d/Coding/RISCV-CPU/riscv/src/defines.v"
`include "defines.v"

// `include "D:/Coding/RISCV-CPU/riscv/src/defines.v"

// memory controller
module memCtrl (
    input wire clk_in,
    input wire rst_in,
    input wire rdy_in,

    // ram
    input wire uart_full_from_ram,  // full signal
    input wire [7:0] data_from_ram, // input
    output reg [7:0] data_to_ram,   // output
    output reg rw_flag_to_ram,
    output reg [31:0] addr_to_ram,

    // fetcher
    input wire [31:0] pc_from_fetcher,
    input wire en_signal_from_fetcher,          // enable signal
    input wire drop_flag_from_fetcher,          // rollback signal, no need to fetch inst
    output reg ok_flag_to_fetcher,              //
    output reg [31:0] inst_to_fetcher,

    // lsu
    input wire [31:0] addr_from_lsu,
    input wire [31:0] write_data_from_lsu,
    input wire en_signal_from_lsu,
    input wire rw_flag_from_lsu,
    input wire [2:0] size_from_lsu,             // get data size = k byte
    output reg ok_flag_to_lsu,
    output reg [31:0] load_data_to_lsu
);

// mem status
localparam IDLE = 0, FETCH = 1, LOAD = 2, STORE = 3;
reg [2:0] status;
reg [31:0] ram_access_counter, ram_access_stop; // ram_access_counter = 0 ~ stop (byte size)
reg [31:0] ram_access_pc, writing_data;

// read/write buffer
// If receive a request while mem is working, the request will be put into buffer
reg [31:0] buffer_pc;
reg buffer_fetch_valid, buffer_ls_valid, buffer_rw_flag;  
reg [2:0] buffer_query_size;
reg [31:0] buffer_addr, buffer_write_data;

// prevent write data to hci when I/O buffer is full
reg uart_write_is_io, uart_write_lock;

// cope with drop situation
// change status when get drop_flag_from_fetcher
reg status_drop_flag, fetch_valid_drop_flag, ls_valid_drop_flag;
wire [2:0] real_status = status_drop_flag ? IDLE : status;
wire real_buffer_fetch_valid = fetch_valid_drop_flag ? 0 : buffer_fetch_valid;
wire real_buffer_ls_valid = ls_valid_drop_flag ? 0 : buffer_ls_valid;

always @(*) begin
    status_drop_flag = 0;
    fetch_valid_drop_flag = 0;
    ls_valid_drop_flag = 0;

    if (drop_flag_from_fetcher) begin
        if (status == FETCH || status == LOAD) status_drop_flag = 1;
        fetch_valid_drop_flag = 1;
        if (buffer_ls_valid && buffer_rw_flag == `READ_FLAG) ls_valid_drop_flag = 1;
    end
end


always @(posedge clk_in) begin
    if (rst_in) begin
        status <= IDLE;
        ram_access_counter <= 0;
        ram_access_stop <= 0;
        ram_access_pc <= 0;
        buffer_fetch_valid <= 0;
        buffer_ls_valid <= 0;
        inst_to_fetcher <= 0;
        load_data_to_lsu <= 0;
        // addr_to_ram <= 0;
        
        uart_write_is_io <= 0;
        uart_write_lock <= 0;
    end
    else if (!rdy_in) begin
        // ok_flag_to_fetcher <= 0;
        // ok_flag_to_lsu <= 0;
    end
    else begin
        // cope with drop situation
        // if (drop_flag_from_fetcher) begin
        //     // fetch failed, update the status
        //     if (status == FETCH || status == LOAD) status <= IDLE;
        //     buffer_fetch_valid <= 0;
        //     if (buffer_ls_valid && buffer_rw_flag == `READ_FLAG) buffer_ls_valid <= 0;
        // end
        if (status_drop_flag) status <= IDLE;
        if (fetch_valid_drop_flag) buffer_fetch_valid <= 0;
        if (ls_valid_drop_flag) buffer_ls_valid <= 0;

        // ok_flag_to_fetcher <= 0;
        // ok_flag_to_lsu <= 0;
        // addr_to_ram <= 0;
        // rw_flag_to_ram <= `READ_FLAG;    // set default value

        // busy mem, put query into r/w buffer
        if (real_status != IDLE || (en_signal_from_fetcher && en_signal_from_lsu)) begin
            // load/store instruction
            if (!en_signal_from_fetcher && en_signal_from_lsu) begin
                buffer_ls_valid <= 1;
                buffer_rw_flag <= rw_flag_from_lsu;
                buffer_addr <= addr_from_lsu;
                buffer_write_data <= write_data_from_lsu;
                buffer_query_size <= size_from_lsu;
            end
            // instruction fetch
            else if (en_signal_from_fetcher) begin
                buffer_fetch_valid <= 1;
                buffer_pc <= pc_from_fetcher;
            end
        end

        // IDLE mem, then update the status
        if (real_status == IDLE) begin
            ok_flag_to_fetcher <= 0;
            ok_flag_to_lsu <= 0;
            inst_to_fetcher <= 0;
            load_data_to_lsu <= 0;

            // cope with lsu inst
            if (en_signal_from_lsu) begin
                if (rw_flag_from_lsu == `WRITE_FLAG) begin
                    ram_access_counter <= 0;
                    ram_access_stop <= size_from_lsu;
                    writing_data <= write_data_from_lsu;
                    addr_to_ram <= 0;       // 0 to prevent writing ahead
                    ram_access_pc <= addr_from_lsu;
                    rw_flag_to_ram <= `WRITE_FLAG;

                    uart_write_is_io <= (addr_from_lsu == `RAM_IO_PORT);
                    uart_write_lock <= 0;

                    status <= STORE;
                end
                else if (rw_flag_from_lsu == `READ_FLAG) begin
                    ram_access_counter <= 0;
                    ram_access_stop <= size_from_lsu;
                    addr_to_ram <= addr_from_lsu;
                    ram_access_pc <= addr_from_lsu + 1; // prevent miss
                    rw_flag_to_ram <= `READ_FLAG;

                    status <= LOAD;
                end
            end
            else if (real_buffer_ls_valid) begin     // there are buffered requests
                if (buffer_rw_flag == `WRITE_FLAG) begin
                    ram_access_counter <= 0;
                    ram_access_stop <= buffer_query_size;
                    writing_data <= buffer_write_data;
                    addr_to_ram <= 0;
                    ram_access_pc <= buffer_addr;
                    rw_flag_to_ram <= `WRITE_FLAG;
                    status <= STORE;                
                end
                else if (buffer_rw_flag == `READ_FLAG) begin
                    ram_access_counter <= 0;
                    ram_access_stop <= buffer_query_size;
                    addr_to_ram <= buffer_addr;
                    ram_access_pc <= buffer_addr + 1; //
                    rw_flag_to_ram <= `READ_FLAG;
                    status <= LOAD;
                end
                buffer_ls_valid <= 0;
            end
            // cope with fetcher
            else if (en_signal_from_fetcher) begin
                ram_access_counter <= 0;
                ram_access_stop <= 4;   // fetch a 4-byte inst [31:0]
                addr_to_ram <= pc_from_fetcher;
                ram_access_pc <= pc_from_fetcher + 1;
                rw_flag_to_ram <= `READ_FLAG;
                status <= FETCH;
            end
            else if (real_buffer_fetch_valid) begin
                ram_access_counter <= 0;
                ram_access_stop <= 4;
                addr_to_ram <= buffer_pc;
                ram_access_pc <= buffer_pc + 1;
                rw_flag_to_ram <= `READ_FLAG;
                status <= FETCH;
                buffer_fetch_valid <= 0;
            end
        end

        // busy, check the illegal status, and then work
        else if (!(uart_full_from_ram && real_status == STORE)) begin
            // work fetch
            if (real_status == FETCH) begin
                addr_to_ram <= ram_access_pc;
                rw_flag_to_ram <= `READ_FLAG;
                case (ram_access_counter)
                    1: inst_to_fetcher[7:0] <= data_from_ram;      // 保证 inst_to_fetcher 落后 data_from_ram 一个 cycle
                    2: inst_to_fetcher[15:8] <= data_from_ram;
                    3: inst_to_fetcher[23:16] <= data_from_ram;
                    4: inst_to_fetcher[31:24] <= data_from_ram;
                endcase
                ram_access_pc <= (ram_access_counter >= ram_access_stop - 1) ? 0 : ram_access_pc + 1;    // get new pc
                if (ram_access_counter == ram_access_stop) begin
                    // completed and stop
                    ok_flag_to_fetcher <= !drop_flag_from_fetcher;
                    status <= IDLE;
                    ram_access_pc <= 0;
                    ram_access_counter <= 0;
                end
                else begin
                    ram_access_counter <= ram_access_counter + 1;
                end
            end

            // load
            else if (real_status == LOAD) begin
                addr_to_ram <= ram_access_pc;
                rw_flag_to_ram <= `READ_FLAG;
                case (ram_access_counter)
                    1: load_data_to_lsu[7:0] <= data_from_ram;  // 同理 保证落后
                    2: load_data_to_lsu[15:8] <= data_from_ram;
                    3: load_data_to_lsu[23:16] <= data_from_ram;
                    4: load_data_to_lsu[31:24] <= data_from_ram;
                endcase
                ram_access_pc <= (ram_access_counter >= ram_access_stop - 1) ? 0 : ram_access_pc + 1;
                if (ram_access_counter == ram_access_stop) begin
                    ok_flag_to_lsu <= !drop_flag_from_fetcher;
                    status <= IDLE;
                    ram_access_pc <= 0;
                    ram_access_counter <= 0;
                end
                else begin
                    ram_access_counter <= ram_access_counter + 1;
                end
            end
            
            // store
            else if (real_status == STORE) begin
                if (!uart_write_is_io || !uart_write_lock) begin
                    // uart is full, lock 1 cycle
                    uart_write_lock <= 1;
                    
                    addr_to_ram <= ram_access_pc;
                    rw_flag_to_ram <= `WRITE_FLAG;
                    case (ram_access_counter) 
                        0: data_to_ram <= writing_data[7:0];    // 写入时不需要落后以读取数据
                        1: data_to_ram <= writing_data[15:8];
                        2: data_to_ram <= writing_data[23:16];
                        3: data_to_ram <= writing_data[31:24];
                    endcase
                    ram_access_pc <= (ram_access_counter >= ram_access_stop - 1) ? 0 : ram_access_pc + 1;
                    if (ram_access_counter == ram_access_stop) begin
                        ok_flag_to_lsu <= 1;
                        status <= IDLE;
                        ram_access_pc <= 0;
                        ram_access_counter <= 0;
                        addr_to_ram <= 0;
                        rw_flag_to_ram <= `READ_FLAG;
                    end
                    else begin
                        ram_access_counter <= ram_access_counter + 1;
                    end
                end
                else begin
                    // unlock uart
                    uart_write_lock <= 0;
                end
            end
        end        
    end
end

endmodule
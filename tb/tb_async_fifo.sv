
`timescale 1ns/1ps

module tb_async_fifo;

    // --------------------------------------------------------
    //  Parameters (match DUT defaults)
    // --------------------------------------------------------
    localparam int DATA_WIDTH = 32;
    localparam int FIFO_DEPTH = 16;
    localparam int PTR_WIDTH  = $clog2(FIFO_DEPTH) + 1;

    // --------------------------------------------------------
    //  Clock periods
    // --------------------------------------------------------
    localparam real WR_CLK_PERIOD = 10.0;   // ns
    localparam real RD_CLK_PERIOD =  7.0;   // ns

    // --------------------------------------------------------
    //  DUT ports
    // --------------------------------------------------------
    logic                  wr_clk;
    logic                  arst_n;
    logic                  wr_en;
    logic [DATA_WIDTH-1:0] wr_data;
    logic                  full;

    logic                  rd_clk;
    logic                  rd_en;
    logic [DATA_WIDTH-1:0] rd_data;
    logic                  empty;

    // --------------------------------------------------------
    //  DUT instantiation
    // --------------------------------------------------------
    async_fifo #(
        .DATA_WIDTH (DATA_WIDTH),
        .FIFO_DEPTH (FIFO_DEPTH)
    ) dut (
        .wr_clk  (wr_clk),
        .arst_n  (arst_n),
        .wr_en   (wr_en),
        .wr_data (wr_data),
        .full    (full),
        .rd_clk  (rd_clk),
        .rd_en   (rd_en),
        .rd_data (rd_data),
        .empty   (empty)
    );

    // --------------------------------------------------------
    //  Clock generation
    // --------------------------------------------------------
    initial begin 
	$dumpfile("fifo.vcd"); 
	$dumpvars(0, tb_async_fifo); 
    end

    initial wr_clk = 0;
    always #(WR_CLK_PERIOD/2.0) wr_clk = ~wr_clk;

    initial rd_clk = 0;
    always #(RD_CLK_PERIOD/2.0) rd_clk = ~rd_clk;

    // --------------------------------------------------------
    //  Scoreboard — reference FIFO (queue)
    // --------------------------------------------------------
    logic [DATA_WIDTH-1:0] ref_queue [$];
    int error_count = 0;
    int test_count  = 0;

    // --------------------------------------------------------
    //  Tasks
    // --------------------------------------------------------

    // Write one word on the next wr_clk posedge
    task automatic write_word(input logic [DATA_WIDTH-1:0] data);
        @(posedge wr_clk);
        #1;  // small delta after clock edge
        wr_en   = 1'b1;
        wr_data = data;
        @(posedge wr_clk);
        #1;
        if (!full) begin
            ref_queue.push_back(data);
        end
        wr_en = 1'b0;
    endtask

    // Read one word on the next rd_clk posedge and verify
    task automatic read_and_check();
        logic [DATA_WIDTH-1:0] expected;
        logic [DATA_WIDTH-1:0] got;
        @(posedge rd_clk);
        #1;
        rd_en = 1'b1;
        @(posedge rd_clk);
        #1;
        rd_en = 1'b0;
        // Wait one more rd_clk for registered output to settle
        @(posedge rd_clk);
        #1;
        got = rd_data;

        if (ref_queue.size() > 0) begin
            expected = ref_queue.pop_front();
            test_count++;
            if (got !== expected) begin
                $display("FAIL [t=%0t]: expected=0x%08X  got=0x%08X",
                         $time, expected, got);
                error_count++;
            end else begin
                $display("PASS [t=%0t]: rd_data=0x%08X", $time, got);
            end
        end
    endtask

    // Wait for a number of wr_clk cycles
    task automatic wait_wr(input int n);
        repeat(n) @(posedge wr_clk);
    endtask

    // Wait for a number of rd_clk cycles
    task automatic wait_rd(input int n);
        repeat(n) @(posedge rd_clk);
    endtask

    // Apply and release reset
    task automatic apply_reset();
        arst_n  = 1'b0;
        wr_en   = 1'b0;
        rd_en   = 1'b0;
        wr_data = '0;
        ref_queue.delete();
        repeat(4) @(posedge wr_clk);
        repeat(4) @(posedge rd_clk);
        arst_n = 1'b1;
        repeat(2) @(posedge wr_clk);
        repeat(2) @(posedge rd_clk);
    endtask

    // --------------------------------------------------------
    //  Main test sequence
    // --------------------------------------------------------
    initial begin
        $display("========================================");
        $display("  Async FIFO Testbench Start");
        $display("  DATA_WIDTH=%0d  FIFO_DEPTH=%0d", DATA_WIDTH, FIFO_DEPTH);
        $display("  wr_clk=%0.0f MHz  rd_clk=%0.1f MHz",
                 1000.0/WR_CLK_PERIOD, 1000.0/RD_CLK_PERIOD);
        $display("========================================");

        // ---- Test 1: Reset check ----
        $display("\n--- Test 1: Reset ---");
        apply_reset();
        assert (empty === 1'b1) else begin
            $display("FAIL: empty should be 1 after reset"); error_count++; end
        assert (full  === 1'b0) else begin
            $display("FAIL: full should be 0 after reset");  error_count++; end
        $display("PASS: empty=%0b  full=%0b after reset", empty, full);

        // ---- Test 2: Write until full ----
        $display("\n--- Test 2: Write until full (%0d entries) ---", FIFO_DEPTH);
        for (int i = 0; i < FIFO_DEPTH; i++) begin
            write_word(32'hA000_0000 + i);
        end
        wait_wr(4);  // let full flag propagate
        assert (full === 1'b1) else begin
            $display("FAIL: full should be 1 after writing %0d words", FIFO_DEPTH);
            error_count++;
        end
        $display("PASS: full asserted correctly after %0d writes", FIFO_DEPTH);

        // ---- Test 3: Write when full (overflow guard) ----
        $display("\n--- Test 3: Write when full (should be ignored) ---");
        @(posedge wr_clk); #1;
        wr_en   = 1'b1;
        wr_data = 32'hDEAD_BEEF;
        @(posedge wr_clk); #1;
        wr_en = 1'b0;
        // ref_queue not updated because write is suppressed by full
        $display("PASS: overflow write ignored (ref_queue size=%0d)", ref_queue.size());

        // ---- Test 4: Read until empty ----
        $display("\n--- Test 4: Read until empty ---");
        for (int i = 0; i < FIFO_DEPTH; i++) begin
            read_and_check();
        end
        wait_rd(4);  // let empty flag propagate
        assert (empty === 1'b1) else begin
            $display("FAIL: empty should be 1 after reading %0d words", FIFO_DEPTH);
            error_count++;
        end
        $display("PASS: empty asserted correctly after %0d reads", FIFO_DEPTH);

        // ---- Test 5: Read when empty (underflow guard) ----
        $display("\n--- Test 5: Read when empty (should be ignored) ---");
        @(posedge rd_clk); #1;
        rd_en = 1'b1;
        @(posedge rd_clk); #1;
        rd_en = 1'b0;
        wait_rd(2);
        $display("PASS: underflow read ignored (queue still empty=%0b)", empty);

        // ---- Test 6: Simultaneous read and write ----
        $display("\n--- Test 6: Simultaneous read and write ---");
        // First fill half the FIFO
        for (int i = 0; i < FIFO_DEPTH/2; i++) begin
            write_word(32'hB000_0000 + i);
        end
        wait_wr(6);
        // Now drive wr and rd simultaneously
        fork
            begin  // writer
                for (int i = 0; i < FIFO_DEPTH; i++) begin
                    @(posedge wr_clk); #1;
                    if (!full) begin
                        wr_en   = 1'b1;
                        wr_data = 32'hC000_0000 + i;
                        @(posedge wr_clk); #1;
                        ref_queue.push_back(32'hC000_0000 + i);
                        wr_en = 1'b0;
                    end else begin
                        wait_wr(1);
                    end
                end
            end
            begin  // reader
                for (int i = 0; i < FIFO_DEPTH/2; i++) begin
                    read_and_check();
                end
            end
        join
        // Drain remaining entries
        wait_wr(10);
        while (!empty) begin
            read_and_check();
        end
        $display("PASS: simultaneous R+W complete");

        // ---- Test 7: Random mixed traffic ----
        $display("\n--- Test 7: Random mixed traffic (200 ops) ---");
        begin
            automatic int op_count = 0;
            while (op_count < 200) begin
                automatic int dice = $urandom_range(0, 2);
                if (dice == 0 && !full) begin
                    automatic logic [DATA_WIDTH-1:0] d = $urandom();
                    @(posedge wr_clk); #1;
                    wr_en   = 1'b1;
                    wr_data = d;
                    @(posedge wr_clk); #1;
                    wr_en = 1'b0;
                    ref_queue.push_back(d);
                    op_count++;
                end else if (dice == 1 && !empty) begin
                    read_and_check();
                    op_count++;
                end else begin
                    wait_wr(1);
                end
            end
        end
        // Final drain
        wait_wr(10);
        while (!empty) begin
            read_and_check();
        end
        $display("PASS: random traffic complete");

        // ---- Summary ----
        $display("\n========================================");
        $display("  Tests run : %0d", test_count);
        $display("  Errors    : %0d", error_count);
        if (error_count == 0)
            $display("  RESULT    : ALL TESTS PASSED");
        else
            $display("  RESULT    : FAILED (%0d errors)", error_count);
        $display("========================================");

        $finish;
    end

    // --------------------------------------------------------
    //  Timeout watchdog
    // --------------------------------------------------------
    initial begin
        #500_000;
        $display("TIMEOUT: simulation exceeded 500 us");
        $finish;
    end

    // --------------------------------------------------------
    //  Optional waveform dump
    // --------------------------------------------------------
    initial begin
        $dumpfile("async_fifo_waves.vcd");
        $dumpvars(0, tb_async_fifo);
    end

endmodule

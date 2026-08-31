
`timescale 1ns/1ps

module fifo_mem #(
    parameter int DATA_WIDTH = 32,
    parameter int FIFO_DEPTH = 16,
    parameter int PTR_WIDTH  = 5    // $clog2(FIFO_DEPTH)+1
)(
    // Write port (wr_clk domain)
    input  logic                  wr_clk,
    input  logic                  wr_en_mem,
    input  logic [PTR_WIDTH-1:0]  wr_ptr,       // full binary pointer (MSB = wrap bit)
    input  logic [DATA_WIDTH-1:0] wr_data,

    // Read port (rd_clk domain)
    input  logic                  rd_clk,
    input  logic                  rd_en_mem,
    input  logic [PTR_WIDTH-1:0]  rd_ptr,       // full binary pointer (MSB = wrap bit)
    output logic [DATA_WIDTH-1:0] rd_data
);

    //  Memory array
    //  Address uses only the lower PTR_WIDTH-1 bits (strip
    //  the extra MSB that is used only for full/empty detection)
    localparam int ADDR_WIDTH = PTR_WIDTH - 1;

    logic [DATA_WIDTH-1:0] mem [0:FIFO_DEPTH-1];

    //  Write port — synchronous, wr_clk
    always_ff @(posedge wr_clk) begin
        if (wr_en_mem)
            mem[wr_ptr[ADDR_WIDTH-1:0]] <= wr_data;
    end

    //  Read port — synchronous, rd_clk
    //  rd_data is registered (output FF inside the memory).
    //  This is the conventional approach for FPGA block RAM.
    always_ff @(posedge rd_clk) begin
        if (rd_en_mem)
            rd_data <= mem[rd_ptr[ADDR_WIDTH-1:0]];
    end

endmodule

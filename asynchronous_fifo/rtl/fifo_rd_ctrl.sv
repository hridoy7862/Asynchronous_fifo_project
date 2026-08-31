
`timescale 1ns/1ps

module fifo_rd_ctrl #(
    parameter int PTR_WIDTH = 5
)(
    input  logic                 rd_clk,
    input  logic                 arst_n,
    input  logic                 rd_en,
    input  logic [PTR_WIDTH-1:0] wr_gray_sync,   // wr_ptr_gray synchronised into rd_clk

    output logic [PTR_WIDTH-1:0] rd_ptr,          // binary read pointer
    output logic [PTR_WIDTH-1:0] rd_ptr_gray,     // Gray-coded read pointer
    output logic                 rd_en_mem,        // gated read enable to memory
    output logic                 empty
);

    //  Next pointer (combinatorial)
    logic [PTR_WIDTH-1:0] rd_ptr_next;
    logic [PTR_WIDTH-1:0] rd_ptr_gray_next;
    logic                 empty_next;

    // Increment only when read is requested and FIFO is not empty
    assign rd_ptr_next      = rd_ptr + {{(PTR_WIDTH-1){1'b0}}, (rd_en & ~empty)};

    // Binary to Gray conversion
    assign rd_ptr_gray_next = rd_ptr_next ^ (rd_ptr_next >> 1);

    // Empty when current read Gray pointer equals synchronised write Gray pointer
    assign empty_next = (rd_ptr_gray_next == wr_gray_sync);

    //  Sequential — clocked by rd_clk, async reset
    always_ff @(posedge rd_clk or negedge arst_n) begin
        if (!arst_n) begin
            rd_ptr      <= '0;
            rd_ptr_gray <= '0;
            empty       <= 1'b1;   // FIFO is empty after reset
        end else begin
            rd_ptr      <= rd_ptr_next;
            rd_ptr_gray <= rd_ptr_gray_next;
            empty       <= empty_next;
        end
    end

    //  Memory read enable — gated
    //  Only read from memory when rd_en is asserted AND not empty
    assign rd_en_mem = rd_en & ~empty;

endmodule

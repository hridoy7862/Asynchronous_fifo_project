
`timescale 1ns/1ps

module fifo_wr_ctrl #(
    parameter int PTR_WIDTH  = 5,
    parameter int FIFO_DEPTH = 16
)(
    input  logic                 wr_clk,
    input  logic                 arst_n,
    input  logic                 wr_en,
    input  logic [PTR_WIDTH-1:0] rd_gray_sync,   // rd_ptr_gray synchronised into wr_clk

    output logic [PTR_WIDTH-1:0] wr_ptr,          // binary write pointer
    output logic [PTR_WIDTH-1:0] wr_ptr_gray,     // Gray-coded write pointer
    output logic                 wr_en_mem,        // gated write enable to memory
    output logic                 full
);

    //  Next pointer (combinatorial)
    logic [PTR_WIDTH-1:0] wr_ptr_next;
    logic [PTR_WIDTH-1:0] wr_ptr_gray_next;
    logic                 full_next;

    // Increment only when write is requested and FIFO is not full
    assign wr_ptr_next      = wr_ptr + {{(PTR_WIDTH-1){1'b0}}, (wr_en & ~full)};

    // Binary to Gray conversion
    assign wr_ptr_gray_next = wr_ptr_next ^ (wr_ptr_next >> 1);

    // Full when next Gray-coded write pointer equals the
    // synchronised read Gray pointer with top 2 bits inverted
    assign full_next = (wr_ptr_gray_next ==
                        {~rd_gray_sync[PTR_WIDTH-1],
                         ~rd_gray_sync[PTR_WIDTH-2],
                          rd_gray_sync[PTR_WIDTH-3:0]});

    //  Sequential — clocked by wr_clk, async reset
    always_ff @(posedge wr_clk or negedge arst_n) begin
        if (!arst_n) begin
            wr_ptr      <= '0;
            wr_ptr_gray <= '0;
            full        <= 1'b0;
        end else begin
            wr_ptr      <= wr_ptr_next;
            wr_ptr_gray <= wr_ptr_gray_next;
            full        <= full_next;
        end
    end

    //  Memory write enable — gated
    //  Only write to memory when wr_en is asserted AND not full
    assign wr_en_mem = wr_en & ~full;

endmodule

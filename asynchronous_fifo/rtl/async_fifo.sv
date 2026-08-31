
`timescale 1ns/1ps

module async_fifo #(
    parameter int DATA_WIDTH = 32,
    parameter int FIFO_DEPTH = 16
)(
    // Write interface
    input  logic                  wr_clk,
    input  logic                  arst_n,     // shared async reset (active-low)
    input  logic                  wr_en,
    input  logic [DATA_WIDTH-1:0] wr_data,
    output logic                  full,

    // Read interface
    input  logic                  rd_clk,
    input  logic                  rd_en,
    output logic [DATA_WIDTH-1:0] rd_data,
    output logic                  empty
);
    //  Derived parameters
    localparam int PTR_WIDTH = $clog2(FIFO_DEPTH) + 1;  // +1 for full/empty distinction

    //  Internal signals
    // Write-domain pointer (binary)
    logic [PTR_WIDTH-1:0] wr_ptr;
    // Read-domain pointer (binary)
    logic [PTR_WIDTH-1:0] rd_ptr;

    // Gray-coded pointers
    logic [PTR_WIDTH-1:0] wr_ptr_gray;
    logic [PTR_WIDTH-1:0] rd_ptr_gray;

    // Gray pointer after 2-FF synchronisation into the other domain
    logic [PTR_WIDTH-1:0] wr_gray_sync;   // wr_ptr_gray synchronised into rd_clk domain
    logic [PTR_WIDTH-1:0] rd_gray_sync;   // rd_ptr_gray synchronised into wr_clk domain

    // Memory write/read enables (gated)
    logic wr_en_mem;
    logic rd_en_mem;

    //  Sub-module instantiations

    // --- Dual-port memory ---
    fifo_mem #(
        .DATA_WIDTH (DATA_WIDTH),
        .FIFO_DEPTH (FIFO_DEPTH),
        .PTR_WIDTH  (PTR_WIDTH)
    ) u_mem (
        .wr_clk    (wr_clk),
        .wr_en_mem (wr_en_mem),
        .wr_ptr    (wr_ptr),
        .wr_data   (wr_data),
        .rd_clk    (rd_clk),
        .rd_en_mem (rd_en_mem),
        .rd_ptr    (rd_ptr),
        .rd_data   (rd_data)
    );

    // --- Write pointer + full flag logic ---
    fifo_wr_ctrl #(
        .PTR_WIDTH  (PTR_WIDTH),
        .FIFO_DEPTH (FIFO_DEPTH)
    ) u_wr_ctrl (
        .wr_clk      (wr_clk),
        .arst_n      (arst_n),
        .wr_en       (wr_en),
        .rd_gray_sync(rd_gray_sync),
        .wr_ptr      (wr_ptr),
        .wr_ptr_gray (wr_ptr_gray),
        .wr_en_mem   (wr_en_mem),
        .full        (full)
    );

    // --- Read pointer + empty flag logic ---
    fifo_rd_ctrl #(
        .PTR_WIDTH  (PTR_WIDTH)
    ) u_rd_ctrl (
        .rd_clk      (rd_clk),
        .arst_n      (arst_n),
        .rd_en       (rd_en),
        .wr_gray_sync(wr_gray_sync),
        .rd_ptr      (rd_ptr),
        .rd_ptr_gray (rd_ptr_gray),
        .rd_en_mem   (rd_en_mem),
        .empty       (empty)
    );

    // --- 2-FF synchroniser: wr_ptr_gray → rd_clk domain ---
    sync_2ff #(
        .WIDTH (PTR_WIDTH)
    ) u_sync_wr2rd (
        .clk    (rd_clk),
        .arst_n (arst_n),
        .d      (wr_ptr_gray),
        .q      (wr_gray_sync)
    );

    // --- 2-FF synchroniser: rd_ptr_gray → wr_clk domain ---
    sync_2ff #(
        .WIDTH (PTR_WIDTH)
    ) u_sync_rd2wr (
        .clk    (wr_clk),
        .arst_n (arst_n),
        .d      (rd_ptr_gray),
        .q      (rd_gray_sync)
    );

endmodule

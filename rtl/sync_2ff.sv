
`timescale 1ns/1ps

module sync_2ff #(
    parameter int WIDTH = 5
)(
    input  logic             clk,
    input  logic             arst_n,
    input  logic [WIDTH-1:0] d,
    output logic [WIDTH-1:0] q
);

    (* ASYNC_REG = "TRUE" *) logic [WIDTH-1:0] meta;   // stage 1 (metastability catch)
    (* ASYNC_REG = "TRUE" *) logic [WIDTH-1:0] sync;   // stage 2 (stable output)

    always_ff @(posedge clk or negedge arst_n) begin
        if (!arst_n) begin
            meta <= '0;
            sync <= '0;
        end else begin
            meta <= d;
            sync <= meta;
        end
    end

    assign q = sync;

endmodule

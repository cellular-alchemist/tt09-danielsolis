`default_nettype none

module izhikevich_neuron #(
    parameter signed [7:0] a_param = 8'sd13,    // Reduced precision
    parameter signed [7:0] b_param = 8'sd131,
    parameter signed [7:0] c_param = -8'sd42,
    parameter signed [7:0] d_param = 8'sd5
)(
    input wire clk,
    input wire reset_n,
    input wire signed [7:0] current,   // Reduced to 8-bit
    output reg signed [7:0] v,         // Reduced to 8-bit
    output reg signed [7:0] u,         // Reduced to 8-bit
    output wire spike
);
    localparam signed [7:0] THRESHOLD = 8'sd20;
    
    assign spike = (v >= THRESHOLD);

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            v <= c_param;
            u <= 8'sd0;
        end else begin
            // Simplified dynamics
            if (v >= THRESHOLD) begin
                v <= c_param;
                u <= u + d_param;
            end else begin
                v <= v + ((current - u) >>> 2);
                u <= u + ((a_param * ((b_param * v) >>> 4) - u) >>> 4);
            end
        end
    end
endmodule




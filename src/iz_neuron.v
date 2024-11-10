`default_nettype none

module izhikevich_neuron #(
    parameter signed [15:0] a_param = 16'sd1311,  // Reduced to 16 bits
    parameter signed [15:0] b_param = 16'sd13107,
    parameter signed [15:0] c_param = -16'sd4259,
    parameter signed [15:0] d_param = 16'sd524
)(
    input wire clk,
    input wire reset_n,
    input wire signed [15:0] current,  // Reduced precision
    output reg signed [15:0] v,        // Reduced precision
    output reg signed [15:0] u,
    output wire spike
);
    // Reduced precision constants
    localparam signed [15:0] THRESHOLD = 16'sd1966;
    localparam signed [15:0] K_0_04 = 16'sd26;
    localparam signed [15:0] K_5 = 16'sd3276;
    localparam signed [15:0] K_140 = 16'sd9175;

    reg signed [15:0] v_next, u_next;
    wire signed [15:0] v_sqr = (v * v) >>> 8;  // Reduced shift
    
    assign spike = (v >= THRESHOLD);

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            v <= c_param;
            u <= (b_param * c_param) >>> 8;
        end else begin
            // Simplified calculations with reduced precision
            v_next = v + ((K_0_04 * v_sqr + K_5 * v + K_140 - u + current) >>> 4);
            u_next = u + ((a_param * (b_param * v - u)) >>> 8);

            if (v_next >= THRESHOLD) begin
                v <= c_param;
                u <= u_next + d_param;
            end else begin
                v <= v_next;
                u <= u_next;
            end
        end
    end
endmodule




`default_nettype none  // Disable implicit net declarations for safety.

// Izhikevich neuron module with parameterizable neuron type (RS or FS).
// Uses fixed-point arithmetic in Q16.16 format
module izhikevich_neuron #(
    // Parameters are in Q16.16 fixed-point format (32 bits total, 16 integer bits, 16 fractional bits)
    parameter signed [31:0] a_param = 32'sd1311,        // 'a' parameter, scaled: 0.02 * 2^16
    parameter signed [31:0] b_param = 32'sd13107,       // 'b' parameter, scaled: 0.2 * 2^16
    parameter signed [31:0] c_param = -32'sd4259840,    // 'c' parameter, scaled: -65 * 2^16
    parameter signed [31:0] d_param = 32'sd524288       // 'd' parameter, scaled: 8 * 2^16
)(
    // Port declarations
    input wire clk,                               // Clock signal
    input wire reset_n,                           // Active-low reset signal
    input wire signed [31:0] current,             // Synaptic current input in Q16.16 format
    output reg signed [31:0] v,                   // Membrane potential 'v' in Q16.16 format
    output reg signed [31:0] u,                   // Recovery variable 'u' in Q16.16 format
    output wire spike                             // Spike output signal
);

    // ==============================
    // Constants and Parameters
    // ==============================

    // Threshold constant for spike generation (v >= 30 mV)
    parameter signed [31:0] threshold = 32'sd1966080; // threshold = 30 * 2^16

    // Fixed-point scaling factors
    parameter signed [31:0] k_0_04 = 32'sd2621;       // 0.04 * 2^16
    parameter signed [31:0] k_5 = 32'sd327680;        // 5 * 2^16
    parameter signed [31:0] k_140 = 32'sd9175040;     // 140 * 2^16

    // ==============================
    // Internal Variables
    // ==============================

    reg signed [31:0] v_new, u_new;
    reg signed [31:0] dv, du;
    reg signed [47:0] v_sqr_long;                     // Reduced from 64 to 48 bits
    reg signed [31:0] v_sqr;
    reg signed [31:0] k_v_sqr, k_v, total_input;
    reg signed [31:0] bv_minus_u;
    reg signed [31:0] a_times_bv_minus_u;             // Reduced from 64 to 32 bits

    // Temporary wire to hold the shifted multiplication result
    wire signed [47:0] mult_reset_shifted;

    // Assign the shifted multiplication result to the temporary wire
    assign mult_reset_shifted = (b_param * c_param) >>> 16;

    // Spike output is high when membrane potential exceeds threshold
    assign spike = (v >= threshold);

    // ==============================
    // Neuron Dynamics Implementation
    // ==============================

    // Sequential logic block triggered on rising edge of clk or negative edge of reset_n
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            // Reset condition: initialize 'v' and 'u'
            v <= c_param;  
            // Assign the lower 32 bits of the shifted result to 'u'
            // This effectively takes bits [31:0] from the shifted 48-bit result
            u <= mult_reset_shifted[31:0]; 
        end else begin
            // Calculate v^2
            v_sqr_long <= v * v;
            // Corrected Assignment: Extract bits [47:16] to assign to v_sqr
            v_sqr <= v_sqr_long[47:16];

            // Compute dv = 0.04v^2 + 5v + 140 - u + I
            k_v_sqr <= (k_0_04 * v_sqr) >>> 16;
            k_v <= (k_5 * v) >>> 16;
            total_input <= k_v_sqr + k_v + k_140 - u + current;

            // Update membrane potential 'v'
            dv <= total_input;
            v_new <= v + dv;

            // Compute du = a(b * v - u)
            bv_minus_u <= ((b_param * v) >>> 16) - u;
            a_times_bv_minus_u <= (a_param * bv_minus_u) >>> 16;
            // Corrected Assignment: Extract lower 32 bits to assign to du
            du <= a_times_bv_minus_u[31:0];
            u_new <= u + du;

            // Check for spike generation
            if (v_new >= threshold) begin
                v <= c_param;              // Reset 'v' to resting potential
                u <= u_new + d_param;      // Increment 'u' by 'd' after spike
            end else begin
                v <= v_new;
                u <= u_new;
            end
        end
    end

endmodule




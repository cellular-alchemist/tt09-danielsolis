`default_nettype none  // Disable implicit net declarations for safety

// Hopfield network module with on-chip Hebbian learning
module hopfield_network(
    input wire clk,                       // Clock signal
    input wire reset_n,                   // Active-low reset signal
    input wire learning_enable,           // Learning enable signal
    input wire [3:0] pattern_input,       // 4-bit Pattern input (from external source)
    output wire [6:0] spikes              // Spike outputs from neurons
);

parameter N = 7;                      // Total number of neurons

// ==============================
// Declarations
// ==============================

wire signed [31:0] v [0:N-1];
wire signed [31:0] u [0:N-1];
wire neuron_spikes [0:N-1];
wire signed [15:0] weights [0:N-1][0:N-1];
reg signed [31:0] currents [0:N-1];

integer i, j; // Procedural loop variables

// ==============================
// Instantiate Hebbian Learning Module
// ==============================

hebbian_learning #(.N(N)) learning_inst (
    .clk(clk),
    .reset_n(reset_n),
    .spikes(neuron_spikes),
    .learning_enable(learning_enable),
    .weights(weights)
);

// ==============================
// Instantiate Neurons
// ==============================

genvar n;
generate
    for (n = 0; n < N; n = n + 1) begin : neuron_array
        izhikevich_neuron neuron_inst (
            .clk(clk),
            .reset_n(reset_n),
            .current(currents[n]),
            .v(v[n]),
            .u(u[n]),
            .spike(neuron_spikes[n])
        );
    end
endgenerate

// ==============================
// Assign spikes
// ==============================

assign spikes = neuron_spikes;

// ==============================
// Compute Synaptic Currents
// ==============================

always @(*) begin
    // Variable declarations at the beginning
    reg signed [15:0] spike_fixed_point;
    reg signed [31:0] weighted_input;

    for (i = 0; i < N; i = i + 1) begin
        currents[i] = 32'sd0;
        for (j = 0; j < N; j = j + 1) begin
            if (i != j) begin
                spike_fixed_point = neuron_spikes[j] ? 16'sd256 : 16'sd0;
                weighted_input = weights[i][j] * spike_fixed_point;
                currents[i] = currents[i] + weighted_input;
            end
        end
        if (learning_enable && i < 4 && pattern_input[i]) begin
            currents[i] = currents[i] + 32'sd131072;
        end
    end
end

endmodule

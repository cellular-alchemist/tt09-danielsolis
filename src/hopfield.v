`default_nettype none  // Disable implicit net declarations for safety

// Hopfield network module with on-chip Hebbian learning
module hopfield_network(
    input wire clk,                       // Clock signal
    input wire reset_n,                   // Active-low reset signal
    input wire learning_enable,           // Learning enable signal
    input wire [3:0] pattern_input,       // 4-bit Pattern input (from external source)
    output wire [6:0] spikes              // Spike outputs from neurons
    // Additional ports can be added if necessary
);

    parameter N = 7;                      // Total number of neurons

    // ==============================
    // Neuron Outputs
    // ==============================

    wire signed [31:0] v [0:N-1];          // Membrane potentials of neurons
    wire signed [31:0] u [0:N-1];          // Recovery variables of neurons
    wire neuron_spikes [0:N-1];            // Individual neuron spike outputs

    // ==============================
    // Synaptic Weights and Currents
    // ==============================

    // Synaptic weights matrix
    wire signed [15:0] weights [0:N-1][0:N-1]; // Weights from neuron j to neuron i in Q8.8 format

    // Synaptic currents
    reg signed [31:0] currents [0:N-1];        // Synaptic currents for each neuron in Q16.16 format

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

    genvar n; // Generate loop variable
    generate
        for (n = 0; n < N; n = n + 1) begin : neuron_array
            if (n < 6) begin
                // Regular Spiking (RS) neurons (indices 0 to 5)
                izhikevich_neuron #(
                    .a_param(32'sd1311),       // 'a' parameter for RS neurons: 0.02 * 2^16
                    .b_param(32'sd13107),      // 'b' parameter for RS neurons: 0.2 * 2^16
                    .c_param(-32'sd4259840),   // 'c' parameter for RS neurons: -65 * 2^16
                    .d_param(32'sd524288)      // 'd' parameter for RS neurons: 8 * 2^16
                ) neuron_inst (
                    .clk(clk),                  // Clock signal
                    .reset_n(reset_n),          // Active-low reset signal
                    .current(currents[n]),      // Synaptic current input
                    .v(v[n]),                   // Membrane potential output
                    .u(u[n]),                   // Recovery variable output
                    .spike(neuron_spikes[n])    // Spike output
                );
            end else begin
                // Fast Spiking (FS) inhibitory neuron (index 6)
                izhikevich_neuron #(
                    .a_param(32'sd6554),       // 'a' parameter for FS neuron: 0.1 * 2^16
                    .b_param(32'sd13107),      // 'b' parameter for FS neuron: 0.2 * 2^16
                    .c_param(-32'sd4259840),   // 'c' parameter for FS neuron: -65 * 2^16
                    .d_param(32'sd131072)      // 'd' parameter for FS neuron: 2 * 2^16
                ) neuron_inst (
                    .clk(clk),                  // Clock signal
                    .reset_n(reset_n),          // Active-low reset signal
                    .current(currents[n]),      // Synaptic current input
                    .v(v[n]),                   // Membrane potential output
                    .u(u[n]),                   // Recovery variable output
                    .spike(neuron_spikes[n])    // Spike output
                );
            end
        end
    endgenerate

    // Assign neuron_spikes to output port 'spikes'
    generate
        for (n = 0; n < N; n = n + 1) begin : spike_generation
            assign spikes[n] = neuron_spikes[n];
        end
    endgenerate

    // ==============================
    // Compute Synaptic Currents
    // ==============================

    integer i, j; // Procedural loop variables
    always @(*) begin
        for (i = 0; i < N; i = i + 1) begin
            currents[i] = 32'sd0; // Initialize current to zero for neuron 'i'
            // Sum contributions from other neurons
            for (j = 0; j < N; j = j + 1) begin
                if (i != j) begin
                    // Multiply weight from neuron 'j' to 'i' by the spike output of neuron 'j'
                    // neuron_spikes[j] is 1 if neuron 'j' fired, 0 otherwise
                    // Convert spike (1-bit) to Q8.8 format
                    reg signed [15:0] spike_fixed_point;
                    spike_fixed_point = neuron_spikes[j] ? 16'sd256 : 16'sd0; // 1.0 in Q8.8 format

                    // Compute weighted input
                    reg signed [31:0] weighted_input;
                    weighted_input = weights[i][j] * spike_fixed_point; // Result in Q16.16 format

                    // Accumulate currents
                    currents[i] = currents[i] + weighted_input;
                end
            end
            // Include pattern input during learning phase
            if (learning_enable) begin
                // Map pattern_input bits to neurons (first 4 neurons)
                if (i < 4) begin
                    if (pattern_input[i]) begin
                        // Add a fixed current to neurons corresponding to '1' in pattern_input
                        currents[i] = currents[i] + 32'sd131072; // Equivalent to 2.0 in Q16.16 format
                    end
                end
            end
        end
    end

endmodule



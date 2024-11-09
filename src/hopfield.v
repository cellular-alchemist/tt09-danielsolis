`default_nettype none

module hopfield_network(
    input wire clk,                    // Clock signal.
    input wire reset_n,                // Active-low reset signal
    input wire learning_enable,        // Learning enable signal
    input wire [3:0] pattern_input,    // 4-bit Pattern input (from external source)
    output wire [6:0] spikes          // Spike outputs from neurons
);

    parameter N = 7;                   // Total number of neurons

    // Declarations
    wire [N-1:0] neuron_spikes;       // Spike outputs from neurons
    wire signed [(N*N*16)-1:0] weights_flat; // Flattened weights vector
    reg signed [31:0] currents [0:N-1];
    
    // Procedural loop variables
    integer i, j;

    // Instantiate Hebbian Learning Module
    hebbian_learning #(
        .N(N)
    ) learning_inst (
        .clk(clk),
        .reset_n(reset_n),
        .learning_enable(learning_enable),
        .spikes(neuron_spikes),
        .weights_flat(weights_flat)
    );

    // Instantiate Neurons
    genvar n;
    generate
        for (n = 0; n < N; n = n + 1) begin : neuron_array
            wire [31:0] unused_v;
            wire [31:0] unused_u;
            
            izhikevich_neuron neuron_inst (
                .clk(clk),
                .reset_n(reset_n),
                .current(currents[n]),
                .v(unused_v),
                .u(unused_u),
                .spike(neuron_spikes[n])
            );
        end
    endgenerate

    // Assign output spikes
    assign spikes = neuron_spikes;

    // Compute Synaptic Currents
    reg signed [15:0] weight;
    reg signed [15:0] spike_fixed_point;
    reg signed [31:0] weighted_input;

    always @(*) begin
        // Initialize all currents to zero
        for (i = 0; i < N; i = i + 1) begin
            currents[i] = 32'sd0;
        end
        
        // Calculate synaptic currents
        for (i = 0; i < N; i = i + 1) begin
            for (j = 0; j < N; j = j + 1) begin
                if (i != j) begin
                    // Extract weight from flattened array
                    weight = weights_flat[((i*N + j)*16) +: 16];
                    
                    // Convert spike to fixed-point representation
                    spike_fixed_point = neuron_spikes[j] ? 16'sd256 : 16'sd0;
                    
                    // Calculate weighted input
                    weighted_input = $signed(weight) * $signed(spike_fixed_point);
                    
                    // Accumulate current with overflow protection
                    if (!($signed(currents[i]) + $signed(weighted_input) > 32'sh7FFFFFFF) &&
                        !($signed(currents[i]) + $signed(weighted_input) < -32'sh80000000)) begin
                        currents[i] = currents[i] + weighted_input;
                    end
                end
            end
            
            // Add external input pattern if learning is enabled
            if (learning_enable && i < 4 && pattern_input[i]) begin
                // Add external current with overflow protection
                if (!($signed(currents[i]) + 32'sd131072 > 32'sh7FFFFFFF)) begin
                    currents[i] = currents[i] + 32'sd131072;
                end
            end
        end
    end

endmodule


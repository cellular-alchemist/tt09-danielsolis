`default_nettype none  // Disable implicit net declarations for safety

// Hebbian learning module for updating synaptic weights in the Hopfield network
module hebbian_learning #(
    parameter N = 7  // Total number of neurons in the network
)(
    input wire clk,                              // Clock signal
    input wire reset_n,                          // Active-low reset signal
    input wire [N-1:0] spikes,                   // Spike outputs from all neurons
    input wire learning_enable,                  // Enable signal for learning
    output reg signed [15:0] weights [0:N-1][0:N-1] // Synaptic weights in Q8.8 format
);

    // ==============================
    // Parameters and Variables
    // ==============================

    integer i, j;  // Loop variables for iterating over neurons

    // Learning rate (fixed internal parameter)
    // Adjust this value based on desired learning speed
    parameter signed [15:0] eta = 16'sd4; // Learning rate in Q8.8 format (0.015625)

    // ==============================
    // Weight Initialization and Learning Logic
    // ==============================

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            // Reset condition: initialize all weights to zero
            for (i = 0; i < N; i = i + 1) begin
                for (j = 0; j < N; j = j + 1) begin
                    weights[i][j] <= 16'sd0; // Set weight from neuron j to neuron i to zero
                end
            end
        end else if (learning_enable) begin
            // Learning phase: update weights based on neuron spikes
            for (i = 0; i < N; i = i + 1) begin
                for (j = 0; j < N; j = j + 1) begin
                    if (i != j) begin
                        // Exclude self-connections (no weight updates for weights[i][i])
                        if (spikes[i] & spikes[j]) begin
                            // Only update weights if both neurons have fired
                            if (i < 6 && j < 6) begin
                                // Both neurons are excitatory (RS neurons, indices 0 to 5)
                                // Update weights using the Hebbian learning rule for excitatory connections
                                weights[i][j] <= weights[i][j] + eta;
                            end else if (i == 6 || j == 6) begin
                                // At least one neuron is inhibitory (FS neuron, index 6)
                                // Update weights with a negative sign for inhibitory influence
                                weights[i][j] <= weights[i][j] - eta;
                            end
                            // Note: Adjustments can be made here for more complex learning rules or to prevent weight saturation
                        end
                        // If spikes[i] & spikes[j] is false, weights[i][j] remains unchanged
                    end
                    // No else clause needed; weights[i][i] remain unchanged
                end
            end
        end
        // If learning_enable is low, weights remain unchanged
    end

endmodule




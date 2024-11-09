`default_nettype none  // Disable implicit net declarations for safety.

// Hebbian Learning Module
// Manages synaptic weights based on neuron spikes
module hebbian_learning #(
    parameter N = 7                // Number of neurons
)(
    input wire clk,                // Clock signal
    input wire reset_n,            // Active-low reset signal
    input wire [N-1:0] spikes,     // Spike outputs from neurons
    output wire signed [15:0] weights_flat // Flattened weights matrix
);

    // ==============================
    // Internal Weight Matrix
    // ==============================
    
    // Declare a 2D array for weights internally
    reg signed [15:0] weights [0:N-1][0:N-1];
    
    // ==============================
    // Flattened Weights for Output
    // ==============================
    
    // Assign the 2D weights matrix to a flattened output vector
    // Order: weights[0][0], weights[0][1], ..., weights[N-1][N-1]
    assign weights_flat = { 
        weights[6][6], weights[6][5], weights[6][4], weights[6][3], weights[6][2], weights[6][1], weights[6][0],
        weights[5][6], weights[5][5], weights[5][4], weights[5][3], weights[5][2], weights[5][1], weights[5][0],
        weights[4][6], weights[4][5], weights[4][4], weights[4][3], weights[4][2], weights[4][1], weights[4][0],
        weights[3][6], weights[3][5], weights[3][4], weights[3][3], weights[3][2], weights[3][1], weights[3][0],
        weights[2][6], weights[2][5], weights[2][4], weights[2][3], weights[2][2], weights[2][1], weights[2][0],
        weights[1][6], weights[1][5], weights[1][4], weights[1][3], weights[1][2], weights[1][1], weights[1][0],
        weights[0][6], weights[0][5], weights[0][4], weights[0][3], weights[0][2], weights[0][1], weights[0][0]
    };

    // ==============================
    // Initialization and Reset
    // ==============================
    
    integer i, j;
    
    // Initialize weights to zero on reset
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            for (i = 0; i < N; i = i + 1) begin
                for (j = 0; j < N; j = j + 1) begin
                    weights[i][j] <= 16'sd0;
                end
            end
        end else begin
            // Hebbian learning rule: Δw_ij = η * spike_i * spike_j
            // For simplicity, assume η = 1
            for (i = 0; i < N; i = i + 1) begin
                for (j = 0; j < N; j = j + 1) begin
                    if (spikes[i] && spikes[j] && i != j) begin
                        weights[i][j] <= weights[i][j] + 16'sd1; // Increment weight
                    end else if (!spikes[i] || !spikes[j]) begin
                        weights[i][j] <= weights[i][j]; // No change
                    end
                end
            end
        end
    end
    
endmodule




`default_nettype none

module hebbian_learning #(
    parameter N = 7 // Number of neurons
)(
    input wire clk,                    // Clock signal
    input wire reset_n,                // Active-low reset signal
    input wire learning_enable,        // Learning enable signal
    input wire [N-1:0] spikes,        // Spike outputs from neurons
    output wire signed [N*N*16-1:0] weights_flat // Flattened weights matrix
);

    // Internal Weight Matrix
    reg signed [15:0] weights [0:N-1][0:N-1];

    // Flattened weights using generate block
    genvar x, y;
    generate
        for (x = 0; x < N; x = x + 1) begin : outer_loop
            for (y = 0; y < N; y = y + 1) begin : inner_loop
                assign weights_flat[((x*N + y)*16) +: 16] = weights[x][y];
            end
        end
    endgenerate

    integer i, j;

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            // Reset all weights to zero
            for (i = 0; i < N; i = i + 1) begin
                for (j = 0; j < N; j = j + 1) begin
                    weights[i][j] <= 16'sd0;
                end
            end
        end else if (learning_enable) begin
            // Hebbian learning rule: Δw_ij = η * spike_i * spike_j
            for (i = 0; i < N; i = i + 1) begin
                for (j = 0; j < N; j = j + 1) begin
                    if (spikes[i] && spikes[j] && i != j) begin
                        // Check for overflow before incrementing
                        if (weights[i][j] < 16'sd32767) begin
                            weights[i][j] <= weights[i][j] + 16'sd1;
                        end
                    end
                end
            end
        end
    end

endmodule




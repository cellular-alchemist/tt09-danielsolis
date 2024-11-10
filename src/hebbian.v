`default_nettype none

module hebbian_learning #(
    parameter N = 7 // Number of neurons
)(
    input wire clk,                    
    input wire reset_n,                
    input wire learning_enable,        
    input wire [N-1:0] spikes,        
    output wire signed [N*N*16-1:0] weights_flat, // Keep for compatibility
    output reg signed [15:0] temp_weight          // Single weight output for verification
);
    // Reduce weight precision to 8 bits to save area
    reg signed [7:0] weights [0:N-1][0:N-1];

    // Optimized weight flattening (keep for compatibility)
    genvar x, y;
    generate
        for (x = 0; x < N; x = x + 1) begin : outer_loop
            for (y = 0; y < N; y = y + 1) begin : inner_loop
                assign weights_flat[((x*N + y)*16) +: 16] = {{8{weights[x][y][7]}}, weights[x][y]};
            end
        end
    endgenerate

    // Single counter for both loops to save area
    reg [2:0] counter_i, counter_j;
    
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            counter_i <= 3'd0;
            counter_j <= 3'd0;
            temp_weight <= 16'sd0;
            for (integer i = 0; i < N; i = i + 1) begin
                for (integer j = 0; j < N; j = j + 1) begin
                    weights[i][j] <= 8'sd0;
                end
            end
        end else if (learning_enable) begin
            if (spikes[counter_i] && spikes[counter_j] && counter_i != counter_j) begin
                if ($signed(weights[counter_i][counter_j]) < 8'sd127) begin
                    weights[counter_i][counter_j] <= $signed(weights[counter_i][counter_j]) + 8'sd1;
                    temp_weight <= $signed(weights[counter_i][counter_j]) + 16'sd1;
                end
            end
            
            // Update counters
            if (counter_j == N-1) begin
                counter_j <= 3'd0;
                if (counter_i == N-1)
                    counter_i <= 3'd0;
                else
                    counter_i <= counter_i + 3'd1;
            end else begin
                counter_j <= counter_j + 3'd1;
            end
        end
    end

endmodule




`default_nettype none

module hebbian_learning #(
    parameter N = 7 
)(
    input wire clk,                    
    input wire reset_n,                
    input wire learning_enable,        
    input wire [N-1:0] spikes,        
    output wire signed [(N*N*8)-1:0] weights_flat,  // Reduced to 8-bit width
    output reg signed [7:0] temp_weight             // Reduced to 8-bit
);
    // Reduced to 4-bit weights to save area
    reg signed [3:0] weights [0:N-1][0:N-1];

    // Simplified weight flattening
    genvar x, y;
    generate
        for (x = 0; x < N; x = x + 1) begin : outer_loop
            for (y = 0; y < N; y = y + 1) begin : inner_loop
                assign weights_flat[((x*N + y)*8) +: 8] = {weights[x][y][3], weights[x][y][3], weights[x][y][3], weights[x][y][3], weights[x][y]};
            end
        end
    endgenerate

    // Use single 3-bit counter and state machine to save area
    reg [2:0] counter;
    reg [1:0] state;
    localparam IDLE = 2'b00, UPDATE = 2'b01, NEXT = 2'b10;

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            counter <= 3'd0;
            state <= IDLE;
            temp_weight <= 8'sd0;
            for (integer i = 0; i < N; i = i + 1) begin
                for (integer j = 0; j < N; j = j + 1) begin
                    weights[i][j] <= 4'sd0;
                end
            end
        end else if (learning_enable) begin
            case (state)
                IDLE: begin
                    counter <= 3'd0;
                    state <= UPDATE;
                end
                
                UPDATE: begin
                    if (spikes[counter] && (counter < N-1)) begin
                        if ($signed(weights[counter][counter+1]) < 4'sd7) begin
                            weights[counter][counter+1] <= weights[counter][counter+1] + 4'sd1;
                            temp_weight <= {weights[counter][counter+1][3], weights[counter][counter+1][3], weights[counter][counter+1][3], weights[counter][counter+1][3], weights[counter][counter+1]} + 8'sd1;
                        end
                    end
                    state <= NEXT;
                end
                
                NEXT: begin
                    if (counter == N-1)
                        state <= IDLE;
                    else begin
                        counter <= counter + 3'd1;
                        state <= UPDATE;
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule




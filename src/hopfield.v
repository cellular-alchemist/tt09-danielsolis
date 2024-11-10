`default_nettype none

module hopfield_network(
    input wire clk,
    input wire reset_n,
    input wire learning_enable,
    input wire [3:0] pattern_input,
    output wire [6:0] spikes
);
    parameter N = 7;

    reg [N-1:0] neuron_spikes;
    reg signed [7:0] currents;  // Reduced to 8-bit
    reg [2:0] active_neuron;
    wire neuron_spike;
    
    // Connect weights_flat to avoid empty reference
    wire signed [(N*N*8)-1:0] weights_flat;
    wire signed [7:0] temp_weight;

    // Single neuron instance
    izhikevich_neuron #(
        .a_param(8'sd13),    // Reduced precision parameters
        .b_param(8'sd131),
        .c_param(-8'sd42),
        .d_param(8'sd5)
    ) neuron_inst (
        .clk(clk),
        .reset_n(reset_n),
        .current(currents),
        .v(),    // Explicitly use /* verilator lint_off PINCONNECTEMPTY */
        .u(),    // for these unused outputs
        .spike(neuron_spike)
    );

    // Hebbian learning instance
    hebbian_learning #(.N(N)) learning_inst (
        .clk(clk),
        .reset_n(reset_n),
        .learning_enable(learning_enable),
        .spikes(neuron_spikes),
        .weights_flat(weights_flat),  // Connected but unused
        .temp_weight(temp_weight)
    );

    // Simplified neuron management
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            active_neuron <= 3'd0;
            neuron_spikes <= 7'd0;
            currents <= 8'sd0;
        end else begin
            // Update neuron spikes
            neuron_spikes[active_neuron] <= neuron_spike;
            
            // Update active neuron
            if (active_neuron == N-1)
                active_neuron <= 3'd0;
            else
                active_neuron <= active_neuron + 3'd1;
                
            // Simple current computation
            currents <= pattern_input[active_neuron] ? 
                       (8'sd16 + temp_weight) : 8'sd0;
        end
    end

    assign spikes = neuron_spikes;

    // Suppress lint warnings
    /* verilator lint_off PINCONNECTEMPTY */
    /* verilator lint_on PINCONNECTEMPTY */

endmodule
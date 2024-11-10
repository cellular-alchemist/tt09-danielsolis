`default_nettype none

module hopfield_network(
    input wire clk,
    input wire reset_n,
    input wire learning_enable,
    input wire [3:0] pattern_input,
    output wire [6:0] spikes
);
    parameter N = 7;

    wire [N-1:0] neuron_spikes;
    wire signed [N*N*16-1:0] weights_flat;
    reg signed [15:0] currents [0:N-1];  // Reduced to 16 bits
    
    // Sequential neuron instantiation to save area
    reg [2:0] active_neuron;
    wire [15:0] neuron_v, neuron_u;
    wire neuron_spike;
    
    izhikevich_neuron neuron_inst (
        .clk(clk),
        .reset_n(reset_n),
        .current(currents[active_neuron]),
        .v(neuron_v),
        .u(neuron_u),
        .spike(neuron_spike)
    );

    // Register spikes
    always @(posedge clk) begin
        if (active_neuron < N)
            neuron_spikes[active_neuron] <= neuron_spike;
        active_neuron <= (active_neuron == N-1) ? 0 : active_neuron + 1;
    end

    hebbian_learning #(.N(N)) learning_inst (
        .clk(clk),
        .reset_n(reset_n),
        .learning_enable(learning_enable),
        .spikes(neuron_spikes),
        .weights_flat(weights_flat)
    );

    // Simplified current computation
    integer i;
    always @(*) begin
        for (i = 0; i < N; i = i + 1) begin
            currents[i] = pattern_input[i] ? 16'sd1024 : 16'sd0;
            if (learning_enable && i < 4 && pattern_input[i])
                currents[i] = currents[i] + 16'sd2048;
        end
    end

    assign spikes = neuron_spikes;
endmodule


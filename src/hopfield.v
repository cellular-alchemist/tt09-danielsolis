`default_nettype none

module hopfield_network(
    input wire clk,
    input wire reset_n,
    input wire learning_enable,
    input wire [3:0] pattern_input,
    output wire [6:0] spikes
);
    parameter N = 7;

    // Change neuron_spikes from wire to reg since we're assigning it in an always block
    reg [N-1:0] neuron_spikes;
    wire signed [N*N*16-1:0] weights_flat;
    reg signed [15:0] currents [0:N-1];  // Reduced to 16 bits
    
    // Sequential neuron instantiation to save area
    reg [2:0] active_neuron;
    wire [15:0] neuron_v, neuron_u;
    wire neuron_spike;
    
    // Registers for spike storage
    reg [N-1:0] spike_storage;
    
    izhikevich_neuron neuron_inst (
        .clk(clk),
        .reset_n(reset_n),
        .current(currents[active_neuron]),
        .v(neuron_v),
        .u(neuron_u),
        .spike(neuron_spike)
    );

    // Register spikes and manage active neuron
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            active_neuron <= 0;
            spike_storage <= 0;
            neuron_spikes <= 0;
        end else begin
            // Update spike storage with current neuron's spike
            spike_storage[active_neuron] <= neuron_spike;
            
            // Update active neuron counter
            if (active_neuron == N-1) begin
                active_neuron <= 0;
                // Update all neuron spikes at once when we've processed all neurons
                neuron_spikes <= spike_storage;
            end else begin
                active_neuron <= active_neuron + 1;
            end
        end
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
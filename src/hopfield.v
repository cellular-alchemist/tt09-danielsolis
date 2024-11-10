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
    wire signed [N*N*16-1:0] weights_flat;
    reg signed [15:0] currents [0:N-1];
    
    reg [2:0] active_neuron;
    wire neuron_spike;
    
    reg [N-1:0] spike_storage;
    
    izhikevich_neuron neuron_inst (
        .clk(clk),
        .reset_n(reset_n),
        .current(currents[active_neuron]),
        .v(),  // Explicitly leave unconnected since unused
        .u(),  // Explicitly leave unconnected since unused
        .spike(neuron_spike)
    );

    // Register spikes and manage active neuron
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            active_neuron <= 3'd0;
            spike_storage <= {N{1'b0}};
            neuron_spikes <= {N{1'b0}};
        end else begin
            spike_storage[active_neuron] <= neuron_spike;
            
            if (active_neuron == (N-1)) begin
                active_neuron <= 3'd0;
                neuron_spikes <= spike_storage;
            end else begin
                active_neuron <= active_neuron + 3'd1;
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

    // Current computation
    always @(*) begin
        for (integer i = 0; i < N; i = i + 1) begin
            currents[i] = pattern_input[i] ? 16'sd1024 : 16'sd0;
            if (learning_enable && i < 4 && pattern_input[i]) begin
                currents[i] = currents[i] + 16'sd2048;
            end
        end
    end

    assign spikes = neuron_spikes;

endmodule
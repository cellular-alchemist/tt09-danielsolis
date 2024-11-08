// ==============================
// Compute Synaptic Currents
// ==============================

integer i, j; // Procedural loop variables

always @(*) begin
    // Move variable declarations to the beginning of the always block
    reg signed [15:0] spike_fixed_point;
    reg signed [31:0] weighted_input;
    for (i = 0; i < N; i = i + 1) begin
        currents[i] = 32'sd0; // Initialize current to zero for neuron 'i'
        // Sum contributions from other neurons
        for (j = 0; j < N; j = j + 1) begin
            if (i != j) begin
                // Convert spike (1-bit) to Q8.8 format
                spike_fixed_point = neuron_spikes[j] ? 16'sd256 : 16'sd0; // 1.0 in Q8.8 format

                // Compute weighted input
                weighted_input = weights[i][j] * spike_fixed_point; // Result in Q16.16 format

                // Accumulate currents
                currents[i] = currents[i] + weighted_input;
            end
        end
        // Include pattern input during learning phase
        if (learning_enable) begin
            // Map pattern_input bits to neurons (first 4 neurons)
            if (i < 4) begin
                if (pattern_input[i]) begin
                    // Add a fixed current to neurons corresponding to '1' in pattern_input
                    currents[i] = currents[i] + 32'sd131072; // Equivalent to 2.0 in Q16.16 format
                end
            end
        end
    end
end



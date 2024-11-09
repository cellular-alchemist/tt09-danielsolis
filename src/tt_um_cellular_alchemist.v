`default_nettype none  // Disable implicit net declarations for safety.

// Top-level module for the Hopfield network with on-chip learning
module tt_um_cellular_alchemist (
    // Dedicated inputs and outputs
    input  wire [7:0] ui_in,     // Dedicated inputs (e.g., external control signals)
    output wire [7:0] uo_out,    // Dedicated outputs (e.g., network status indicators)
    
    // General-purpose IOs
    input  wire [7:0] uio_in,    // IOs: Input path (e.g., pattern inputs)
    output wire [7:0] uio_out,   // IOs: Output path (e.g., neuron spike outputs)
    output wire [7:0] uio_oe,    // IOs: Enable path (1=output, 0=input)
    
    // Control signals
    input  wire       ena,       // Enable signal (always 1 when the design is powered)
    input  wire       clk,       // Clock signal
    input  wire       rst_n      // Reset signal (active low)
);

// ==============================
// Signal Declarations
// ==============================

wire learning_enable;              // Signal to enable learning in the network
wire [6:0] spikes;                 // Spike outputs from all neurons (7 neurons)
wire [3:0] pattern_input;          // 4-bit pattern input from external source
reg  [2:0] activity_count;         // Activity count (number of active neurons)
reg  [2:0] temp_activity_count;    // Temporary variable for accumulation
integer i;

// Assign IO enable signals: uio pins 0-3 as inputs, 4-7 as outputs
assign uio_oe = 8'b11110000;  // uio_oe[7:4]=1 (outputs), uio_oe[3:0]=0 (inputs)

// Handle unused inputs to prevent warnings
wire unused = &{ena, ui_in[7:1], uio_in[7:4]};

// ==============================
// Mapping External Signals
// ==============================

// Map external pattern inputs from uio_in[3:0] (4-bit pattern)
assign pattern_input = uio_in[3:0];

// Map learning enable signal from ui_in[0]
assign learning_enable = ui_in[0];

// Map spike outputs to uio_out[7:4]
assign uio_out[7:4] = spikes[3:0]; // Output spikes[3:0] to uio_out[7:4]
assign uio_out[3:0] = 4'b0000;     // Set uio_out[3:0] to 0 since they are inputs

// ==============================
// Instantiate Hopfield Network
// ==============================

hopfield_network hopfield_inst (
    .clk(clk),
    .reset_n(rst_n),
    .learning_enable(learning_enable),
    .pattern_input(pattern_input),
    .spikes(spikes)
);

// ==============================
// Network Status Indicators
// ==============================

// Calculate network activity level (number of neurons that fired)
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        activity_count <= 3'd0;
    end else begin
        temp_activity_count <= 3'd0; // Use non-blocking assignment for accumulation
        for (i = 0; i < 7; i = i + 1) begin
            temp_activity_count <= temp_activity_count + {2'b00, spikes[i]};
        end
        activity_count <= temp_activity_count; // Update activity_count on clock edge
    end
end

// Map activity_count and spikes[6:4] to uo_out
assign uo_out = {activity_count[2:0], 2'b00, spikes[6:4]};

endmodule




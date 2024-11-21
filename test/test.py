import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge, FallingEdge
from cocotb.binary import BinaryValue
import logging
from enum import IntEnum

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class HWConstants:
    """
    Hardware configuration constants derived from Verilog implementation.
    Centralizes all timing and parameter values to ensure tests match hardware behavior.
    """
    # Network Architecture Constants
    NUM_NEURONS = 7
    WEIGHT_BITS = 4
    MAX_WEIGHT = (1 << (WEIGHT_BITS - 1)) - 1

    # State Machine States (from hebbian.v)
    STATE_IDLE = 0
    STATE_UPDATE = 1
    STATE_NEXT = 2
    STATE_MACHINE_CYCLE = 3  # Complete cycle through states

    # Timing Constants
    NEURON_CYCLES = NUM_NEURONS + 2  # Cycles for complete network update
    LEARNING_CYCLES = NUM_NEURONS * 3  # Cycles for weight updates
    
    # Izhikevich Neuron Parameters (from iz_neuron.v)
    THRESHOLD = 20
    MEMBRANE_TAU = 20
    RECOVERY_TAU = 50
    REFRACTORY_PERIOD = 10
    
    # Composite Timing Constants
    STABILIZATION_CYCLES = NEURON_CYCLES * 5
    WEIGHT_UPDATE_DELAY = STATE_MACHINE_CYCLE * NUM_NEURONS
    NEURON_STABILIZATION = MEMBRANE_TAU + RECOVERY_TAU
    SPIKE_WINDOW = MEMBRANE_TAU * 5
    TOTAL_SPIKE_CHECK = SPIKE_WINDOW + NEURON_CYCLES

async def initialize_dut(dut):
    """Initialize DUT with clock and reset, accounting for sequential processing."""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset with enough cycles for all sequential elements
    dut.rst_n.value = 0
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    await ClockCycles(dut.clk, HWConstants.NEURON_CYCLES * 2)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, HWConstants.NEURON_CYCLES)

@cocotb.test()
async def test_reset_state(dut):
    """
    Purpose: Verify proper initialization accounting for sequential processing.
    
    Logic: Wait for complete initialization of all neurons and weight registers,
    checking multiple cycles to ensure stability.
    """
    await initialize_dut(dut)
    
    for _ in range(HWConstants.NEURON_CYCLES):
        await RisingEdge(dut.clk)
        assert dut.uo_out.value == 0, f"Expected uo_out=0, got {dut.uo_out.value}"
        assert dut.uio_out.value == 0, f"Expected uio_out=0, got {dut.uio_out.value}"
    
    logger.info("Reset state test completed successfully")

@cocotb.test()
async def test_single_neuron_activation(dut):
    """
    Purpose: Verify single neuron activation with Izhikevich dynamics timing.
    
    Logic: Account for membrane potential dynamics, recovery variable,
    and refractory period in the Izhikevich model.
    """
    await initialize_dut(dut)
    
    # Set input pattern to activate single neuron
    dut.uio_in.value = 0x1
    dut.ui_in.value = 0  # Disable learning
    
    # Wait for initial membrane potential stabilization
    await ClockCycles(dut.clk, HWConstants.NEURON_STABILIZATION)
    
    # Monitor for spike with proper timing windows
    spike_detected = False
    refractory_observed = False
    
    for _ in range(HWConstants.TOTAL_SPIKE_CHECK):
        await RisingEdge(dut.clk)
        if dut.uio_out.value & 0x10:
            spike_detected = True
            # Verify refractory period
            for _ in range(HWConstants.REFRACTORY_PERIOD):
                await RisingEdge(dut.clk)
                if not (dut.uio_out.value & 0x10):
                    refractory_observed = True
                    break
            break
    
    assert spike_detected, "No spike detected within membrane time constant window"
    assert refractory_observed, "No refractory period observed after spike"
    logger.info("Single neuron activation test completed with proper dynamics")

@cocotb.test()
async def test_hebbian_learning(dut):
    """
    Purpose: Verify Hebbian learning with explicit state machine timing.
    
    Logic: Account for IDLE->UPDATE->NEXT state transitions and ensure
    proper weight updates across full state machine cycles.
    """
    await initialize_dut(dut)
    
    # Enable learning
    dut.ui_in.value = 0x1
    
    # Present pattern and wait for complete state machine cycle
    test_pattern = 0x3  # Two adjacent neurons
    dut.uio_in.value = test_pattern
    
    # Wait for initial state machine cycle
    await ClockCycles(dut.clk, HWConstants.STATE_MACHINE_CYCLE)
    
    # Monitor weight updates over multiple complete cycles
    activities = []
    for cycle in range(5):  # Test multiple update cycles
        # Wait for complete weight update sequence
        await ClockCycles(dut.clk, HWConstants.WEIGHT_UPDATE_DELAY)
        
        # Sample activity at stable points in state machine cycle
        await ClockCycles(dut.clk, HWConstants.STATE_MACHINE_CYCLE - 1)
        activities.append(dut.uo_out.value & 0x7)
        
        # Verify activity increases with weight updates
        if cycle > 0:
            assert activities[-1] >= activities[-2], \
                f"Weight update failed in cycle {cycle}"
    
    # Verify final weight saturation
    assert max(activities) <= HWConstants.MAX_WEIGHT, \
        "Weights exceeded 4-bit limitation"
    assert max(activities) > min(activities), \
        "No learning progression detected"
    
    logger.info("Hebbian learning test completed with state machine timing verification")

@cocotb.test()
async def test_pattern_recall(dut):
    """
    Purpose: Verify pattern recall with sequential updates.
    
    Logic: Account for neuron update sequence and stabilization time
    in pattern completion.
    """
    await initialize_dut(dut)
    
    # Store pattern with sequential processing consideration
    dut.ui_in.value = 0x1  # Enable learning
    test_pattern = 0x7  # Three active neurons
    dut.uio_in.value = test_pattern
    
    # Wait for learning with sequential updates
    await ClockCycles(dut.clk, HWConstants.LEARNING_CYCLES * 5)
    
    # Disable learning and present partial pattern
    dut.ui_in.value = 0x0
    dut.uio_in.value = 0x3  # Partial pattern
    
    # Wait for sequential pattern completion
    await ClockCycles(dut.clk, HWConstants.STABILIZATION_CYCLES)
    
    # Sample activity over multiple cycles
    activities = []
    for _ in range(HWConstants.NEURON_CYCLES):
        await RisingEdge(dut.clk)
        activities.append(dut.uo_out.value & 0x7)
    
    # Verify pattern completion within weight limitations
    max_activity = max(activities)
    assert max_activity > 0x3, "Pattern completion failed"
    assert max_activity <= HWConstants.MAX_WEIGHT, "Activity exceeded weight limit"
    
    logger.info("Pattern recall test completed successfully")

@cocotb.test()
async def test_network_stability(dut):
    """
    Purpose: Verify stability with fixed-point arithmetic constraints.
    
    Logic: Monitor activity considering sequential updates and weight
    saturation limits.
    """
    await initialize_dut(dut)
    
    # Present initial pattern
    dut.uio_in.value = 0x5
    
    # Monitor activity over multiple complete network cycles
    activity_samples = []
    for _ in range(HWConstants.STABILIZATION_CYCLES):
        await ClockCycles(dut.clk, HWConstants.NEURON_CYCLES)
        activity_samples.append(dut.uo_out.value & 0x7)
    
    # Calculate stability metrics with fixed-point considerations
    max_activity = max(activity_samples)
    min_activity = min(activity_samples[HWConstants.NEURON_CYCLES:])
    
    # Verify stability within hardware constraints
    assert max_activity <= HWConstants.MAX_WEIGHT, "Activity exceeded weight range"
    assert max_activity < HWConstants.NUM_NEURONS, "Too many neurons active"
    assert min_activity > 0, "Network activity died out"
    
    # Check for activity oscillation within acceptable range
    activity_range = max_activity - min_activity
    assert activity_range <= HWConstants.MAX_WEIGHT // 2, \
        "Network showing excessive activity oscillation"
    
    logger.info("Network stability test completed successfully")

async def inject_noise(pattern, noise_level=1):
    """Helper function to inject noise while respecting hardware constraints."""
    noise_mask = (1 << noise_level) - 1
    return pattern ^ noise_mask

@cocotb.test()
async def test_noise_robustness(dut):
    """
    Purpose: Verify noise robustness with hardware constraints.
    
    Logic: Test pattern recovery considering sequential updates and
    fixed-point limitations.
    """
    await initialize_dut(dut)
    
    # Store original pattern
    dut.ui_in.value = 0x1  # Enable learning
    original_pattern = 0x5
    dut.uio_in.value = original_pattern
    await ClockCycles(dut.clk, HWConstants.LEARNING_CYCLES * 3)
    
    # Disable learning
    dut.ui_in.value = 0x0
    
    # Test with controlled noise levels
    for noise_level in range(1, 3):
        noisy_pattern = await inject_noise(original_pattern, noise_level)
        dut.uio_in.value = noisy_pattern
        
        # Allow network to settle with sequential updates
        await ClockCycles(dut.clk, HWConstants.STABILIZATION_CYCLES)
        
        # Sample final state over multiple cycles
        recovered_patterns = []
        for _ in range(HWConstants.NEURON_CYCLES):
            await RisingEdge(dut.clk)
            recovered_patterns.append(dut.uio_out.value & 0xF0)
        
        # Verify recovery within hardware constraints
        final_pattern = max(recovered_patterns)
        assert final_pattern != 0, "Failed to recover from noise"
        assert bin(final_pattern).count('1') <= HWConstants.MAX_WEIGHT, \
            "Recovery exceeded weight limitations"
    
    logger.info("Noise robustness test completed successfully")

if __name__ == "__main__":
    logger.info("Starting Neuromorphic Circuit Tests")
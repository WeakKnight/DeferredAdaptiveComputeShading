import slangpy as spy
import numpy as np
from pathlib import Path

def testWaveOps(funcName):
    print(funcName)
    
    EXAMPLE_DIR = Path(__file__).parent
    
    # Create device
    device = spy.Device(
        enable_debug_layers=True,
        compiler_options={"include_paths": [EXAMPLE_DIR]},
    )
    
    # Load test program
    test_program = device.load_program("TestWaveOps.slang", [funcName])
    test_kernel = device.create_compute_kernel(test_program)
    
    # Create output buffer - we'll test with 32 threads (1 wave)
    num_threads = 64
    output_buffer = device.create_buffer(
        struct_size = 4,
        usage = spy.BufferUsage.unordered_access | spy.BufferUsage.copy_source | spy.BufferUsage.shader_resource,
        size = 4 * num_threads,
    )
    
    # Run the test
    command_encoder = device.create_command_encoder()
    with command_encoder.begin_compute_pass() as pass_encoder:
        shader_object = pass_encoder.bind_pipeline(test_kernel.pipeline)
        cursor = spy.ShaderCursor(shader_object)
        cursor.gOutputBuffer = output_buffer
        pass_encoder.dispatch([num_threads, 1, 1])
    
    device.submit_command_buffer(command_encoder.finish())
    device.wait_for_idle()
    
    # Read back results
    results = output_buffer.to_numpy()
    results_filtered = results[::4]
    print(results_filtered)
    
def main():
    testWaveOps('testWaveGetLaneIndex')
    testWaveOps('testWaveActiveCountBits')
    testWaveOps('testWavePrefixCountBits')

if __name__ == "__main__":
    main()
import slangpy as spy
import numpy as np
import imageio
from pathlib import Path

EXAMPLE_DIR = Path(__file__).parent

def loadImageData(path, w, h):
    imageData = imageio.v3.imread(path)
    # reshape imageData into 512x512x4, adding an alpha channel
    print(imageData.shape)
    if len(imageData.shape) >= 3 and imageData.shape[2] == 3:
        imageData = np.concatenate([imageData, np.ones((w, h, 1), dtype=np.uint8) * 255], axis=2)
    return imageData

device = spy.Device(
    enable_debug_layers=True,
    compiler_options={"include_paths": [EXAMPLE_DIR]},
)

gbufferPassProgram = device.load_program("GBufferPass.slang", ["main"])
gbufferPassKernel = device.create_compute_kernel(gbufferPassProgram)

lightingPassProgram = device.load_program("LightingPass.slang", ["main"])
lightingPassKernel = device.create_compute_kernel(lightingPassProgram)

adaptiveLightingPassProgram = device.load_program("AdaptiveLightingPass.slang", ["main"])
adaptiveLightingPassKernel = device.create_compute_kernel(adaptiveLightingPassProgram)

screen_width = 1920
screen_height = 1080

blueNoiseTexData = loadImageData("BlueNoise.png", 256, 256)
blueNoiseTex = device.create_texture(
    width = 256,
    height = 256,
    format = spy.Format.rgba8_unorm,
    usage = spy.TextureUsage.shader_resource,
    data = blueNoiseTexData
)

linearClampSampler = device.create_sampler()
linearRepeatSampler = device.create_sampler(address_u=spy.TextureAddressingMode.mirror_repeat)

resultTex = device.create_texture(
    width = screen_width,
    height = screen_height,
    format = spy.Format.rgba8_unorm,
    usage = spy.TextureUsage.shader_resource | spy.TextureUsage.unordered_access,
)

posTex = device.create_texture(
    width = screen_width,
    height = screen_height,
    format = spy.Format.rgba32_float,
    usage = spy.TextureUsage.shader_resource | spy.TextureUsage.unordered_access,
)

normalTex = device.create_texture(
    width = screen_width,
    height = screen_height,
    format = spy.Format.rgba16_float,
    usage = spy.TextureUsage.shader_resource | spy.TextureUsage.unordered_access,
)

diffuseTex = device.create_texture(
    width = screen_width,
    height = screen_height,
    format = spy.Format.rgba16_float,
    usage = spy.TextureUsage.shader_resource | spy.TextureUsage.unordered_access,
)

specularTex = device.create_texture(
    width = screen_width,
    height = screen_height,
    format = spy.Format.rgba16_float,
    usage = spy.TextureUsage.shader_resource | spy.TextureUsage.unordered_access,
)

layoutScratchBuffer = device.create_buffer(usage = 
                                           spy.BufferUsage.unordered_access
                                           |spy.BufferUsage.shader_resource
                                           |spy.BufferUsage.copy_destination
                                           |spy.BufferUsage.copy_source,
                                           struct_size = 4, 
                                           element_count = 8,
                                           data = np.array([0] * 8, dtype=np.uint32))
command_encoder = device.create_command_encoder()
with command_encoder.begin_compute_pass() as pass_encoder:
    # GBuffer Pass
    shader_object = pass_encoder.bind_pipeline(gbufferPassKernel.pipeline)
    cursor = spy.ShaderCursor(shader_object)

    cursor.gPositionTexture = posTex
    cursor.gNormalTexture = normalTex
    cursor.gDiffuseTexture = diffuseTex
    cursor.gSpecularTexture = specularTex
    
    cursor.iResolution = spy.float2(screen_width, screen_height)
    cursor.iFrame = 42
    cursor.iTime = 8

    cursor.gBlueNoiseTex = blueNoiseTex
    cursor.gLinearClampSampler = linearClampSampler
    cursor.gLinearRepeatSampler = linearRepeatSampler

    pass_encoder.dispatch([screen_width, screen_height, 1])

    # Lighting Pass
    if False: 
        # Coherent
        shader_object = pass_encoder.bind_pipeline(lightingPassKernel.pipeline)
        cursor = spy.ShaderCursor(shader_object)

        cursor.gScreenSize = spy.uint2(screen_width, screen_height)

        cursor.gPositionTexture = posTex
        cursor.gNormalTexture = normalTex
        cursor.gDiffuseTexture = diffuseTex
        cursor.gSpecularTexture = specularTex
        cursor.gOutputTexture = resultTex
        
        pass_encoder.dispatch([screen_width, screen_height, 1])
    else: 
        # Adaptive
        shader_object = pass_encoder.bind_pipeline(adaptiveLightingPassKernel.pipeline)
        cursor = spy.ShaderCursor(shader_object)

        cursor.gScreenSize = spy.uint2(screen_width, screen_height)
        cursor.gTotalPixelNum = screen_width * screen_height
        cursor.gPositionTexture = posTex
        cursor.gNormalTexture = normalTex
        cursor.gDiffuseTexture = diffuseTex
        cursor.gSpecularTexture = specularTex
        cursor.gOutputTexture = resultTex
        cursor.gLayoutScratch = layoutScratchBuffer
        
        pass_encoder.dispatch([screen_width * screen_height, 1, 1])
    
device.submit_command_buffer(command_encoder.finish())
device.wait_for_idle()

imageio.imwrite("Result.png", resultTex.to_numpy())
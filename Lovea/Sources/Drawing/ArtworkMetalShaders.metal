#include <metal_stdlib>
using namespace metal;

struct ArtworkVertex {
    float2 position;
    float2 texCoord;
    float4 color;
};

struct ArtworkRasterVertex {
    float4 position [[position]];
    float2 texCoord;
    float4 color;
};

vertex ArtworkRasterVertex artworkVertex(
    const device ArtworkVertex *vertices [[buffer(0)]],
    uint index [[vertex_id]]
) {
    ArtworkRasterVertex output;
    output.position = float4(vertices[index].position, 0, 1);
    output.texCoord = vertices[index].texCoord;
    output.color = vertices[index].color;
    return output;
}

fragment float4 artworkTextureFragment(
    ArtworkRasterVertex input [[stage_in]],
    texture2d<float> image [[texture(0)]],
    constant float &opacity [[buffer(0)]]
) {
    constexpr sampler imageSampler(coord::normalized, address::clamp_to_edge, filter::linear);
    return image.sample(imageSampler, input.texCoord) * opacity;
}

fragment float4 artworkStrokeFragment(
    ArtworkRasterVertex input [[stage_in]],
    constant float &hardness [[buffer(0)]]
) {
    float distance = length(input.texCoord);
    float coverage = 1.0 - smoothstep(hardness, 1.0, distance);
    return float4(input.color.rgb, input.color.a * coverage);
}

struct ArtworkBlendUniforms {
    int mode;
    float opacity;
};

float3 artworkBlendColor(float3 backdrop, float3 source, int mode) {
    if (mode == 1) return backdrop * source;
    if (mode == 2) return backdrop + source - backdrop * source;
    if (mode == 3) return select(2.0 * backdrop * source, 1.0 - 2.0 * (1.0 - backdrop) * (1.0 - source), backdrop >= 0.5);
    if (mode == 4) return min(backdrop, source);
    if (mode == 5) return max(backdrop, source);
    if (mode == 6) return min(backdrop + source, 1.0);
    if (mode == 7) {
        float3 dark = backdrop - (1.0 - 2.0 * source) * backdrop * (1.0 - backdrop);
        float3 d = select(((16.0 * backdrop - 12.0) * backdrop + 4.0) * backdrop, sqrt(backdrop), backdrop > 0.25);
        float3 light = backdrop + (2.0 * source - 1.0) * (d - backdrop);
        return select(dark, light, source >= 0.5);
    }
    return source;
}

fragment float4 artworkBlendFragment(
    ArtworkRasterVertex input [[stage_in]],
    texture2d<float> lower [[texture(0)]],
    texture2d<float> active [[texture(1)]],
    constant ArtworkBlendUniforms &uniforms [[buffer(0)]]
) {
    constexpr sampler imageSampler(coord::normalized, address::clamp_to_edge, filter::linear);
    float4 backdrop = lower.sample(imageSampler, input.texCoord);
    float4 source = active.sample(imageSampler, input.texCoord) * uniforms.opacity;
    float3 cb = backdrop.a > 0.0 ? backdrop.rgb / backdrop.a : float3(0.0);
    float3 cs = source.a > 0.0 ? source.rgb / source.a : float3(0.0);
    float3 blend = artworkBlendColor(cb, cs, uniforms.mode);
    float3 result = (1.0 - source.a) * backdrop.rgb
                  + (1.0 - backdrop.a) * source.rgb
                  + backdrop.a * source.a * blend;
    float alpha = source.a + backdrop.a * (1.0 - source.a);
    return float4(result, alpha);
}

#include <metal_stdlib>
using namespace metal;

struct CanvasVertex {
    float2 position;
    float4 color;
};

struct RasterVertex {
    float4 position [[position]];
    float4 color;
};

vertex RasterVertex canvasVertex(
    const device CanvasVertex *vertices [[buffer(0)]],
    uint id [[vertex_id]]
) {
    RasterVertex output;
    output.position = float4(vertices[id].position, 0, 1);
    output.color = vertices[id].color;
    return output;
}

fragment float4 canvasFragment(RasterVertex input [[stage_in]]) {
    return input.color;
}

struct CompositeVertex {
    float4 position [[position]];
};

vertex CompositeVertex compositeVertex(uint id [[vertex_id]]) {
    constexpr float2 positions[] = {
        float2(-1, -1),
        float2(3, -1),
        float2(-1, 3)
    };
    CompositeVertex output;
    output.position = float4(positions[id], 0, 1);
    return output;
}

fragment float4 compositeFragment(
    CompositeVertex input [[stage_in]],
    texture2d<float, access::read> layer [[texture(0)]],
    constant float &opacity [[buffer(0)]]
) {
    return layer.read(uint2(input.position.xy)) * opacity;
}

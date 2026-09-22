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

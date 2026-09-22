#include <metal_stdlib>
using namespace metal;

// All colors are premultiplied alpha. Document pixels: origin top-left, y down.

struct QuadOut {
    float4 position [[position]];
    float2 uv;
};

// Four corners in NDC, triangle strip order: top-left, top-right, bottom-left, bottom-right.
vertex QuadOut quadVertex(uint vid [[vertex_id]], constant float2 *corners [[buffer(0)]]) {
    QuadOut out;
    out.position = float4(corners[vid], 0, 1);
    out.uv = float2(float(vid & 1), float(vid >> 1));
    return out;
}

fragment float4 copyFragment(
    QuadOut in [[stage_in]],
    texture2d<float> source [[texture(0)]],
    sampler smp [[sampler(0)]],
    constant float &opacity [[buffer(0)]]
) {
    return source.sample(smp, in.uv) * opacity;
}

fragment float4 maskedCopyFragment(
    QuadOut in [[stage_in]],
    texture2d<float> source [[texture(0)]],
    texture2d<float> mask [[texture(1)]],
    sampler smp [[sampler(0)]],
    constant int &invert [[buffer(0)]]
) {
    float m = mask.sample(smp, in.uv).r;
    return source.sample(smp, in.uv) * (invert != 0 ? 1.0 - m : m);
}

fragment float4 maskColorFragment(
    QuadOut in [[stage_in]],
    texture2d<float> mask [[texture(0)]],
    texture2d<float> selection [[texture(1)]],
    sampler smp [[sampler(0)]],
    constant float4 &color [[buffer(0)]]
) {
    float a = mask.sample(smp, in.uv).r * selection.sample(smp, in.uv).r * color.a;
    return float4(color.rgb * a, a);
}

fragment float4 invertMaskFragment(QuadOut in [[stage_in]], texture2d<float> mask [[texture(0)]], sampler smp [[sampler(0)]]) {
    return float4(1.0 - mask.sample(smp, in.uv).r);
}

fragment float4 checkerFragment(QuadOut in [[stage_in]], constant float2 &docSize [[buffer(0)]]) {
    float2 cell = floor(in.uv * docSize / 8.0);
    float v = fmod(cell.x + cell.y, 2.0) < 1.0 ? 1.0 : 0.82;
    return float4(v, v, v, 1);
}

float3 blendColor(float3 b, float3 s, int mode) {
    if (mode == 1) return b * s;
    if (mode == 2) return b + s - b * s;
    if (mode == 3) return select(2.0 * b * s, 1.0 - 2.0 * (1.0 - b) * (1.0 - s), b >= 0.5);
    if (mode == 4) return min(b, s);
    if (mode == 5) return max(b, s);
    if (mode == 6) return min(b + s, 1.0);
    if (mode == 7) {
        float3 dark = b - (1.0 - 2.0 * s) * b * (1.0 - b);
        float3 d = select(((16.0 * b - 12.0) * b + 4.0) * b, sqrt(b), b > 0.25);
        float3 light = b + (2.0 * s - 1.0) * (d - b);
        return select(dark, light, s >= 0.5);
    }
    return s;
}

struct BlendUniforms {
    int mode;
    float opacity;
    int useMask;
};

// W3C compositing: source over backdrop with a separable blend mode. Same-size textures, read by pixel.
fragment float4 blendFragment(
    QuadOut in [[stage_in]],
    texture2d<float> backdrop [[texture(0)]],
    texture2d<float> source [[texture(1)]],
    texture2d<float> mask [[texture(2)]],
    constant BlendUniforms &u [[buffer(0)]]
) {
    uint2 p = uint2(in.position.xy);
    float4 b = backdrop.read(p);
    float4 s = source.read(p) * u.opacity;
    if (u.useMask != 0) s *= mask.read(p).a;
    float3 cb = b.a > 0.0 ? b.rgb / b.a : float3(0.0);
    float3 cs = s.a > 0.0 ? s.rgb / s.a : float3(0.0);
    float3 mixed = blendColor(cb, cs, u.mode);
    float3 rgb = (1.0 - s.a) * b.rgb + (1.0 - b.a) * s.rgb + b.a * s.a * mixed;
    return float4(rgb, s.a + b.a * (1.0 - s.a));
}

struct AdjustUniforms {
    int mode;      // 1 grayscale, 2 invert, 3 brightness, 4 saturation, 5 hue
    float amount;
};

float3 rgbToHsv(float3 c) {
    float4 k = float4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    float4 p = mix(float4(c.bg, k.wz), float4(c.gb, k.xy), step(c.b, c.g));
    float4 q = mix(float4(p.xyw, c.r), float4(c.r, p.yzx), step(p.x, c.r));
    float d = q.x - min(q.w, q.y);
    float e = 1.0e-10;
    return float3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

float3 hsvToRgb(float3 c) {
    float3 p = abs(fract(c.xxx + float3(1.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
    return c.z * mix(float3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}

fragment float4 adjustFragment(
    QuadOut in [[stage_in]],
    texture2d<float> source [[texture(0)]],
    texture2d<float> selection [[texture(1)]],
    sampler smp [[sampler(0)]],
    constant AdjustUniforms &u [[buffer(0)]]
) {
    float4 px = source.sample(smp, in.uv);
    if (px.a <= 0.0) return px;
    float3 c = px.rgb / px.a;
    float3 r = c;
    if (u.mode == 1) r = float3(dot(c, float3(0.2126, 0.7152, 0.0722)));
    if (u.mode == 2) r = 1.0 - c;
    if (u.mode == 3) r = clamp(c + u.amount, 0.0, 1.0);
    if (u.mode == 4) { float3 g = float3(dot(c, float3(0.2126, 0.7152, 0.0722))); r = clamp(mix(g, c, 1.0 + u.amount), 0.0, 1.0); }
    if (u.mode == 5) { float3 h = rgbToHsv(c); h.x = fract(h.x + u.amount); r = hsvToRgb(h); }
    float m = selection.sample(smp, in.uv).r;
    return float4(mix(c, r, m) * px.a, px.a);
}

struct StampGPU {
    float2 center;
    float radius;
    float opacity;
    float angle;
    float aspect;
};

struct StampUniforms {
    float2 docSize;
    float4 color;
    float hardness;
    float grain;
    int pixel;
    int useMask;
};

struct StampOut {
    float4 position [[position]];
    float2 local;
    float2 doc;
    float opacity;
};

vertex StampOut stampVertex(
    uint vid [[vertex_id]],
    uint iid [[instance_id]],
    const device StampGPU *stamps [[buffer(0)]],
    constant StampUniforms &u [[buffer(1)]]
) {
    StampGPU s = stamps[iid];
    float2 local = float2(float(vid & 1) * 2.0 - 1.0, float(vid >> 1) * 2.0 - 1.0);
    float2 offset = local * float2(s.radius, s.radius * s.aspect);
    float c = cos(s.angle);
    float n = sin(s.angle);
    float2 doc = s.center + float2(offset.x * c - offset.y * n, offset.x * n + offset.y * c);
    StampOut out;
    out.position = float4(doc.x / u.docSize.x * 2.0 - 1.0, 1.0 - doc.y / u.docSize.y * 2.0, 0, 1);
    out.local = local;
    out.doc = doc;
    out.opacity = s.opacity;
    return out;
}

fragment float4 stampFragment(
    StampOut in [[stage_in]],
    constant StampUniforms &u [[buffer(1)]],
    texture2d<float> mask [[texture(0)]]
) {
    float a = in.opacity;
    if (u.pixel == 0) {
        float d = length(in.local);
        float fw = max(fwidth(d), 1.0e-4);
        float inner = min(u.hardness, 1.0 - fw);
        a *= 1.0 - smoothstep(inner, 1.0, d);
        if (u.grain > 0.0) {
            float noise = fract(sin(dot(floor(in.doc), float2(12.9898, 78.233))) * 43758.5453);
            a *= mix(1.0, noise, u.grain);
        }
    }
    if (u.useMask != 0) {
        constexpr sampler smp(coord::normalized, address::clamp_to_edge, filter::linear);
        a *= mask.sample(smp, in.doc / u.docSize).r;
    }
    return float4(u.color.rgb * a, a);
}

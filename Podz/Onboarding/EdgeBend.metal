#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

/// Bulges a layer toward the viewer around its edges, and fringes the color
/// channels only right at the rim. Nothing changes at the center.
///
/// - bend: how much the rim is magnified (grows with the squared distance
///   from the center, so the content seems to curve out of the screen).
/// - aberration: red (+) / blue (-) radial offset around green, applied only
///   in the last stretch before the screen edge.
[[ stitchable ]] half4 edgeBend(
    float2 position,
    SwiftUI::Layer layer,
    float2 size,
    float bend,
    float aberration
) {
    float2 center = size * 0.5;
    float2 d = (position - center) / center;
    float r2 = dot(d, d) * 0.5;

    // Sampling closer to the center than the pixel's own position magnifies.
    float scale = 1.0 - bend * r2;

    // 0 until 80% of the way to an edge, easing up to 1 at the edge itself.
    float edge = smoothstep(0.8, 1.0, max(abs(d.x), abs(d.y)));
    float shift = aberration * edge;
    float2 limit = size - 1.0;

    half4 red = layer.sample(clamp(center + d * (scale + shift) * center, 0.0, limit));
    half4 green = layer.sample(clamp(center + d * scale * center, 0.0, limit));
    half4 blue = layer.sample(clamp(center + d * (scale - shift) * center, 0.0, limit));

    return half4(red.r, green.g, blue.b, green.a);
}

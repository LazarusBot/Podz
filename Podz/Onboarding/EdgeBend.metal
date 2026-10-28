#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

/// Bends a layer around its edges like a convex lens and splits the color
/// channels apart toward the rim. Nothing changes at the center; both effects
/// grow with the squared distance from it.
///
/// - bend: how far the rim samples outward (content squeezes toward the edges).
/// - aberration: extra radial offset for red (+) and blue (-) around green.
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

    float scale = 1.0 + bend * r2;
    float shift = aberration * r2;
    float2 limit = size - 1.0;

    half4 red = layer.sample(clamp(center + d * (scale + shift) * center, 0.0, limit));
    half4 green = layer.sample(clamp(center + d * scale * center, 0.0, limit));
    half4 blue = layer.sample(clamp(center + d * (scale - shift) * center, 0.0, limit));

    return half4(red.r, green.g, blue.b, green.a);
}

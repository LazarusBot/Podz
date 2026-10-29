#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

/// Bulges a layer toward the viewer along its edges. The inner part of the
/// layer stays flat: the bend begins `start` of the way out to each edge and
/// eases in from zero slope, so there is no visible crease where it starts.
///
/// - bend: how far, in half-size units, the content at an edge is pulled in
///   (keep it below (1 - start) / 2 or the mapping folds over itself).
/// - start: 0...1, how far from the center the bend begins.
[[ stitchable ]] half4 edgeBend(
    float2 position,
    SwiftUI::Layer layer,
    float2 size,
    float bend,
    float start
) {
    float2 center = size * 0.5;
    float2 d = (position - center) / center;

    // Per axis: 0 until `start`, then 0...1 toward that edge.
    float2 t = max(abs(d) - start, 0.0) / (1.0 - start);
    float2 bent = d - sign(d) * bend * t * t;

    return layer.sample(clamp(center + bent * center, 0.0, size - 1.0));
}

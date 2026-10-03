#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

static float peelHash(float2 cell) {
    return fract(sin(dot(cell, float2(127.1, 311.7))) * 43758.5453);
}

[[ stitchable ]]
half4 cardPeel(float2 position, SwiftUI::Layer layer, float progress, float direction, float width) {
    if (progress <= 0.0) {
        return layer.sample(position);
    }
    if (progress >= 1.0) {
        return half4(0.0);
    }

    constexpr float cellSize = 9.0;
    float2 destinationCell = floor(position / cellSize);
    half4 result = half4(0.0);

    // Each source cell has its own release point. Check adjacent cells so a
    // shifted fragment can occupy a different cell without losing its image.
    for (int y = -1; y <= 1; ++y) {
        for (int x = -1; x <= 1; ++x) {
            float2 sourceCell = destinationCell + float2(x, y);
            float random = peelHash(sourceCell);
            float sourceX = (sourceCell.x + 0.5) * cellSize;
            float sweep = direction > 0.0 ? sourceX / width : 1.0 - sourceX / width;
            float release = 0.03 + 0.76 * clamp(sweep, 0.0, 1.0) + (random - 0.5) * 0.06;
            float age = clamp((progress - release) / 0.18, 0.0, 1.0);

            float vertical = peelHash(sourceCell + float2(17.0, 43.0)) - 0.5;
            float2 drift = float2(direction * 7.2, vertical * 12.0) * age;
            float2 local = (position - sourceCell * cellSize - drift) / cellSize;
            if (any(local < 0.0) || any(local >= 1.0)) {
                continue;
            }

            float coverage = 1.0;
            if (age > 0.0) {
                float radius = 0.5 - 0.27 * age;
                float edge = max(abs(local.x - 0.5), abs(local.y - 0.5));
                coverage = 1.0 - smoothstep(radius - 0.07, radius, edge);
            }
            float fade = 1.0 - smoothstep(0.25, 1.0, age);
            half4 sampledFragment = layer.sample(position - drift) * half(coverage * fade);
            result = sampledFragment + result * (half(1.0) - sampledFragment.a);
        }
    }

    return result;
}

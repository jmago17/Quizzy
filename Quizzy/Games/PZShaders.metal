// Shaders de SwiftUI (`ShaderLibrary`) para la celebración al ganar (2026-11-16).
//  · pzShine: brillo metálico que barre en diagonal sobre lo que se dibuja (insignia del resultado).
//  · pzShockwave: onda expansiva que deforma la hoja desde el centro de la insignia.
#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

/// Banda de luz diagonal que cruza cada `period` s, con un leve tornasol. Solo toca píxeles opacos.
[[ stitchable ]] half4 pzShine(float2 position, half4 color, float2 size, float time, float period) {
    if (color.a < 0.01h) { return color; }
    float2 uv = position / max(size, float2(1.0));
    float t = fract(time / period) * 2.6 - 0.8;          // la banda entra y sale del todo
    float d = (uv.x + uv.y * 0.6) - t;
    float band = exp(-d * d * 60.0);                       // núcleo estrecho
    float halo = exp(-d * d * 8.0) * 0.25;                 // resplandor ancho
    float3 tint = 0.5 + 0.5 * cos(6.2831 * (uv.x + float3(0.0, 0.33, 0.67)) + time); // tornasol suave
    float3 rgb = float3(color.rgb) + (band + halo) * mix(float3(1.0), tint, 0.25) * float(color.a);
    return half4(half3(min(rgb, float3(1.0))), color.a);
}

/// Onda expansiva: un anillo que crece desde `center` y desplaza los píxeles hacia fuera mientras pasa.
[[ stitchable ]] half4 pzShockwave(float2 position, SwiftUI::Layer layer, float2 center,
                                   float time, float speed, float amplitude) {
    float2 delta = position - center;
    float dist = length(delta);
    float radius = time * speed;
    float x = dist - radius;
    float ring = exp(-x * x / 900.0);                      // anillo de ~30 pt de ancho
    float fade = clamp(1.0 - time / 1.1, 0.0, 1.0);
    float2 dir = dist > 0.001 ? delta / dist : float2(0.0);
    float2 offset = dir * ring * amplitude * fade * sin(x * 0.12);
    half4 c = layer.sample(position - offset);
    c.rgb += half3(ring * fade * 0.10h) * c.a;              // un poco de luz en el frente de la onda
    return c;
}

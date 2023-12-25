//
//  grid.metal
//  Loop
//
//  Created by Kai Azim on 2023-11-30.
//

#include <metal_stdlib>
using namespace metal;

[[stitchable]] half4 grid(float2 position, half4 currentColor, float size, half4 newColor) {
    position += 1;

    // Calculate the position of the current pixel in grid coordinates.
    uint2 gridPosition = uint2(position / size);

    // Introduce a factor to control the thickness of the grid lines
    float thicknessFactor = 0.1;

    // Check if the pixel is close to the grid lines
    bool isGridLine = ((position.x / size - float(gridPosition.x)) < thicknessFactor) ||
                      ((position.y / size - float(gridPosition.y)) < thicknessFactor);

    return isGridLine ? newColor * currentColor.a : half4(0.0, 0.0, 0.0, 0.0);
}

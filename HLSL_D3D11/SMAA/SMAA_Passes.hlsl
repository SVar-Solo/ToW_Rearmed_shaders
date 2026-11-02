// D3D11 entry points for SMAA. Replaces the legacy SMAA.fx techniques.
// Compile each entry separately with the matching vs_5_0 / ps_5_0 profile.
#include "SMAA.hlsl"

Texture2D colorTex  : register(t0);
Texture2D depthTex  : register(t1);
Texture2D edgesTex  : register(t2);
Texture2D blendTex  : register(t3);
Texture2D areaTex   : register(t4);
Texture2D searchTex : register(t5);
// LinearSampler (s0) and PointSampler (s1) are declared in SMAA.hlsl.

struct SMAA_VSIn
{
    float4 position : POSITION;
    float2 texcoord : TEXCOORD0;
};

struct SMAA_EdgeVSOut
{
    float4 position : SV_Position;
    float2 texcoord : TEXCOORD0;
    float4 offset[3] : TEXCOORD1;
};

struct SMAA_BlendVSOut
{
    float4 position : SV_Position;
    float2 texcoord : TEXCOORD0;
    float2 pixcoord : TEXCOORD1;
    float4 offset[3] : TEXCOORD2;
};

struct SMAA_NeighborVSOut
{
    float4 position : SV_Position;
    float2 texcoord : TEXCOORD0;
    float4 offset : TEXCOORD1;
};

void SMAAEdgeDetectionVS_Main(in SMAA_VSIn input, out SMAA_EdgeVSOut output)
{
    output.position = input.position;
    output.texcoord = input.texcoord;
    SMAAEdgeDetectionVS(input.texcoord, output.offset);
}

void SMAABlendingWeightCalculationVS_Main(in SMAA_VSIn input, out SMAA_BlendVSOut output)
{
    output.position = input.position;
    output.texcoord = input.texcoord;
    SMAABlendingWeightCalculationVS(input.texcoord, output.pixcoord, output.offset);
}

void SMAANeighborhoodBlendingVS_Main(in SMAA_VSIn input, out SMAA_NeighborVSOut output)
{
    output.position = input.position;
    output.texcoord = input.texcoord;
    SMAANeighborhoodBlendingVS(input.texcoord, output.offset);
}

float4 SMAALumaEdgeDetectionPS_Main(SMAA_EdgeVSOut input) : SV_Target0
{
    return float4(SMAALumaEdgeDetectionPS(input.texcoord, input.offset, colorTex), 0.0, 0.0);
}

float4 SMAAColorEdgeDetectionPS_Main(SMAA_EdgeVSOut input) : SV_Target0
{
    return float4(SMAAColorEdgeDetectionPS(input.texcoord, input.offset, colorTex), 0.0, 0.0);
}

float4 SMAADepthEdgeDetectionPS_Main(SMAA_EdgeVSOut input) : SV_Target0
{
    return float4(SMAADepthEdgeDetectionPS(input.texcoord, input.offset, depthTex), 0.0, 0.0);
}

float4 SMAABlendingWeightCalculationPS_Main(SMAA_BlendVSOut input) : SV_Target0
{
    return SMAABlendingWeightCalculationPS(input.texcoord, input.pixcoord, input.offset,
                                           edgesTex, areaTex, searchTex, float4(0.0, 0.0, 0.0, 0.0));
}

float4 SMAANeighborhoodBlendingPS_Main(SMAA_NeighborVSOut input) : SV_Target0
{
    return SMAANeighborhoodBlendingPS(input.texcoord, input.offset, colorTex, blendTex);
}

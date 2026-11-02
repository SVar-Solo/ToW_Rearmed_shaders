// D3D11 port of HDRClearPS.hlsl. Generated from the legacy HLSL source; see README.md.
struct VertexOUT {
    float2 TEX0 : TEXCOORD0;
};

cbuffer HDRClearPS_CB0 : register(b0)
{
float4 color;

 // main procedure, the original name was main
};
float4 main() : SV_Target0
{
    return color;
} // main end

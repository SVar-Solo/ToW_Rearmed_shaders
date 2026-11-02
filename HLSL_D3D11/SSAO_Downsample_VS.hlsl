// D3D11 port of SSAO_Downsample_VS.hlsl. Generated from the legacy HLSL source; see README.md.
struct VertexIN {
    float4 position : POSITION;
    float3 texcoord : TEXCOORD0;
};

struct VertexOUT {
    float2 TEX0 : TEXCOORD0;
    float2 TEX1 : TEXCOORD1;
    float4 HPOS : SV_Position;
};

cbuffer SSAO_Downsample_VS_CB0 : register(b0)
{
float2 pixelSize;

 // main procedure, the original name was main
};
VertexOUT main(in VertexIN IN)
{
    VertexOUT OUT;

    OUT.HPOS = IN.position;
    OUT.TEX0 = IN.texcoord.xy;// +  0.5f*pixelSize;
    OUT.TEX1 = pixelSize;
    return OUT;
} // main end

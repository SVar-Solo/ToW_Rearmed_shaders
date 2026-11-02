// D3D11 port of SSAO_VS.hlsl. Generated from the legacy HLSL source; see README.md.
struct VertexIN {
    float4 position : POSITION;
    float2 texcoord : TEXCOORD0;
};

struct VertexOUT {
    float2 TEX0 : TEXCOORD0;
    float4 HPOS : SV_Position;
};

cbuffer SSAO_VS_CB0 : register(b0)
{
float2 pixelSize;
column_major float4x4 Proj;

 // main procedure, the original name was main
};
VertexOUT main(in VertexIN IN)
{
    VertexOUT OUT;

    OUT.HPOS = IN.position;
    OUT.TEX0 = IN.texcoord.xy;// + 0.5f*pixelSize;
    //OUT.TEX0 = 0.5*(IN.position)+0.5;// +  0.5f*float2(4.f/1280.f, 4.f/800.f);
    return OUT;
} // main end

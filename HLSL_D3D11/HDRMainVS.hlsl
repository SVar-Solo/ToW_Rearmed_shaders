// D3D11 port of HDRMainVS.hlsl. Generated from the legacy HLSL source; see README.md.
struct VertexIN {
    float4 position : POSITION;
    float2 texcoord : TEXCOORD0;
};

struct VertexOUT {
    float4 HPOS : SV_Position;
    float2 TEX0 : TEXCOORD0;
    float2 TEX1 : TEXCOORD1;
};

cbuffer HDRMainVS_CB0 : register(b0)
{
float2 pixelSize;

 // main procedure, the original name was main
};
VertexOUT main(in VertexIN IN)
{

    VertexOUT OUT;

    OUT.HPOS = IN.position;
    OUT.TEX0 = IN.texcoord.xy +  0.5f*pixelSize;
    OUT.TEX1 = IN.texcoord.xy + ( 0.5f*pixelSize)/8.f;
    return OUT;
} // main end

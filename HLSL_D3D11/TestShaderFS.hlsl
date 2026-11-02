// D3D11 port of TestShaderFS.hlsl. Generated from the legacy HLSL source; see README.md.
struct vfconn {
    float4 COL0 : COLOR0;
    float2 TEX0 : TEXCOORD0;
};

Texture2D TexMap : register(t0);
SamplerState TexMap_Sampler : register(s0);

 // main procedure, the original name was main
float4 main(in vfconn IN) : SV_Target0
{

    float4 decalColor;

    decalColor = TexMap.Sample(TexMap_Sampler, IN.TEX0.xy);
    return decalColor*IN.COL0;
} // main end

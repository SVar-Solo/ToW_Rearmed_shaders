// D3D11 port of TestShaderVS.hlsl. Generated from the legacy HLSL source; see README.md.
struct appdata {
    float4 position : POSITION;
    float4 Color0 : COLOR0;
    float4 Color1 : COLOR1;
    float2 Tex0 : TEXCOORD0;
};

struct vfconn {
    float4 HPOS : SV_Position;
    float4 COL0 : COLOR0;
    float2 TEX0 : TEXCOORD0;
};

cbuffer TestShaderVS_CB0 : register(b0)
{
column_major float4x4 ModelViewProj;
column_major float4x4 halTextureMatrix0;
//uniform float2 gRTSize;

 // main procedure, the original name was main
};
vfconn main(in appdata IN)
{
	vfconn OUT;

	OUT.HPOS = mul(ModelViewProj, float4(IN.position.xyz, 1.0));
	OUT.COL0 = IN.Color0;
	OUT.TEX0 = IN.Tex0;//+float2(0.5f/gRTSize.x, 0.5f/gRTSize.y);//mul( halTextureMatrix0, IN.Tex0);
    OUT.COL0 = saturate(OUT.COL0); // D3D9 COLOR interpolator clamp
	return OUT;
} // main end

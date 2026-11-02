// D3D11 port of EffectShaderVS.hlsl. Generated from the legacy HLSL source; see README.md.
struct appdata
{
    float4 position : POSITION;
	float4 Color0 : COLOR0;
	float4 Color1 : COLOR1;
	float4 Tex0 : TEXCOORD0;
};

struct vfconn
{
    float4 COL0 : COLOR0;
    float4 TEX0 : TEXCOORD0;
    float4 HPOS : SV_Position;
};

cbuffer EffectShaderVS_CB0 : register(b0)
{
column_major float4x4 ModelViewProj;
column_major float4x4 halTextureMatrix0;

};
vfconn main(in appdata IN
			)
{
    vfconn OUT;

	OUT.HPOS = mul(ModelViewProj, float4(IN.position.xyz, 1.0));

	OUT.COL0 = IN.Color0;//;float4(1.0, 0.0, 1.0, 1.0);
	OUT.TEX0 = mul( halTextureMatrix0, IN.Tex0);
    OUT.COL0 = saturate(OUT.COL0); // D3D9 COLOR interpolator clamp
    return OUT;
} 

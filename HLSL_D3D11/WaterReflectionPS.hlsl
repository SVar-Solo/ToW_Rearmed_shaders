// D3D11 port of WaterReflectionPS.hlsl. Generated from the legacy HLSL source; see README.md.
//#define OLD_SHADERS

struct VertexOut
{
	float4 Color0		: COLOR0;
	float4 texcoord0	: TEXCOORD0;  //dsdt texture coord.
	float4 texcoord1	: TEXCOORD1;  //reflection texture coord.
};

cbuffer WaterReflectionPS_CB0 : register(b0)
{
float4 MatOffset;
};
Texture2D Tex0 : register(t0);
SamplerState Tex0_Sampler : register(s0);
Texture2D Tex1 : register(t1);
SamplerState Tex1_Sampler : register(s1);

float4 main( in VertexOut IN	):SV_Target0
{

	float4 DSDT = Tex0.Sample(Tex0_Sampler, IN.texcoord0.xy);

	float2 reflCoord = IN.texcoord1.xy;
	//float2 newst = reflCoord + MatOffset.xy * DSDT.xx + MatOffset.zw * DSDT.yy;
	float2 newst = float2(reflCoord.x + MatOffset.x * DSDT.x + MatOffset.z * DSDT.y, reflCoord.y + MatOffset.y * DSDT.x + MatOffset.w * DSDT.y);
	float4 Reflection = Tex1.Sample(Tex1_Sampler, newst);
	
	return float4(Reflection.rgb, IN.Color0.b);//clamp(IN.Color0.b*2,0,0.5));
}
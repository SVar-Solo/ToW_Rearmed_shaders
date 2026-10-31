//#define OLD_SHADERS

struct VertexOut
{
	float4 Color0		: COLOR0;
	float4 texcoord0	: TEXCOORD0;  //dsdt texture coord.
	float4 texcoord1	: TEXCOORD1;  //reflection texture coord.
};

uniform float4 MatOffset;
uniform sampler2D Tex0: register(s0);
uniform sampler2D Tex1: register(s1);

float4 main( in VertexOut IN	):COLOR
{

	float4 DSDT = tex2D(Tex0, IN.texcoord0.xy);

	float2 reflCoord = IN.texcoord1.xy;
	//float2 newst = reflCoord + MatOffset.xy * DSDT.xx + MatOffset.zw * DSDT.yy;
	float2 newst = float2(reflCoord.x + MatOffset.x * DSDT.x + MatOffset.z * DSDT.y, reflCoord.y + MatOffset.y * DSDT.x + MatOffset.w * DSDT.y);
	float4 Reflection = tex2D(Tex1, newst);
	
	return float4(Reflection.rgb, IN.Color0.b);//clamp(IN.Color0.b*2,0,0.5));
}
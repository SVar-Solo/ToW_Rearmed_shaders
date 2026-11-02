// D3D11 port of ShadowGrassFP.hlsl. Generated from the legacy HLSL source; see README.md.
//****************************************************
//	Fragment shader for support Shadow map in Grass 
//****************************************************

struct VertexOut
{
//    float4 HPOS : SV_Position;
	float4 COL0		: COLOR0;
	float4 COL1		: COLOR1;
    float2 TEX0		: TEXCOORD0;   // Vertical Grass
    float2 TEX1		: TEXCOORD1;   // Land
    float4 ScreenPos : TEXCOORD2;   // screen coord
};


Texture2D GBufferTex : register(t2);
SamplerState GBufferTex_Sampler : register(s2);
cbuffer ShadowGrassFP_CB0 : register(b0)
{
float4 Ka; //Ambient color
float4 Kd; //Diffuse color
};
Texture2D VGrassTex : register(t0);
SamplerState VGrassTex_Sampler : register(s0);
Texture2D LandTex : register(t1);
SamplerState LandTex_Sampler : register(s1);
cbuffer ShadowGrassFP_CB1 : register(b1)
{
float2 gRTSize;

//-----------------------------------------------------------------------------
//	main
//-----------------------------------------------------------------------------

};
float4 main(VertexOut IN) :	SV_Target0
{

	float4 color;
	float4 diffuse_light;
	
	// diffuse color
	float4 tex0	= VGrassTex.Sample(VGrassTex_Sampler, IN.TEX0.xy);
	float4 ColorStage0 = tex0 *	IN.COL0;
	float4 tex1	= LandTex.Sample(LandTex_Sampler, IN.TEX1.xy);  //0.5
	color.rgb =	tex1.rgb * ColorStage0.rgb * 2.0f;	 //*2.0	- ???
	color.a	= ColorStage0.a;  //1.0;
	diffuse_light.rgb =	tex1.a * (Kd.rgb+Ka.rgb);	

	// read	GBuffer
	float2 screen_uv = IN.ScreenPos.xy/IN.ScreenPos.w;
	screen_uv.x	= 0.5f * (1.0f + screen_uv.x) + 0.5f/gRTSize.x;
	screen_uv.y	= 0.5f * (1.0f - screen_uv.y) + 0.5f/gRTSize.y;
	float4 gbuffer = GBufferTex.Sample(GBufferTex_Sampler, screen_uv.xy);

	// shadows
	float shadow_factor	= gbuffer.r;	  
	diffuse_light.rgb =	shadow_factor *	diffuse_light.rgb;

	color.rgb =	clamp(Ka.rgb + diffuse_light.rgb, 0.0, 1.0)	* color.rgb;

	return color;
}


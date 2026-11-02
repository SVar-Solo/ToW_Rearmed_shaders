// D3D11 port of GrassMainPassPS.hlsl. Generated from the legacy HLSL source; see README.md.
//****************************************************
//	Fragment shader for support Shadow map in Grass 
//****************************************************

struct VertexOut
{
	float4 COL0		 : COLOR0;
	float4 COL1		 : COLOR1;
    float2 TEX0		 : TEXCOORD0;   // Vertical Grass
    float2 TEX1		 : TEXCOORD1;   // Land
    float4 ScreenPos : TEXCOORD2;   // screen coord
	float4 coordw	 : TEXCOORD3;
};

//-----------------------------------------------------------------------------
//	shader params
//-----------------------------------------------------------------------------

cbuffer GrassMainPassPS_CB0 : register(b0)
{
float3 g_vLightDiffuse;   // light's diffuse color
float3 g_vLightAmbient;   // light's ambient color
float3 g_vLightScale;     // mirrors the diffuse scalar value in CAD, used to help combat the darkening effect of multiple texture layers
float3 LightDir;

};
Texture2D GBufferTex : register(t2);
SamplerState GBufferTex_Sampler : register(s2);
Texture2D VGrassTex : register(t0);
SamplerState VGrassTex_Sampler : register(s0);
Texture2D LandTex : register(t1);
SamplerState LandTex_Sampler : register(s1);
cbuffer GrassMainPassPS_CB1 : register(b1)
{
float2 gRTSize;

};
Texture2D MegaNormalMap : register(t4);
SamplerState MegaNormalMap_Sampler : register(s4);


//-----------------------------------------------------------------------------
//	main
//-----------------------------------------------------------------------------

float4 main(VertexOut IN) :	SV_Target0
{
	// grass color
	float4 color = 1.0f;
	
	// normal map
	float4 MegaNormalColor = MegaNormalMap.Sample(MegaNormalMap_Sampler, float2(IN.coordw.x/2048, 1-IN.coordw.y/2048));
	float3 MegaNormal = 2.0f * float3(MegaNormalColor.a, 1.0f - MegaNormalColor.g, 0.0f) - 1.0f;
	float sx = MegaNormal.x;
	float sy = MegaNormal.y;
	float sz = saturate(sqrt(1.0f - (sx * sx + sy * sy)));
	MegaNormal = normalize(float3(sx, sy, sz));
	
	// diffuse color
	float4 tex0	= VGrassTex.Sample(VGrassTex_Sampler, IN.TEX0.xy);
	float4 land_tex	= LandTex.Sample(LandTex_Sampler, IN.TEX1.xy);
	
	// read	GBuffer
	float2 screen_uv = IN.ScreenPos.xy/IN.ScreenPos.w;
	screen_uv.x	= 0.5f * (1.0f + screen_uv.x) + 0.5f/gRTSize.x;
	screen_uv.y	= 0.5f * (1.0f - screen_uv.y) + 0.5f/gRTSize.y;
	float4 gbuffer = GBufferTex.Sample(GBufferTex_Sampler, screen_uv.xy);

	// shadows
	float ndl = saturate(dot(MegaNormal, LightDir));
	float shadow_factor	= gbuffer.r;
	ndl *= shadow_factor;
	ndl = clamp(ndl * g_vLightScale.x + g_vLightScale.y , 0, 1);
	land_tex.rgb *= lerp(g_vLightAmbient * gbuffer.g, g_vLightDiffuse * g_vLightScale.z, ndl);

	// modulation
	color.rgb = 2.4f * land_tex.rgb * tex0.rgb;
	color.a	= tex0.a;
	
	return color;
}
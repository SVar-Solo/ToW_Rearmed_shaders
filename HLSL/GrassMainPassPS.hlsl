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

uniform float3      g_vLightDiffuse;   // light's diffuse color
uniform float3      g_vLightAmbient;   // light's ambient color
uniform float3      g_vLightScale;     // mirrors the diffuse scalar value in CAD, used to help combat the darkening effect of multiple texture layers
uniform float3 		LightDir;

uniform sampler2D	GBufferTex : register(s2);
uniform sampler2D	VGrassTex : register(s0);
uniform sampler2D	LandTex : register(s1);
uniform float2		gRTSize;

uniform sampler2D 	MegaNormalMap : register(s4);


//-----------------------------------------------------------------------------
//	main
//-----------------------------------------------------------------------------

float4 main(VertexOut IN) :	COLOR
{
	// grass color
	float4 color = 1.0f;
	
	// normal map
	float4 MegaNormalColor = tex2D(MegaNormalMap, float2(IN.coordw.x/2048, 1-IN.coordw.y/2048));
	float3 MegaNormal = 2.0f * float3(MegaNormalColor.a, 1.0f - MegaNormalColor.g, 0.0f) - 1.0f;
	float sx = MegaNormal.x;
	float sy = MegaNormal.y;
	float sz = saturate(sqrt(1.0f - (sx * sx + sy * sy)));
	MegaNormal = normalize(float3(sx, sy, sz));
	
	// diffuse color
	float4 tex0	= tex2D(VGrassTex, IN.TEX0.xy);
	float4 land_tex	= tex2D(LandTex, IN.TEX1.xy);
	
	// read	GBuffer
	float2 screen_uv = IN.ScreenPos.xy/IN.ScreenPos.w;
	screen_uv.x	= 0.5f * (1.0f + screen_uv.x) + 0.5f/gRTSize.x;
	screen_uv.y	= 0.5f * (1.0f - screen_uv.y) + 0.5f/gRTSize.y;
	float4 gbuffer = tex2D(GBufferTex, screen_uv.xy);

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
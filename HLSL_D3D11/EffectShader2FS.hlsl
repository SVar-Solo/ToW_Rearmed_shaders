// D3D11 port of EffectShader2FS.hlsl. Generated from the legacy HLSL source; see README.md.
// From vertex shader

struct vfconn
{
    float4 HPOS			: SV_Position;
    float4 TEX0			: TEXCOORD0;
    float4 COL0			: TEXCOORD1;
    float4 ScreenPos	: TEXCOORD2; // screen coords
    float  CameraDepth  : TEXCOORD3; 
};

Texture2D TexMap : register(t0);
SamplerState TexMap_Sampler : register(s0); // Base texture
Texture2D DepthMap : register(t1);
SamplerState DepthMap_Sampler : register(s1); // Base texture

float4 main(in vfconn IN) : SV_Target0
{
	float4 decalColor = TexMap.Sample(TexMap_Sampler, IN.TEX0.xy);
	//float4 decalColor = float4(1, 1, 1, 1);
	
	// 
	float4 color = IN.COL0;
	
#ifdef SOFT_PARTICLES
	// read screen depth buffer
	float2 screen_uv = IN.ScreenPos.xy/IN.ScreenPos.w;
	screen_uv.x	= 0.5f * (1.0f + screen_uv.x);
	screen_uv.y	= 0.5f * (1.0f - screen_uv.y);
	
	float screen_depth = DepthMap.Sample(DepthMap_Sampler, screen_uv.xy).r;
	//float screen_depth = tex2D(DepthMap, screen_uv.xy + 0.5f*PixelSize).r;
	
	float depth_delta0 = 1.0f;
	float depth_delta = screen_depth - IN.CameraDepth;
	float fade = depth_delta/depth_delta0;
	if (fade > 0.0f)
	{
		color.a = color.a * clamp(fade, 0.0f, 1.0f);
	}
	else
	{
		color.a = 0.0f;
	}
#endif // SOFT_PARTICLES
	
	return decalColor * color;
	//return color;
	
	
	//return decalColor;
	//return float4(IN.COL0.rgb, 1);

	//return float4(IN.TEX0.xy, 0, 1);
}



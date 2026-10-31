//****************************************************
//	Fragment shader for support Shadow map in Grass 
//****************************************************

struct VertexOut
{
//    float4 HPOS : POSITION;
	float4 COL0		: COLOR0;
	float4 COL1		: COLOR1;
    float2 TEX0		: TEXCOORD0;   // Vertical Grass
    float2 TEX1		: TEXCOORD1;   // Land
    float4 ScreenPos : TEXCOORD2;   // screen coord
};


uniform sampler2D GBufferTex : register(s2);
uniform float4 Ka; //Ambient color
uniform float4 Kd; //Diffuse color
uniform sampler2D VGrassTex : register(s0);
uniform sampler2D LandTex : register(s1);
uniform float2 gRTSize;

//-----------------------------------------------------------------------------
//	main
//-----------------------------------------------------------------------------

float4 main(VertexOut IN) :	COLOR
{

	float4 color;
	float4 diffuse_light;
	
	// diffuse color
	float4 tex0	= tex2D(VGrassTex, IN.TEX0.xy);
	float4 ColorStage0 = tex0 *	IN.COL0;
	float4 tex1	= tex2D(LandTex, IN.TEX1.xy);  //0.5
	color.rgb =	tex1.rgb * ColorStage0.rgb * 2.0f;	 //*2.0	- ???
	color.a	= ColorStage0.a;  //1.0;
	diffuse_light.rgb =	tex1.a * (Kd.rgb+Ka.rgb);	

	// read	GBuffer
	float2 screen_uv = IN.ScreenPos.xy/IN.ScreenPos.w;
	screen_uv.x	= 0.5f * (1.0f + screen_uv.x) + 0.5f/gRTSize.x;
	screen_uv.y	= 0.5f * (1.0f - screen_uv.y) + 0.5f/gRTSize.y;
	float4 gbuffer = tex2D(GBufferTex, screen_uv.xy);

	// shadows
	float shadow_factor	= gbuffer.r;	  
	diffuse_light.rgb =	shadow_factor *	diffuse_light.rgb;

	color.rgb =	clamp(Ka.rgb + diffuse_light.rgb, 0.0, 1.0)	* color.rgb;

	return color;
}


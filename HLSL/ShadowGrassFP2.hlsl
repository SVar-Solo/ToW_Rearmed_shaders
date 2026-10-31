//****************************************************
//Fragment shader for support Shadow map in Horizontal Grass 
//****************************************************

//Attention: define BoundTemplate for handling bounding grass blocks
//Attention: now - without Fog

//#define FULL
//#define BoundTemplate
//#define COMPAREZ  //used for Radeon

struct VertexOut
{
    //Attention: below is output from vertex shader
//    float4 HPOS : POSITION;
	float4 COL0 : COLOR0;
    float2 TEX0 : TEXCOORD0;			//horizontal grass texture
    float2 TEX1 : TEXCOORD1;			//land texture
    float4 ScreenPos : TEXCOORD2;		//shadow map texture    

#ifdef BoundTemplate
    float2 TEX3 : TEXCOORD3;    //template mask texture for boundary grass blocks
#endif
};


uniform float4 Ka; //Ambient color
uniform float4 Kd; //Diffuse color
uniform sampler2D HGrassTex : register(s0);
uniform sampler2D LandTex : register(s1);
uniform sampler2D GBufferTex : register(s2);

#ifdef BoundTemplate
	uniform sampler2D TemplateTex : register(s3);
#endif

uniform float2 gRTSize;

float4 main(VertexOut IN) : COLOR
{
  float4 color;
  float4 diffuse_light;

//float4 Ka = float4(0.5, 0.5, 0.6, 0.0);    //???
//float4 Kd = float4(0.5, 0.5, 0.5, 0.0);    //???

  float4 tex0 = tex2D(HGrassTex, IN.TEX0.xy);
  float4 ColorStage0 = tex0 * IN.COL0;
  float4 tex1 = tex2D(LandTex, IN.TEX1.xy);
  float4 ColorStage1;
  ColorStage1.rgb = (tex1.rgb * ColorStage0.rgb) * 2.0f;  //*2.0 - ???
  ColorStage1.a = ColorStage0.a;

  color = ColorStage1;

  diffuse_light.rgb = tex1.a * Kd.rgb;   

  //template
#ifdef BoundTemplate
  float4 tex3 = tex2D(TemplateTex, IN.TEX3.xy);
  color.a *= tex3.a;
#endif

#ifdef FULL
	// read	GBuffer
	float2 screen_uv = IN.ScreenPos.xy/IN.ScreenPos.w;
	screen_uv.x	= 0.5f * (1.0f + screen_uv.x) + 0.5f/gRTSize.x;
	screen_uv.y	= 0.5f * (1.0f - screen_uv.y) + 0.5f/gRTSize.y;
	float4 gbuffer = tex2D(GBufferTex, screen_uv.xy);

	// shadows
	float shadow_factor	= gbuffer.r;	  
	diffuse_light.rgb =	shadow_factor *	diffuse_light.rgb;
#endif //FULL

#ifdef PROFILE_FP20
	color.rgb = saturate(Ka.rgb + diffuse_light.rgb) * color.rgb;
#else
	color.rgb = clamp(Ka.rgb + diffuse_light.rgb, 0.0, 1.0) * color.rgb;
#endif

  return color;
}



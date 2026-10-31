
uniform sampler2D decal  : register(s0);
uniform sampler2D BumpMap  : register(s1);
uniform sampler2D GBufferTex : register(s2);

#ifdef USE_FOG
	uniform samplerCUBE SkyMap: register(s3); // Fog texture
#endif

uniform float3 koeffNdotL;
uniform float fSkyMultiplier;
uniform float2 gRTSize;



/////////////////////////////
struct vfconn
{
	float4 FogColor : COLOR0;
	float3 Normal : COLOR1;
	float2 TexCoord0 : TEXCOORD0;
	float3 fogCoord : TEXCOORD1; // fog
	float3 LightDir : TEXCOORD2;
	float3 H : TEXCOORD3;
	float4 ScreenPos : TEXCOORD4; // shadows
};


uniform float4 AmbientColor;
#ifdef USE_SPECULAR
	uniform float4 SpecularColor;
#endif
uniform float4 DiffuseColor;
uniform float4 ColorScale;

float4 main(in vfconn IN) : COLOR
{
  float BumpAmount = DiffuseColor.a;

#ifdef USE_SPECULAR  
  float SpecularAmount = SpecularColor.a;
#endif
  
  float4 decalColor = tex2D(decal, IN.TexCoord0);
  float4 NormTex = (tex2D(BumpMap, IN.TexCoord0));

  //float3 normal = 2*(IN.Normal-0.5);
  float3 Norm = (2*(NormTex.xyz)-1.0);
  Norm = normalize(Norm);

  float3 L = normalize(IN.LightDir.xyz);
  // compute self-shadowing term
  float light = saturate(dot((Norm.rgb), L ));
  
#ifdef USE_SPECULAR
	float spec;
	if (SpecularAmount>0)
	{
		float3 E = normalize(IN.H);
		float3 R = reflect(L, Norm.rgb);
		spec = saturate(dot(R, -E));

		spec = pow(spec,SpecularAmount);//*shadow;
	}
	else
		spec = 0;
#endif

  float4 decalCS = float4(decalColor.rgb * ColorScale.rgb /** IN.Color*/, decalColor.a * ColorScale.a);
  float3 specular_color = float3(0.0f, 0.0f, 0.0f);
  
#ifdef USE_SPECULAR
	if (SpecularAmount>0)
	{
		specular_color.rgb = SpecularColor.rgb * spec * NormTex.a;
	}	
#endif

	// read GBuffer
	float2 screen_uv = IN.ScreenPos.xy/IN.ScreenPos.w;
	screen_uv.x = 0.5f * (1.0f + screen_uv.x) + 0.5f/gRTSize.x;
	screen_uv.y = 0.5f * (1.0f - screen_uv.y) + 0.5f/gRTSize.y;
	float4 gbuffer = tex2D(GBufferTex, screen_uv.xy);
	
#ifdef USE_SHADOWS
	float shadow_factor = gbuffer.r;
    light *= shadow_factor;
#endif  //USE_SHADOWS
 
  light = clamp(light*koeffNdotL.x + koeffNdotL.y, 0, 1);
  

  float3 LightValue = lerp(AmbientColor.rgb * gbuffer.g, DiffuseColor.rgb*koeffNdotL.z, light);
  LightValue = decalCS.rgb * LightValue;
  
#ifdef USE_SPECULAR
float4 resColor;
if (SpecularAmount>0)
  resColor= float4( LightValue.rgb + saturate(specular_color.rgb) , decalCS.a);
else
  resColor = float4( LightValue.rgb, decalCS.a);
#else
  float4 resColor = float4( LightValue.rgb, decalCS.a);
#endif

#ifdef USE_FOG1
  float4 fogColor = texCUBE(SkyMap, IN.fogCoord);
  fogColor.rgb = lerp(fogColor.rgb, fogColor.rgb*fSkyMultiplier, fogColor.a);
  // compute final color
  resColor.rgb = lerp(resColor.rgb, fogColor.rgb, IN.FogColor.a);
#endif
  return resColor;
}

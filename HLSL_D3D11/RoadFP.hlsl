// D3D11 port of RoadFP.hlsl. Generated from the legacy HLSL source; see README.md.
// Legacy fog variant alias: FOG1 must see the same resources/interpolators as FOG.
#if defined(FOG1) && !defined(FOG)
#define FOG
#endif
//Road pixel shader.
//This is ARB version of shader (also used as fp20 version in case of SPECULAR macros not defined)
//So on GeForce3,4 will be used truncated version without specular


struct VertexOut
{	
  float4 TexCoord0 : TEXCOORD0;  //Road texture. z,w - splinormal x, y
  float2 TexCoord1 : TEXCOORD1;  //Bump map, really duplicate TexCoord0 - need for fp20 profile only
  float4 Color : COLOR0;        //Color.r contain Land.a, Color.g contain vertex Alpha
  float4 ScreenPos : TEXCOORD2;  //Shadow map

#ifdef SPECULAR
//  float3 Color1 : COLOR1;       //Normal here for specular
  float3 tex3 : TEXCOORD3;      //contain Half vector for given vertex (need for specular)
#endif //SPECULAR

  float4 fogCoord: TEXCOORD4;
  float2 megaCoord: TEXCOORD5;
  float3 LightDir : TEXCOORD6;
};

//-----------------------------------------------------------------------------
//	getPSSMPixel3
//-----------------------------------------------------------------------------


cbuffer RoadFP_CB0 : register(b0)
{
float4 Ka; //Ambient color
float4 Kd; //Diffuse color
//uniform float3 LightDir;                           //Dir to sun
float3 koeffNdotL;
float fSkyMultiplier;

};
Texture2D RoadTex : register(t0);
SamplerState RoadTex_Sampler : register(s0);				//Road texture
Texture2D BumpMap : register(t1);
SamplerState BumpMap_Sampler : register(s1);              //Bump texture
Texture2D GBufferTex : register(t2);
SamplerState GBufferTex_Sampler : register(s2);

#ifdef SPECULAR
cbuffer RoadFP_CB1 : register(b1)
{
	float SpecularPower;                     //degree of specular - 16.0  ???????????????
	float BumpAmount;                         //influnce of bump normal to specular - 1.0  ???????????????
	float3 SunSpecularColor;
};
#endif //SPECULAR

#ifdef FOG
	TextureCube SkyMap : register(t3);
	SamplerState SkyMap_Sampler : register(s3); // Fog texture
#endif

Texture2D MegaNormalMap : register(t4);
SamplerState MegaNormalMap_Sampler : register(s4);              //Bump texture

cbuffer RoadFP_CB2 : register(b2)
{
float2 gRTSize;

};
float4 main(in VertexOut IN) : SV_Target0
{
    //read bump vector
	float4 Bump = BumpMap.Sample(BumpMap_Sampler, IN.TexCoord1);
	float3 preBump = (2.0f*Bump.rgb-1.0f);
								
	//float2 CosSin;
	//CosSin = normalize (float2(IN.TexCoord0.z, IN.TexCoord0.w));
	
	float cos_a = IN.TexCoord0.z;
	float sin_a = IN.TexCoord0.w;
	//float cos_a = CosSin.x;
	//float sin_a = CosSin.y;
	
	Bump.x = preBump.x * cos_a + preBump.y * (-sin_a);
	Bump.y = preBump.x * sin_a + preBump.y * (cos_a);
	Bump.z = preBump.z;

	// Global landspace normal as basis for bump
	float4 MegaNormalColor = MegaNormalMap.Sample(MegaNormalMap_Sampler, float2(IN.megaCoord.x, 1-IN.megaCoord.y));

	float3 MegaNormal = float3(0,0,1);
	MegaNormal = 2*float3(MegaNormalColor.a, 1-MegaNormalColor.g, 0)-1;
	float sx = MegaNormal.x;
	float sy = MegaNormal.y;
	float sz = sqrt(1.0f-(sx*sx+sy*sy));
	MegaNormal = normalize(float3(sx, sy, sz));

	float3 Nx = float3(Bump.z, 0, -Bump.x);
	float3 Ny = float3(0, Bump.z, -Bump.y);
	Bump.xyz = normalize(MegaNormal.z * Bump.xyz + MegaNormal.x * Nx + MegaNormal.y * Ny);

    //---diffuse---
	float LandA = IN.Color.a;
	float3 diffuse_light;       // Attention: under arbfp1 and fp30 profile I have a compilation error if use float4 instead of float3 (?????)
    diffuse_light.rgb = (Kd).rgb;
	//IN.LightDir.z = 1-IN.LightDir.z;
	float3 L = normalize(IN.LightDir.xyz);
	float scalar_product = dot(L, Bump.rgb); //* LandA;

	// specular 
#ifdef SPECULAR
    float3 HalfVec = normalize(IN.tex3);
    float spec = dot(HalfVec, Bump.xyz);
    spec = pow(spec, SpecularPower);

	float gloss = Bump.a;
	float3 specular_light = spec * gloss * SunSpecularColor;
#endif //SPECULAR

	float4 Road = RoadTex.Sample(RoadTex_Sampler, IN.TexCoord0.xy);   

	// read GBuffer
	float2 screen_uv = IN.ScreenPos.xy/IN.ScreenPos.w;
	screen_uv.x = 0.5f * (1.0f + screen_uv.x) + 0.5f/gRTSize.x;
	screen_uv.y = 0.5f * (1.0f - screen_uv.y) + 0.5f/gRTSize.y;
	float4 gbuffer = GBufferTex.Sample(GBufferTex_Sampler, screen_uv.xy);
	
#ifdef SHADOW
	float shadow_factor = gbuffer.r;
    scalar_product *= shadow_factor;
    
#ifdef SPECULAR
	specular_light *= shadow_factor;
#endif //SPECULAR

#endif  //SHADOW

	scalar_product = clamp(scalar_product * koeffNdotL.x + koeffNdotL.y , 0, 1);
	Road.rgb *= lerp(Ka.rgb*gbuffer.g, diffuse_light.rgb*koeffNdotL.z, scalar_product);

	float VertexAlpha = IN.Color.g;  //vertex alpha

#ifdef SPECULAR

	Road.rgb += ((specular_light) * VertexAlpha);   //also weight specular with vertex alpha

#endif //SPECULAR

	//update out alpha
    Road.a *= VertexAlpha;

#ifdef FOG1
  float4 fogColor = SkyMap.Sample(SkyMap_Sampler, IN.fogCoord.xyz);
  fogColor.rgb = lerp(fogColor.rgb, fogColor.rgb*fSkyMultiplier, fogColor.a);
  // compute final color
  Road.rgb = lerp(Road.rgb, fogColor.rgb, IN.fogCoord.w);
#endif

    return Road; 
}



struct VertexOut
{	
  float2 TexCoord0 : TEXCOORD0;  //Road texture
  float2 TexCoord1 : TEXCOORD1;  //Bump map           //really duplicate TexCoord0 - need for fp20 profile only
  float4 Color : COLOR0;        //Color.r contain Land.a, Color.g contain vertex Alpha

#ifdef SHADOW 
  float4 TexCoord2 : TEXCOORD2;  //Shadow map
#endif  //SHADOW

#ifdef SPECULAR
  float3 Color1 : COLOR1;       //Normal here for specular
  float3 tex3 : TEXCOORD3;      //contain Half vector for given vertex (need for specular)
#endif //SPECULAR
    float4 fogCoord : TEXCOORD4;
};


//-----------------------------------------------------------------------------
// PSSM implemetation

uniform sampler2D ShadowMap : register(s2);

// PSSM matrix array
uniform float4x4 PSSMProjTexMatrix0;
uniform float4x4 PSSMProjTexMatrix1;
uniform float4x4 PSSMProjTexMatrix2;
uniform float4x4 PSSMProjTexMatrix3;

uniform float4x4 PSSMModelTexMatrix0;
uniform float4x4 PSSMModelTexMatrix1;
uniform float4x4 PSSMModelTexMatrix2;
uniform float4x4 PSSMModelTexMatrix3;

uniform float PSSMSplit0;
uniform float PSSMSplit1;
uniform float PSSMSplit2;
uniform float PSSMSplit3;


uniform float PSSMWidth;

uniform float4 fSkyMultiplier;

//shadow map
#ifdef SHADOW
#define PSSM
	


// sample shadow map
float getShadowPixel(float3 projcoord)
{
	float ShadowFactor = 1;
#ifdef USE_SHADOWS
	float4 Shadow = tex2D(ShadowMap, projcoord.xy);
#ifndef COMPAREZ  
	ShadowFactor = Shadow.r;   //0 or 1
#else  //COMPAREZ
	float zProj = projcoord.z;
	ShadowFactor = (zProj > Shadow.r + 0.00) ? 0 : 1;
	ShadowFactor = Shadow.r > 0 ? ShadowFactor : 1;
#endif //COMPAREZ
#endif  //SHADOW
	return ShadowFactor;
}

float getShadow_ZLod(float4 world_coords)
{
    float4 shad_coord = float4(0, 0, 0, 0);
	float4 shadow_sample = float4(0, 0, 0, 0);

	float4 sm_k = float4(0, 0, 0, 0);
	

	//sm_k.x = step(0, world_coords.w) - step(PSSMSplit0, world_coords.w);
	//sm_k.y = step(PSSMSplit0, world_coords.w) - step(PSSMSplit1, world_coords.w);
	//sm_k.z = step(PSSMSplit1, world_coords.w) - step(PSSMSplit2, world_coords.w);
	//sm_k.w = step(PSSMSplit2, world_coords.w) - step(PSSMSplit3, world_coords.w);

	sm_k.x = world_coords.w > 0 ? (world_coords.w < PSSMSplit0 ? 1.0 : 0.0) : 0.0;
	sm_k.y = world_coords.w > PSSMSplit0 ? (world_coords.w < PSSMSplit1 ? 1.0 : 0.0) : 0.0;
	sm_k.z = world_coords.w > PSSMSplit1 ? (world_coords.w < PSSMSplit2 ? 1.0 : 0.0) : 0.0;
	sm_k.w = world_coords.w > PSSMSplit2 ? (world_coords.w < PSSMSplit3 ? 1.0 : 0.0) : 0.0;

	float sm_k_none = 1 - (dot(sm_k, sm_k)); // step(PSSMSplit3, world_coords.w); //  ? 1 : 0;
	


// 	sm_k.x = 0;
// 	sm_k.y = 0;
// 	sm_k.z = 0;
// 	sm_k.w = 1;
// 	sm_k_none = 1;


	float4x4 sh_m = sm_k.x*PSSMProjTexMatrix0 +
					sm_k.y*PSSMProjTexMatrix1 + 
					sm_k.z*PSSMProjTexMatrix2 + 
					sm_k.w*PSSMProjTexMatrix3;
					
	float4x4 sh_mv = sm_k.x*PSSMModelTexMatrix0 +
					 sm_k.y*PSSMModelTexMatrix1 + 
					 sm_k.z*PSSMModelTexMatrix2 + 
					 sm_k.w*PSSMModelTexMatrix3;

	//shad_coord = sm_k.x*shad_coord0 + sm_k.y*shad_coord1 + sm_k.z*shad_coord2 + 
	//	sm_k.w*shad_coord3;
	
	shad_coord = mul(sh_m, float4(world_coords.xyz, 1));
	shad_coord.xyz /= shad_coord.w;
	
	float z_eps =	sm_k.x*0.0001 + 
					sm_k.y*0.0002 + 
					sm_k.z*0.0004 + 
					sm_k.w*0.0006;
	
	if (1)	z_eps = 0.000;	

	float3 sm_offs =	sm_k.x * float3(0.0, 0.5, 0.0) +
						sm_k.y * float3(0.5, 0.5, 0.0) + 
						sm_k.z * float3(0.0, 0.0, 0.0) + 
						sm_k.w * float3(0.5, 0.0, 0.0);

	float sm_scale = sm_k.x*0.8 + sm_k.y*0.6 + sm_k.z*0.4 + sm_k.w*0.2;

	float shadow_factor = 1.0;

	if (0)
	{
		return 1;
	}
	else if (1)
	{
		float dist = -0.001 * mul(sh_mv, float4(world_coords.xyz, 1)).z;
	
		// changed shadow_factor		
		shadow_sample = tex2D(ShadowMap, float2(sm_offs.x + 0.5*shad_coord.x, sm_offs.y + 0.5*shad_coord.y));
		shadow_factor = (dist  - z_eps > shadow_sample.r) ? 1 : 0;
		shadow_factor = shadow_sample.r > 0 ? shadow_factor : 0;
		
		// change sign
		//shadow_factor = shadow_factor*saturate(1 - saturate((world_coords.w - PSSMSplit3 + 20)/20));
		shadow_factor = 1 - shadow_factor;
	}
	else
	{
		float3 uvz = shad_coord.xyz; // clamp(shad_coord.xy, 0.0, 1.0);
		uvz.xy = clamp(shad_coord.xy, 0.0, 1.0); 
		float mgs = PSSMWidth;
		uvz.x *= 0.5*PSSMWidth;
		uvz.y *= 0.5*PSSMWidth;
		float x = floor(uvz.x);
		float y = floor(uvz.y);
		float z = uvz.z * mgs;
		float u_ratio = uvz.x - x;
		float v_ratio = uvz.y - y;
		float u_opposite = 1 - u_ratio;
		float v_opposite = 1 - v_ratio;

		//shadow_factor = getShadowPixel(sm_offs + float3(x, y, z)/mgs);
		
		//shadow_sample = tex2D(ShadowMap, float2(sm_offs.x + 0.5*shad_coord.x, sm_offs.y + 0.5*shad_coord.y));

		shadow_factor =
			(getShadowPixel(sm_offs + float3(x, y, z)/mgs)*u_opposite + 
			 getShadowPixel(sm_offs + float3(x+1,y,z)/mgs)*u_ratio) * v_opposite + 

			(getShadowPixel(sm_offs + float3(x,y+1,z)/mgs) * u_opposite + 
			 getShadowPixel(sm_offs + float3(x+1,y+1,z)/mgs)*u_ratio) * v_ratio;
	}
	
	
	
	//return sm_scale;
	//return sm_scale*shadow_factor;
	return shadow_factor; //  + sm_k_none;
}

#endif  //SHADOW

//-----------------------------------------------------------------------------
//	Main
//-----------------------------------------------------------------------------

uniform float4 Ka; //Ambient color
uniform float4 Kd; //Diffuse color
uniform float3 LightDir;                           //Dir to sun
uniform sampler2D RoadTex: register(s0);              //Road texture
uniform sampler2D BumpMap : register(s1);              //Bump texture
#ifdef SPECULAR
	uniform float SpecularAmount;                     //degree of specular - 16.0  ???????????????
	uniform float BumpAmount;                         //influnce of bump normal to specular - 1.0  ???????????????
	uniform float3 SunSpecularColor;
#endif //SPECULAR
#ifdef FOG
	uniform samplerCUBE SkyMap: register(s3); // Fog texture
#endif

float4 main(in VertexOut IN
			) : COLOR
{
    //read bump vector
	float4 Bump = tex2D(BumpMap, IN.TexCoord1);
	Bump.rgb = 2.0f*(Bump.rgb-0.5f);  //blue component after this conversion will be the same

    //---diffuse---
	float LandA = IN.Color.r;
	float3 diffuse_light;       //Attention: under arbfp1 and fp30 profile I have a compilation error if use float4 instead of float3 (?????)
    diffuse_light.rgb = LandA * Kd.rgb;
	float scalar_product = dot(Bump.rgb, LightDir);
	diffuse_light.rgb *= scalar_product;

#ifdef SPECULAR
	//---specular---
	float3 specular_light = SunSpecularColor;
    float3 normal = 2.0*(IN.Color1-0.5);
    float3 Norm = normalize(lerp(normal.rgb, Bump.rgb, BumpAmount));
	float3 HalfVec = normalize(IN.tex3);
    float spec = dot(HalfVec, Norm);
    spec = pow(spec,SpecularAmount);

	float gloss = Bump.a;
	specular_light = specular_light * spec * gloss;
	//--------------
#endif //SPECULAR

	float4 Road = tex2D(RoadTex, IN.TexCoord0);   

#ifdef SHADOW
	float ShadowFactor = 0;

	ShadowFactor = getShadow_ZLod(IN.TexCoord2.xyzw); 

	diffuse_light.rgb = ShadowFactor * diffuse_light.rgb;

#ifdef SPECULAR
	specular_light = ShadowFactor * specular_light;
#endif //SPECULAR
	//-------------

#endif  //SHADOW

	Road.rgb = clamp( Ka.rgb + diffuse_light.rgb, 0.0, 1.0) * Road.rgb;

#ifdef SPECULAR
	Road.rgb += clamp(specular_light, 0.0, 1.0);   
#endif //SPECULAR

#ifdef FOG
  float4 fogColor = texCUBE(SkyMap, IN.fogCoord.xyz);
  // clamp(fSkyMultiplier, 0, 12)
  fogColor.rgb = lerp(fogColor.rgb, fogColor.rgb*fSkyMultiplier.x, fogColor.a);
  // fogColor.rgb = fogColor.rgb*clamp(1.0 + (fSkyMultiplier - 1.0), 0.0, 1.0);
  // compute final color
  Road.rgb = lerp(Road.rgb, fogColor.rgb, IN.fogCoord.w);  
#endif

    return Road; 
}



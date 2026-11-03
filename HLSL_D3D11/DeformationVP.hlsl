// D3D11 port of DeformationVP.hlsl. Generated from the legacy HLSL source; see README.md.
#define PSSM

struct VertexIn
{
    float4 position : POSITION;
	float2 tex0 : TEXCOORD0;
    float4 Color : COLOR0;           //Color.r contain Land.a
#ifdef SPECULAR
	float3 Normal : NORMAL;
#endif //SPECULAR
};

struct VertexOut
{
    float2 tex0 : TEXCOORD0;    //Deformation texture
    float2 tex1 : TEXCOORD1;    //Bump map           //really duplicate TexCoord0 - need for fp20 profile only
    float4 Color : COLOR0;
    #ifdef SHADOW
	//Attention: we assume that will be used hardware shadow map support, so Tex(s/q, t/q) will be compared with r/q
    float4 tex2 : TEXCOORD2;    //shadow map texture - !!!NEW
    #endif  //SHADOW

#ifdef SPECULAR
    float3 Color1 : COLOR1;     //Normal here for specular
    float3 tex3 : TEXCOORD3;    //contain Half vector for given vertex (need for specular)
    #endif //SPECULAR
    float4 fogCoord : TEXCOORD4;
    float4 pos : SV_Position;
};

#ifdef FOG
//Calculate integral fog density throw 2 fog layers
//Attention: Note!!! A*=0.5
float IntegralHDense2(in float4 cFogHBounds,       //cMinFogH1 cMaxFogH1 cMinFogH2 cMaxFogH2
                      in float4 cFogABAB,          //xy=A1B1, zw=A2B2
                      in float H0, in float H1)    //height for camera and vertex				 
{
  float4 HH = float4(H0, H1, H0, H1);
  HH = clamp(HH, cFogHBounds.xxzz, cFogHBounds.yyww);   //here HH=(hMin1,hMax1,hMin2,hMax2)
  float4 ff = HH*(HH*cFogABAB.xxzz + cFogABAB.yyww);
  return dot(ff, float4(-1.0f, 1.0f, -1.0f, 1.0f)); 
}
#endif

#ifdef SPECULAR
cbuffer DeformationVP_CB0 : register(b0)
{
	float3 CamPos;     //for specular
	float3 LightDir;    //dir to sun - for specular (must be normirated)
};
#endif //SPECULAR
	
cbuffer DeformationVP_CB1 : register(b1)
{
column_major float4x4 ModelView;
column_major float4x4 ModelViewProj;

};
#ifdef FOG
  #ifdef SIMPLE_FOG_OLD
cbuffer DeformationVP_CB2 : register(b2)
{
	float cSimpleDensity;
};
  #endif //SIMPLE_FOG_OLD
#ifndef SPECULAR
cbuffer DeformationVP_CB3 : register(b3)
{
	float3 CamPos;
};
#endif
            		//helper const 
cbuffer DeformationVP_CB4 : register(b4)
{
	float cTexScale;       //for calc texture coordinate in texture with fog RGB color
	float4 cFogHBounds;    //cMinFogH1 cMaxFogH1 cMinFogH2 cMaxFogH2
	float4 cFogABAB;       //A1,B1,A2,B2
	float4 CosSin;
};
#endif

VertexOut main(VertexIn IN
            )
{
    VertexOut OUT;
	OUT.fogCoord = float4(0,0,0,0);

/*
	//---transform vertex - rotation on angle---
    //Attention: !!! use rotation around center !!!
    float2 center_in_plane = OriginSize.xy + OriginSize.zw/2.0;
    float3 relative_pos = float3(IN.position.xy - center_in_plane, 0.0);
    float3 pos = mul(RotationMatrix, relative_pos); 
	pos.z = 0.0;
	pos += float3(center_in_plane, IN.position.z);  //now pos contain word coord after rotation
	float4 pos_new = float4(pos, 1.0);
*/   
    float4 pos_new = IN.position;

	//---transform vertex to camera space---
    OUT.pos = mul(ModelViewProj, pos_new);

#ifdef SHADOW
	OUT.tex2 = pos_new;
	OUT.tex2.w = -mul(ModelView, float4(IN.position.xyz, 1)).z;
#endif  //SHADOW

/*
	//Generate texture coord, using vertex position and deformation's grid origin and size (passed as uniform input)
	//Attention: during rotation texture is fixed relative to grid, so to simplify calculation use IN.position insted of pos_new
	OUT.tex0 = (IN.position.xy - OriginSize.xy)/OriginSize.zw;
	OUT.tex1 = OUT.tex0;
*/
	//Pass throw 
	OUT.tex0 = IN.tex0;
	OUT.tex1 = IN.tex0;

	//Pass throw 
	OUT.Color = IN.Color;

#ifdef SPECULAR
	//calc Half vector
	float3 ViewDir = normalize(CamPos - pos_new.xyz);
	float3 HalfVec = ViewDir + LightDir; //will be normirate in pixel shader

    OUT.Color1.rgb = 0.5*IN.Normal + 0.5;
    OUT.tex3 = HalfVec;
#endif //SPECULAR


#ifdef FOG
  float3 VertexPosition = IN.position.xyz;
  float3 dP = VertexPosition - CamPos;
  float dist = length(dP);

#ifdef SIMPLE_FOG_OLD

  float II = cSimpleDensity*dist;
  float fog=1.0-exp(-II);
  
#else //SIMPLE_FOG_OLD

  //--main fog calculation--
  float H0 = CamPos.z;
  float H1 = VertexPosition.z;
  float DH = H1-H0;

  //--work around singularity - (devizion by 0)--
  //!!! correct slightly H1 !!!
  const float eps = 1.0E-1;   //[m]
  if(abs(DH) < eps) 
  {
  	  H1 += 2.0*eps;
  	  DH = H1-H0;
  }
  //const float eps = -0.01f;
  //DH -= 2*clamp(abs(DH)+eps,eps,0);
  //---------------------------------------------

  float InvSinAlfa=dist/DH;
  float II = InvSinAlfa*IntegralHDense2(cFogHBounds, cFogABAB, H0, H1);  
  float fog=1.0-exp(-abs(II));

#endif //SIMPLE_FOG_OLD

  //--select fog RGB color from fog support texture--   
  //OUT.fogCoord = float3((cTexScale*dP + 0.5).xy, fog);
  OUT.fogCoord = float4(dP.x*CosSin.x+dP.y*CosSin.y, dP.x*CosSin.z+dP.y*CosSin.w, -saturate(-dP.z), fog);
  OUT.fogCoord = float4(cTexScale*OUT.fogCoord.xy, -1, OUT.fogCoord.w);
#endif

    OUT.Color = saturate(OUT.Color); // D3D9 COLOR interpolator clamp
#ifdef SPECULAR
    OUT.Color1 = saturate(OUT.Color1); // D3D9 COLOR interpolator clamp
#endif
    return OUT;
} 

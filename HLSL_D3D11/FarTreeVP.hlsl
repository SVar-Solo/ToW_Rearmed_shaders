// D3D11 port of FarTreeVP.hlsl. Generated from the legacy HLSL source; see README.md.
//****************************************************
// FarTrees vertex shader
//****************************************************

struct InStruct
{
  float4 position : POSITION;  
  float2 tex0     : TEXCOORD0; 
  float4 fogColor : TEXCOORD1;
};

struct OutStruct
{
  float4 color    : COLOR0;
  float4 fogColor : COLOR1;
  float2 tex0     : TEXCOORD0;
  float4 fogCoord : TEXCOORD1;
  float4 hPos     : SV_Position;
};

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

cbuffer FarTreeVP_CB0 : register(b0)
{
column_major float4x4 ModelViewProj;
float3 LightVector;   //vector from sun in WCS
float3 DiffuseColor;  //current diffuse coeff
float3 AmbientColor;  //current ambient coeff
float3 CameraPos;     //current camera pos
};
#ifdef FOG
  #ifdef SIMPLE_FOG_OLD
cbuffer FarTreeVP_CB1 : register(b1)
{
	float cSimpleDensity;
};
  #endif //SIMPLE_FOG_OLD
cbuffer FarTreeVP_CB2 : register(b2)
{
	float3 CamPos;
         		//helper const 
	float cTexScale;       //for calc texture coordinate in texture with fog RGB color
	float4 cFogHBounds;    //cMinFogH1 cMaxFogH1 cMinFogH2 cMaxFogH2
	float4 cFogABAB;       //A1,B1,A2,B2
	float4 CosSin;
};
#endif

cbuffer FarTreeVP_CB3 : register(b3)
{
float3 koeffNdotL;

};
OutStruct main(in InStruct IN)
{
  OutStruct OUT;
  OUT.hPos = mul(ModelViewProj, IN.position);
  OUT.tex0 = IN.tex0;
  OUT.fogCoord = float4(0,0,0,0);
  
  float3 eyeVector;
  eyeVector.xy = CameraPos.xy - IN.position.xy;
  eyeVector.z  = 0;
  
  float3 diffuseLight = DiffuseColor; 
  float3 ambientLight = AmbientColor;

  float scalar_product = clamp(dot(LightVector, normalize(eyeVector)), 0, 1);
  scalar_product = clamp(scalar_product * koeffNdotL.x + koeffNdotL.y , 0, 1);
  OUT.color.rgb = lerp(ambientLight, diffuseLight.rgb*koeffNdotL.z, scalar_product);
//  OUT.color.rgb = diffuseLight + ambientLight;
  OUT.color.a   = 1.0f;
  OUT.fogColor  = IN.fogColor;
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
  if(abs(DH) < eps) {
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
    OUT.color = saturate(OUT.color); // D3D9 COLOR interpolator clamp
    OUT.fogColor = saturate(OUT.fogColor); // D3D9 COLOR interpolator clamp
  return OUT;
} 

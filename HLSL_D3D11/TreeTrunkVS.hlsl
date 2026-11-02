// D3D11 port of TreeTrunkVS.hlsl. Generated from the legacy HLSL source; see README.md.
struct VertexIN
{
    float4 position : POSITION;
    float4 color0 : COLOR0;
    float4 color1 : COLOR1;
    float2 texcoord : TEXCOORD0;
};

struct VertexOUT
{
	#ifndef ZPASS
	float4 color : COLOR0;
	float2 texcoord : TEXCOORD0;
	#ifdef FOG
	float4 fogCoord : TEXCOORD1;
	#endif
#else
	float4 zcoord : TEXCOORD2;
	#endif // ZPASS
	float4 HPOS : SV_Position;
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

cbuffer TreeTrunkVS_CB0 : register(b0)
{
column_major float4x4 ModelViewProj;
};
#ifndef ZPASS
#ifdef FOG
  #ifdef SIMPLE_FOG_OLD
cbuffer TreeTrunkVS_CB1 : register(b1)
{
	float cSimpleDensity;
};
  #endif //SIMPLE_FOG_OLD
cbuffer TreeTrunkVS_CB2 : register(b2)
{
	float3 CamPos;
            		//helper const 
	float cTexScale;       //for calc texture coordinate in texture with fog RGB color
	float4 cFogHBounds;    //cMinFogH1 cMaxFogH1 cMinFogH2 cMaxFogH2
	float4 cFogABAB;       //A1,B1,A2,B2
	float4 CosSin;
};
#endif // FOG
#endif // ZPASS

VertexOUT main(in VertexIN IN) 
{
	VertexOUT OUT;
	float3 pos = IN.position.xyz;
	OUT.HPOS = mul(ModelViewProj, float4(pos, 1.0));
#ifndef ZPASS
	OUT.color = IN.color0;	
	OUT.texcoord = IN.texcoord;
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
#else
	OUT.zcoord = OUT.HPOS;
#endif // ZPASS
    OUT.color = saturate(OUT.color); // D3D9 COLOR interpolator clamp
	return OUT;
} 

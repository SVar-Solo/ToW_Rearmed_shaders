

struct VertexIN
{
    float4 position : POSITION;
    float2 coord : TEXCOORD0;
};         

struct VertexOUT
{
	float4 HPOS : POSITION;
#ifdef USE_FOG
	float4 FogColor: COLOR0;
#endif
	float4 coord : TEXCOORD0;
	float4 spos	: TEXCOORD1;
	float4 screen_pos : TEXCOORD2;
#ifdef USE_FOG
	float3 fogCoord : TEXCOORD3;
#endif

};

#ifdef USE_FOG
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

uniform float4x4 ModelViewProj : _GL_MVP;
uniform float4x4 ModelView : _GL_MV;
uniform float3 cameraPosition;


#ifdef USE_FOG
  #ifdef SIMPLE_FOG_OLD
	uniform float cSimpleDensity;
  #endif //SIMPLE_FOG_OLD
	uniform float3 CamPos;
            		//helper const 
	uniform float cTexScale;       //for calc texture coordinate in texture with fog RGB color
	uniform float4 cFogHBounds;    //cMinFogH1 cMaxFogH1 cMinFogH2 cMaxFogH2
	uniform float4 cFogABAB;       //A1,B1,A2,B2
	uniform float4 CosSin;
#endif


VertexOUT main(VertexIN IN) 
{
	VertexOUT OUT;
	
	float3 pos = IN.position.xyz;
	OUT.HPOS = mul(ModelViewProj, float4(pos, 1.0));
	//float2 texcoord = float2(1,1)-(IN.position.xy/2048);
	float2 texcoord = (IN.position.xy/2048);
	//texcoord.y = 1-texcoord.y;
	OUT.coord.xy = float2(texcoord.x, texcoord.y);
	OUT.coord.z = IN.position.z;
	OUT.coord.w = OUT.HPOS.z;
	OUT.spos = OUT.HPOS;
	OUT.screen_pos = OUT.HPOS;

#ifdef USE_FOG1

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
  //const float eps = 0.01f;
  //DH = -sign(DH)*(clamp(abs(DH),eps, 10000));
  //DH -= 2*clamp(abs(DH)+eps,eps,0);
  //---------------------------------------------

  float InvSinAlfa=dist/DH;
  float II = InvSinAlfa*IntegralHDense2(cFogHBounds, cFogABAB, H0, H1);  
  float fog=1.0-exp(-abs(II));

#endif //SIMPLE_FOG_OLD

  //--select fog RGB color from fog support texture--   
  OUT.FogColor = float4(1.0, 1.0, 1.0, fog);  
  //OUT.fogCoord = (cTexScale*dP + 0.5).xy;
  //OUT.fogCoord = float3(dP.x*CosSin.x+dP.y*CosSin.y, dP.x*CosSin.z+dP.y*CosSin.w, -saturate(-dP.z));
  //OUT.fogCoord = float3(dP.x*CosSin.x + dP.y*CosSin.y, dP.x*CosSin.z + dP.y*CosSin.w, -saturate(-dP.z));
  OUT.fogCoord = float3(dP.x*CosSin.x + dP.y*CosSin.y, dP.x*CosSin.z + dP.y*CosSin.w, -saturate(-dP.z));
  OUT.fogCoord = float3(cTexScale*OUT.fogCoord.xy, -1);
#endif
//temp
#ifdef USE_FOG
  OUT.FogColor = float4(1.0, 1.0, 1.0, 0.0);
  OUT.fogCoord = float3(0,0,0);
#endif
	
	return OUT;
} 

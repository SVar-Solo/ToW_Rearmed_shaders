// D3D11 port of FogTest.hlsl. Generated from the legacy HLSL source; see README.md.
//****************************************************
//Vertex shader for Fog calculation
//See function prototype - float TLandscape::_Fogf(TPoint3D &P)
//****************************************************

//Attention: USE_CUSTOM_MATRIX - need for additional vertex conversion to WCS
//#define SIMPLE_FOG

struct appdata
{
    float4 position : POSITION;
};

struct vfconn
{
    float4 COL0 : COLOR0;
    float3 fogCoord : TEXCOORD0;
    //	float ppp : PSIZE;
    float4 HPOS : SV_Position;
};

/*      
//see TLandBase::SetFogRange() for MinFogH, MaxFogH, AFog, BFog calculation
float IntegralHDense(in float H0, in float H1,              //min and max height for camera and vertex
					 in float MinFogH, in float MaxFogH,    //min and max height for fog layer
					 in float AFog, in float BFog)          //linear interpolation coeff for fog density
{
  float h0=clamp(H0,MinFogH, MaxFogH);
  float h1=clamp(H1,MinFogH, MaxFogH);

	return ((h1-h0)*(AFog*(h1+h0)*0.5 + BFog));
	
}
*/

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

cbuffer FogTest_CB0 : register(b0)
{
column_major float4x4 ModelViewProj;
};
#ifdef USE_CUSTOM_MATRIX
cbuffer FogTest_CB1 : register(b1)
{
	column_major float4x4 CustomMatrix;
};
#endif
cbuffer FogTest_CB2 : register(b2)
{
	float3 CamPos;
            //helper const 
	float cTexScale;       //for calc texture coordinate in texture with fog RGB color
	float4 cFogHBounds;    //cMinFogH1 cMaxFogH1 cMinFogH2 cMaxFogH2
	float4 cFogABAB;       //A1,B1,A2,B2
};
#ifdef SIMPLE_FOG
cbuffer FogTest_CB3 : register(b3)
{
	float cSimpleDensity;
};
#endif //SIMPLE_FOG
cbuffer FogTest_CB4 : register(b4)
{
	float4 CosSin;


};
vfconn main(appdata IN)
{
    vfconn OUT;

	//---transform vertex to camera space---
    OUT.HPOS = mul(ModelViewProj, IN.position);


	//**************************************************************************
	//Attention: calculation logic must be the same, see TLandscape::GetFogRGBA()
	//**************************************************************************


	float3 VertexPosition = IN.position.xyz;
#ifdef USE_CUSTOM_MATRIX
	VertexPosition = mul(CustomMatrix, IN.position);
#endif

	float3 dP = VertexPosition - CamPos;
    float dist = length(dP);

#ifdef SIMPLE_FOG

	float II = cSimpleDensity*dist;
    float fog=1.0-exp(-II);

#else //SIMPLE_FOG

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

#endif //SIMPLE_FOG

	//--select fog RGB color from fog support texture--   
    OUT.COL0 = float4(1.0, 1.0, 1.0, fog);  
    //OUT.fogCoord = (cTexScale*dP + 0.5).xy; 
    OUT.fogCoord = float3(dP.x*CosSin.x+dP.y*CosSin.y, dP.x*CosSin.z+dP.y*CosSin.w, -saturate(-dP.z));
    OUT.fogCoord = float3(cTexScale*OUT.fogCoord.xy, -1);
    OUT.COL0 = saturate(OUT.COL0); // D3D9 COLOR interpolator clamp
    return OUT;
} 

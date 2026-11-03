// D3D11 port of TreeVP.hlsl. Generated from the legacy HLSL source; see README.md.
//****************************************************
//Vertex shader for calculation trees sprite geometry and lighting
//See function prototype - float TTrees::VS_RenderTreeSprites()
//****************************************************

//#define SHADOW  
//#define ZPASS  
#define PSSM

struct InStruct
{
    float4 position : POSITION;  //position of center of sprite in WCS
    float3 normal   : NORMAL;    //temp pack

#ifndef ZPASS
    float2 tex0 : TEXCOORD0;     //temp pack
    float2 tex1 : TEXCOORD1;     //temp pack
#else
	float2 tex1 : TEXCOORD0;     //temp pack
#endif //ZPASS

    

#ifndef ZPASS
    float4 Color0   : COLOR0;    //??????   //fog.rgba   //Attention: !!! color.a can't be used for Radeon !!!
#endif //ZPASS
};

struct OutStruct
{
    #ifndef ZPASS
    float4 COL0 : COLOR0;       //temp - tranzit from input    - diffuse + ambient light
    float4 COL1 : COLOR1;       //temp - tranzit from input    - fog
    float2 tex0 : TEXCOORD0;
    float2 tex1 : TEXCOORD1;
    #else
	float2 tex1 : TEXCOORD0;
    #endif //ZPASS
    

#ifndef ZPASS
#ifdef SHADOW
	//Attention: we assume that will be used hardware shadow map support, so Tex(s/q, t/q) will be compared with r/q
    float4 TEX2 : TEXCOORD2;    //shadow map texture - !!!NEW
    #endif  //SHADOW
  #ifdef FOG
	float4 fogCoord : TEXCOORD3;
    #endif
#else
	float4 zcoord : TEXCOORD4;
    #endif //ZPASS
	float3 ambient_dir : TEXCOORD5;
    float3 normal : TEXCOORD6;
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

cbuffer TreeVP_CB0 : register(b0)
{
column_major float4x4 ModelViewProj;
};
#ifndef PROFILE_ARBVP1
cbuffer TreeVP_CB1 : register(b1)
{
	column_major float4x4 ModelView;
	column_major float4x4 ModelViewInverse;  //???
	column_major float4x4 Proj;
};
#endif  //PROFILE_ARBVP1
#ifndef ZPASS
cbuffer TreeVP_CB2 : register(b2)
{
	float3 LightVector;    //vector from sun in WCS
	float Ka;  //current ambient coeff
	float Kd;  //current diffuse coeff
	//uniform float3 TreesKa;  //current ambient coeff
	//uniform float3 TreesKd;  //current diffuse coeff
};
#ifdef SHADOW
cbuffer TreeVP_CB3 : register(b3)
{
	column_major float4x4 ShadowMapProjTexMatrix;         //shadow map texture - !!!NEW
};
#endif  //SHADOW
#ifdef FOG
  #ifdef SIMPLE_FOG_OLD
cbuffer TreeVP_CB4 : register(b4)
{
	float cSimpleDensity;
};
  #endif //SIMPLE_FOG_OLD
cbuffer TreeVP_CB5 : register(b5)
{
	float3 CamPos;
	//helper const 
	float cTexScale;       //for calc texture coordinate in texture with fog RGB color
	float4 cFogHBounds;    //cMinFogH1 cMaxFogH1 cMinFogH2 cMaxFogH2
	float4 cFogABAB;       //A1,B1,A2,B2
	float4 CosSin;
};
#endif
#endif //ZPASS

OutStruct main(in InStruct IN)
{

    OutStruct OUT;

	//get sprite data
    float2 SpriteRadius = IN.normal.xy;

	//made sprite vertex
	float4 SpriteVertexWCS = IN.position;                    //center of sprite in WCS
    float4 SpriteVertex = mul(ModelView, SpriteVertexWCS);   //convert to camera model view CS

	//---made sprite CS(represented in camera model view CS)----
/*
    float3 vz = normalize(SpriteVertex.xyz);
	float3 vx = float3(vz.z, 0, -vz.x);   //so cross product vx*vz = 0
    vx = normalize(vx);
	float3 vy = cross(vz,vx);
*/
    float3 vz = -normalize(SpriteVertex.xyz);  //we want vector oriented from sprite
    float3 vy = float3(0.0, 1.0, 0.0);
	float3 vx = cross(vy,vz);
    vx = normalize(vx);
	vy = cross(vz,vx);
	//---------------------

    //---add sprite vertex shift---
//	SpriteVertex.xy += SpriteRadius;

    SpriteVertex.xyz += (SpriteRadius.x * vx.xyz);
    SpriteVertex.xyz += (SpriteRadius.y * vy.xyz);
	//-----------------------------

	//remove artefacts - made sprites slighly not complanar
//	SpriteVertex.z += 0.05*(SpriteRadius.x + SpriteRadius.y);  //?????

	//transform vertex to camera space
    OUT.HPOS = mul(Proj, SpriteVertex);

//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
//Attention: we don't use this code since it doesn't work on Radeon.
//	         Instead we move this simple texture coord calculations back to CPU.
//           The problem is dueto using any branch instruction in vertex shader (not always work for Radeon).
//           This corrected in CG 1.2.1 version.

/*
	//texture mapping: bump and tree textures
    float2 tt_bump_shift = IN.tex0;  //select bump fragment 
    float2 tt_tex_shift = IN.tex1;   //select texture fragment according to tree type

    float2 tt= float2(0.25, 0.25)*(sign(SpriteRadius) + float2(1.0, 1.0));

    OUT.tex1 = tt + tt_tex_shift;    //tree texture

#ifndef ZPASS

    OUT.tex0 = tt + tt_bump_shift;   //bump texture
*/

    OUT.tex1 = IN.tex1; 

#ifndef ZPASS

    OUT.tex0 = IN.tex0;

//~~~~~~~~~~~~~~

	//------------------------Light calculations---------------------
	//calc FogRGBA
	float fog_factor = IN.Color0.a;   
    float4 FogRGBA = IN.Color0 * fog_factor;   

    //calc LVColor
	float2 CurrentAmbientDiffuse = float2(Ka, Kd);    //float2(0.5, 0.5);
	float2 AmbientDiffuse = CurrentAmbientDiffuse*(1.0-fog_factor);  //reguard fog here
//	float3 Ambient = TreesKa * (1.0-fog_factor);  //reguard fog here
//	float3 Diffuse = TreesKd * (1.0-fog_factor);  //reguard fog here

	//-------handling external lights--------
	//get sum intensity of external lights
    float SumIntensity = IN.normal.z;

    float SumI = SumIntensity/4.0*(1.0-fog_factor);  //correct by fog 
    FogRGBA += float4(0.875, 0.75, 0.5, 0.0)*SumI;   //update FogRGBA      (7/8, 3/4, 1/2, 0)
	AmbientDiffuse.x += (0.75*SumI);                 //update ambient
//    Ambient += (0.75*SumI);
//    Diffuse += (0.75*SumI);
	//---------------------------------------

	//------calc light vector in sprite CS-----
	float3 LightVectorS = mul(ModelView, float4(-LightVector, 0.0)).xyz;   
    LightVectorS = float3(dot(LightVectorS,vx), dot(LightVectorS,vy), dot(LightVectorS,vz));  
	//-----------------------------------------

	//LightVectorS *= AmbientDiffuse.y;  //LightVectorS again in range [-1...1]
	//LightVectorS = normalize(LightVectorS);
	float3 adir = mul(ModelView, float4(0,0,1,0)).xyz;
        adir = float3(dot(adir,vx), dot(adir,vy), dot(adir,vz));
	OUT.ambient_dir = adir;
    //---Attention:---
	//LightVectorS must be converted from range [-1...1] to range [0...1] for pass to pixel shader throw color
    OUT.normal = LightVectorS;
    LightVectorS +=1.0;
    LightVectorS *=0.5;
	//----------------
    OUT.COL0.rgb = LightVectorS.xyz;    //diffuse here
    OUT.COL0.a = AmbientDiffuse.x;      //ambient here

    OUT.COL1 = FogRGBA;
	//----------------------------------------------------------------

	//--shadows--
#ifdef SHADOW
    //float4 new_position = SpriteVertexWCS+float4(IN.normal.xy,0,0);//mul(ModelViewInverse, SpriteVertex);   //convert back to WCS
    float4 new_position = mul(ModelViewInverse, float4(SpriteVertex.xyz,1));   //convert back to WCS

#ifdef PSSM
	
	//--optional correction--
	//update position sligtly to remove artefacts
	const float cLvShift = 1.0;  //[m]
    new_position -= float4(LightVector * cLvShift, 0.0);
    new_position.w = 1;
	//new_position.z+=1;
	OUT.TEX2 = new_position;
#else
	//--optional correction--
	//update position sligtly to remove artefacts
	const float cLvShift = 1.0;  //[m]
    new_position -= float4(LightVector * cLvShift, 0.0);
    new_position.w=1;
	//new_position.z+=1;
	//-----------------------

    //OUT.TEX2 = float4(SpriteVertexWCS.x, SpriteVertexWCS.y, SpriteVertexWCS.z*0, SpriteVertexWCS.w)/100.f;//mul(ShadowMapProjTexMatrix, new_position);
    //new_position = float4(1,1,1,1);
    OUT.TEX2 = mul(ShadowMapProjTexMatrix, new_position);
#endif // PSSM
#endif  //SHADOW

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
	//OUT.HPOS = mul(ModelViewProj, float4(IN.position.xyz+float3(IN.normal.x,IN.normal.y, 0),1));
	OUT.zcoord = OUT.HPOS;
#endif // ZPASS

#ifndef ZPASS
    OUT.COL0 = saturate(OUT.COL0); // D3D9 COLOR interpolator clamp
    OUT.COL1 = saturate(OUT.COL1); // D3D9 COLOR interpolator clamp
#endif
    return OUT;
} 

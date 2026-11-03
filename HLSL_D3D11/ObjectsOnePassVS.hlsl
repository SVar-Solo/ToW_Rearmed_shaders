// D3D11 port of ObjectsOnePassVS.hlsl. Generated from the legacy HLSL source; see README.md.
// Legacy fog variant alias: FOG1/USE_FOG1 must see the same resources/interpolators as USE_FOG.
#if defined(USE_FOG1) && !defined(USE_FOG)
#define USE_FOG
#endif
struct vertexInputs
{
    float4 position     : POSITION;
	//float4 color        : COLOR0;
    float3 normal       : NORMAL;
    float2 texcoords0   : TEXCOORD0;
	float3 texcoords1   : TEXCOORD1;
	float3 texcoords2   : TEXCOORD2;
	float3 texcoords3   : TEXCOORD3;
#ifdef USE_SKINNING
	float4 texcoords4   : TEXCOORD4; // bones
	float4 texcoords5   : TEXCOORD5; // weights
//	float4 texcoords6   : TEXCOORD6; // used in vb_transform
#endif
};

struct vfconn
{
	float4 FogColor : COLOR0;
	float3 Normal : COLOR1;
	float2 Tex0 : TEXCOORD0;
	float3 fogCoord : TEXCOORD1; // fog
	float3 LightDir : TEXCOORD2;
	float3 Tex3 : TEXCOORD3;
	float4 Tex4 : TEXCOORD4; // shadows
	//	float3 UpDir : TEXCOORD5; // up
	float4 HPos : SV_Position;
};

cbuffer ObjectsOnePassVS_CB0 : register(b0)
{
float3 LightDir;
};
#ifdef USE_SPECULAR
cbuffer ObjectsOnePassVS_CB1 : register(b1)
{
	float3 ViewDir;
};
#endif

cbuffer ObjectsOnePassVS_CB2 : register(b2)
{
column_major float4x4 ModelView;
column_major float4x4 ModelViewProj;
column_major float4x4 halTextureMatrix0;
column_major float4x4 MatrixObjectToWorld;


};
#ifdef USE_FOG
  #ifdef SIMPLE_FOG_OLD
cbuffer ObjectsOnePassVS_CB3 : register(b3)
{
	float cSimpleDensity;
};
  #endif //SIMPLE_FOG_OLD
cbuffer ObjectsOnePassVS_CB4 : register(b4)
{
	float3 CamPos;
            //helper const 
	float cTexScale;       //for calc texture coordinate in texture with fog RGB color
	float4 cFogHBounds;    //cMinFogH1 cMaxFogH1 cMinFogH2 cMaxFogH2
	float4 cFogABAB;       //A1,B1,A2,B2
	float4 CosSin;
};
#endif
cbuffer ObjectsOnePassVS_CB5 : register(b5)
{
column_major float4x4 BonesMatrix[40];

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

// vertex program
vfconn main(in vertexInputs IN)
{
  vfconn OUT;
  OUT.Tex4 = float4(0,0,0,0);
  OUT.fogCoord = float3(0,0,0);
  OUT.FogColor = float4(0,0,0,0);

  float4 fogRGBA = float4(0,0,0,0);
  float4x4 modelViewProj = float4x4(1,0,0,0, 0,1,0,0, 0,0,1,0, 0,0,0,1);
  float4x4 Texmatrix = modelViewProj;

  // Compute position
  // compute the 3x3 transform from
  // tangent space to object space
  float4	pos;
  float4	obj_pos;
  float4	world_pos = IN.position;
  float3x3 objToTangentSpace;
  
//  if (BonesCount > 0)
//  {
#ifdef USE_SKINNING
      float4x4	skin_matrix = float4x4(1,0,0,0, 0,1,0,0, 0,0,1,0, 0,0,0,1);;
      float3x3  skin_normal_matrix;  
		  
	  
	  skin_matrix =  IN.texcoords5.x * BonesMatrix[IN.texcoords4.x];
 	  skin_matrix += IN.texcoords5.y * BonesMatrix[IN.texcoords4.y];
 	  skin_matrix += IN.texcoords5.z * BonesMatrix[IN.texcoords4.z];
 	  skin_matrix += IN.texcoords5.w * BonesMatrix[IN.texcoords4.w];
	
	  skin_normal_matrix = float3x3(skin_matrix[0].xyz, skin_matrix[1].xyz, skin_matrix[2].xyz);

	  obj_pos = mul(skin_matrix, IN.position);
	  
	  pos = mul(ModelViewProj, obj_pos);
	  world_pos = mul(MatrixObjectToWorld, obj_pos);
	  
	  objToTangentSpace[0] = normalize(mul(skin_normal_matrix, IN.texcoords1));
	  objToTangentSpace[1] = normalize(mul(skin_normal_matrix, IN.texcoords2));
	  objToTangentSpace[2] = normalize(mul(skin_normal_matrix, IN.texcoords3));
//  }
//  else
//  {
#else 
#ifdef VB_TRANSFORM
	 // world_pos = IN.position;
	  obj_pos.x = dot(IN.texcoords4, float4(IN.position.xyz, 1.0));
	  obj_pos.y = dot(IN.texcoords5, float4(IN.position.xyz, 1.0));
	  obj_pos.z = dot(IN.texcoords6, float4(IN.position.xyz, 1.0));
	  obj_pos.w = 1.0;
	  
	  // transform tbn
	  float3x3  small_normal_matrix;  
	  small_normal_matrix = float3x3(IN.texcoords4.xyz, IN.texcoords5.xyz, IN.texcoords6.xyz);
	  
	  objToTangentSpace[0] = normalize(mul(small_normal_matrix, IN.texcoords1));
	  objToTangentSpace[1] = normalize(mul(small_normal_matrix, IN.texcoords2));
	  objToTangentSpace[2] = normalize(mul(small_normal_matrix, IN.texcoords3));
	  
	  pos = mul(ModelViewProj, obj_pos);
	  
#else
	  obj_pos = IN.position;
	  pos = mul(ModelViewProj, obj_pos);
	  world_pos = mul(MatrixObjectToWorld, obj_pos);
	  objToTangentSpace[0] = normalize(IN.texcoords1);
	  objToTangentSpace[1] = normalize(IN.texcoords2);
	  objToTangentSpace[2] = normalize(IN.texcoords3);
#endif
#endif

  OUT.HPos = pos;
  float2 NewTexCoord = mul(halTextureMatrix0, float4(IN.texcoords0,0,1)).xy;

  OUT.Tex0 = NewTexCoord;
  
  // Convert light direction to tangent space
  float3 LocalLight;

  LocalLight = mul(objToTangentSpace, LightDir);
  OUT.LightDir = (LocalLight);

  OUT.Normal.rgb = float3 (0, 0, 1);

#ifdef USE_SPECULAR
  float3 H = (ViewDir - IN.position.xyz);
  OUT.Tex3 =  (mul(objToTangentSpace, H));
#else
  OUT.Tex3 = float3(0,0,0);
#endif  

	OUT.Tex4 = OUT.HPos;

#ifdef USE_FOG1

  float3 VertexPosition = world_pos.xyz; // mul(MatrixObjectToWorld, IN.position.xyz).xyz;
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
  OUT.FogColor = float4(1.0, 1.0, 1.0, fog);  
  //OUT.Tex1 = (cTexScale*dP + 0.5).xy;
  OUT.fogCoord = float3(dP.x*CosSin.x+dP.y*CosSin.y, dP.x*CosSin.z+dP.y*CosSin.w, -saturate(-dP.z));
  OUT.fogCoord = float3(cTexScale*OUT.fogCoord.xy, -1);
#endif

    OUT.FogColor = saturate(OUT.FogColor); // D3D9 COLOR interpolator clamp
    OUT.Normal = saturate(OUT.Normal); // D3D9 COLOR interpolator clamp
  return OUT;
}

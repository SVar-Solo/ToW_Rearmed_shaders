// D3D11 port of GrassVP_Shadows.hlsl. Generated from the legacy HLSL source; see README.md.
//****************************************************
//Vertex shader for Far grass: pass2 - shadows
//****************************************************

#define PSSM


struct VertexIn
{
  float4 position : POSITION;
};

struct VertexOut
{
  float4 HPOS : SV_Position;
  float4 texCoord0 : TEXCOORD0;    //ShadowMap
  float2 texCoord1 : TEXCOORD1;    //Mask          
  float2 texCoord2 : TEXCOORD2;    //Land
  float2 texCoord3 : TEXCOORD3;    //Grass
};

cbuffer GrassVP_Shadows_CB0 : register(b0)
{
column_major float4x4 ModelViewProj;
column_major float4x4 ShadowMapProjTexMatrix;
//  uniform float  dH,                              //layer dh
float4 S_TexGenVecMain;                 //tex gen vector for main land texture 
float4 T_TexGenVecMain;                 //tex gen vector for main land texture 
float4 S_TexGenVecNoise;                //tex gen vector for noise texture 
float4 T_TexGenVecNoise;                 //tex gen vector for noise texture 

};
VertexOut main(VertexIn IN
			)
{
    VertexOut OUT;

	//---transform vertex to camera space---
    float4 position = IN.position;

//    position.z += dH;
    OUT.HPOS = mul(ModelViewProj, position);

    OUT.texCoord2 = float2( dot(IN.position, S_TexGenVecMain),  dot(IN.position, T_TexGenVecMain));
	OUT.texCoord1 = OUT.texCoord2;

	OUT.texCoord3 = float2( dot(IN.position, S_TexGenVecNoise),  dot(IN.position, T_TexGenVecNoise));

#ifdef PSSM
    OUT.texCoord0 = position;
#else
	OUT.texCoord0 = mul(ShadowMapProjTexMatrix, position);
#endif

    return OUT;
} 

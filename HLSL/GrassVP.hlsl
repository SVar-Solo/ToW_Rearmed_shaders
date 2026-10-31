//****************************************************
//Vertex shader for Far grass: pass1 - without shadows
//****************************************************

struct VertexIn
{
  float4 position : POSITION;
};

struct VertexOut
{
  float4 HPOS : POSITION;
  float2 texCoord0 : TEXCOORD0;    //RoundMaskTex    //dsdt 
  float2 texCoord1 : TEXCOORD1;    //Mask
  float2 texCoord2 : TEXCOORD2;    //Land
  float2 texCoord3 : TEXCOORD3;    //Grass
};

uniform float4x4 ModelViewProj : _GL_MVP;
uniform float3 CamPos;
uniform float  dH;                              //layer dh
uniform float2  dXdY;                           //layer shift in horizontal plane
uniform float MaxRadius;                        //vizibility radius of far grass - really this is only const
uniform float4 S_TexGenVecMain;                 //tex gen vector for main land texture 
uniform float4 T_TexGenVecMain;                 //tex gen vector for main land texture 
uniform float4 S_TexGenVecNoise;                //tex gen vector for noise texture 
uniform float4 T_TexGenVecNoise;                 //tex gen vector for noise texture 

VertexOut main(VertexIn IN
			)
{
    VertexOut OUT;

	//---transform vertex to camera space---
    float4 position = IN.position;
    position.z += dH;
    OUT.HPOS = mul(ModelViewProj, position);

    OUT.texCoord2 = float2( dot(IN.position, S_TexGenVecMain),  dot(IN.position, T_TexGenVecMain));
	OUT.texCoord1 = OUT.texCoord2;
	OUT.texCoord1 += dXdY;

	OUT.texCoord3 = float2( dot(IN.position, S_TexGenVecNoise),  dot(IN.position, T_TexGenVecNoise));

	//calc tex coord for sampling RoundMaskTex
//	const float MaxRadius = 250.0; //200.0;  //here is vizibility radius in [m]
    float2 texCoord0 = 0.5*clamp((IN.position.xy - CamPos.xy)/MaxRadius, -1.0, 1.0) + 0.5;
	OUT.texCoord0 = texCoord0;  

    return OUT;
} 

// D3D11 port of ShadowGrassVP2.hlsl. Generated from the legacy HLSL source; see README.md.
//****************************************************
//Vertex shader for Shadow calculation for Horizontal Grass
//****************************************************

//Attention: define BoundTemplate for handling bounding grass blocks
//Attention: now - without Fog

//#define FULL
//#define BoundTemplate

struct VertexIN
{
    float4 position : POSITION;
#ifdef BoundTemplate
    float2 TEX3 : TEXCOORD3;     
#endif //BoundTemplate
};

struct VertexOUT
{
    float4 COL0 : COLOR0;
    float2 TEX0 : TEXCOORD0;    //horizontal grass texture
    float2 TEX1 : TEXCOORD1;    //land texture
    float4 ScreenPos : TEXCOORD2;    //shadow map texture
    #ifdef BoundTemplate
    float2 TEX3 : TEXCOORD3;    //template mask texture for boundary grass blocks
    #endif  //BoundTemplate
    float4 HPOS : SV_Position;
};

cbuffer ShadowGrassVP2_CB0 : register(b0)
{
column_major float4x4 ModelViewProj;
};
#ifdef FULL
cbuffer ShadowGrassVP2_CB1 : register(b1)
{
	column_major float4x4 ShadowMapProjTexMatrix;
};
#endif //FULL
cbuffer ShadowGrassVP2_CB2 : register(b2)
{
float4 LayerColor;
float LayerDH;
float4 S_TexGenVec;                //tex gen vector for main land texture
float4 T_TexGenVec;                 //tex gen vector for main land texture


};
VertexOUT main(VertexIN IN)                
{
    VertexOUT OUT;

	//---transform vertex to camera space---
    float4 new_position = IN.position;
    new_position.z += LayerDH;
    OUT.HPOS = mul(ModelViewProj, new_position);
	//------------------------------------------

    OUT.COL0 = LayerColor;

    OUT.TEX0 = 0.5 * IN.position.xy;

	float s = dot(S_TexGenVec, IN.position);  
	float t = dot(T_TexGenVec, IN.position);
    OUT.TEX1 = float2(s,t);

    OUT.ScreenPos = OUT.HPOS;


#ifdef BoundTemplate
    OUT.TEX3 = IN.TEX3;
#endif

    OUT.COL0 = saturate(OUT.COL0); // D3D9 COLOR interpolator clamp
    return OUT;
} 

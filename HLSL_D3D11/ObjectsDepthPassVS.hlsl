// D3D11 port of ObjectsDepthPassVS.hlsl. Generated from the legacy HLSL source; see README.md.
struct vertexInputs
{
	float4 position     : POSITION;
	float3 normal       : NORMAL;
	float2 texcoords0   : TEXCOORD0;
	float3 texcoords1   : TEXCOORD1;
	float3 texcoords2   : TEXCOORD2;
	float3 texcoords3   : TEXCOORD3;
#ifdef USE_SKINNING
	float4 texcoords4   : TEXCOORD4; // bones
	float4 texcoords5   : TEXCOORD5; // weights
//	float4 texcoords6   : TEXCOORD6; // weights
#endif
};

struct vfconn
{
    float2 Tex0 : TEXCOORD0;
    float4 zCoord : TEXCOORD1;
    float4 HPos : SV_Position;
};

cbuffer ObjectsDepthPassVS_CB0 : register(b0)
{
column_major float4x4 ModelViewProj;
column_major float4x4 ModelView;
column_major float4x4 halTextureMatrix0;
column_major float4x4 BonesMatrix[40];
                                 
// vertex program
};
vfconn main(in vertexInputs IN
			)
{
  vfconn OUT;
	float4 objpos = float4(IN.position.xyz, 1);
	float4 campos;

	// Compute position
#ifdef USE_SKINNING
	float4x4 skin_matrix;
	skin_matrix =  IN.texcoords5.x * BonesMatrix[IN.texcoords4.x];
	skin_matrix += IN.texcoords5.y * BonesMatrix[IN.texcoords4.y];
	skin_matrix += IN.texcoords5.z * BonesMatrix[IN.texcoords4.z];
	skin_matrix += IN.texcoords5.w * BonesMatrix[IN.texcoords4.w];

	float4 skinned_pos = mul(skin_matrix, objpos);
    float4 pos = mul(ModelViewProj, skinned_pos);
	campos = mul(ModelView, skinned_pos);
#else
#ifdef VB_TRANSFORM
	 // world_pos = IN.position;
	 float4 world_pos;
	  world_pos.x = dot(IN.texcoords4, float4(IN.position.xyz, 1.0));
	  world_pos.y = dot(IN.texcoords5, float4(IN.position.xyz, 1.0));
	  world_pos.z = dot(IN.texcoords6, float4(IN.position.xyz, 1.0));
	  world_pos.w = 1.0;
	   
	  float4 pos = mul(ModelViewProj, world_pos);
	campos = mul(ModelView, world_pos);
#else
	float4 pos = mul(ModelViewProj, objpos);
	campos = mul(ModelView, objpos);
#endif
#endif

  OUT.HPos = pos;
  float2 NewTexCoord = mul(halTextureMatrix0, float4(IN.texcoords0,0,1)).xy;

  OUT.Tex0 = NewTexCoord;
  OUT.zCoord = campos;

  return OUT;
}

struct VertexIN
{
    float4 position : POSITION;
};

struct VertexOUT
{
	float4 HPOS : POSITION;
	float3 TEX0 : TEXCOORD0;
};

uniform float4x4 ModelViewProj : _GL_MVP;
uniform float3 cameraPosition;
uniform float4 CosSin;

VertexOUT main(in VertexIN IN) 
{
	VertexOUT OUT;
	OUT.HPOS = mul(ModelViewProj, float4(cameraPosition+IN.position.xyz, 1.0));
	float3 pos = float3(IN.position.x, IN.position.y, IN.position.z);
	OUT.TEX0 = float3(pos.x*CosSin.x+pos.y*CosSin.y, pos.x*CosSin.z+pos.y*CosSin.w, pos.z);

	return OUT;
} 

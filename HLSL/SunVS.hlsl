struct VertexIN
{
    float4 position : POSITION;
    float2 texcoord : TEXCOORD0;
};

struct VertexOUT
{
	float4 HPOS : POSITION;
	float2 TEX0 : TEXCOORD0;
	float4 color : TEXCOORD1;
};

uniform float4x4 ModelViewProj : _GL_MVP;
uniform float4 realPosition; // pos + size
uniform float4 rescale;
uniform float4 realColor;

VertexOUT main(in VertexIN IN
			) 
{
	VertexOUT OUT;
	OUT.HPOS = mul(ModelViewProj, float4(realPosition.xyz, 1.0));
	OUT.HPOS.xy *= realPosition.w;
	float len = clamp(length(OUT.HPOS.xy/OUT.HPOS.w), 0, 1);	
	float scale = lerp(rescale.z, rescale.w, len);
	OUT.HPOS.xy += IN.position.xy*rescale.xy*OUT.HPOS.w * scale;
	OUT.TEX0 = IN.texcoord;
	OUT.color = realColor;

	return OUT;
} 

struct VertexOUT {
    float2 texCoord : TEXCOORD0;
};

uniform sampler2D TexMap : register(s0);
uniform float2 avSampleOffsets[16];

 // main procedure, the original name was main
float4 main(in VertexOUT IN) : COLOR0
{

	float4 sample = tex2D(TexMap, IN.texCoord + avSampleOffsets[0]);
	for(int i=1;i<16;i++)
	{
		sample += tex2D(TexMap, IN.texCoord + avSampleOffsets[i]);
	}
	sample *= (1.f/16);
	return sample;
} // main end

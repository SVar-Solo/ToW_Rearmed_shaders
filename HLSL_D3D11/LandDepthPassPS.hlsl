// D3D11 port of LandDepthPassPS.hlsl. Generated from the legacy HLSL source; see README.md.
// From vertex shader
struct vfconn
{
	float4 HPos			: SV_Position;	
	float4 zCoord		: TEXCOORD0;
};

Texture2D typeMap : register(t0);
SamplerState typeMap_Sampler : register(s0);

float4 main(in vfconn IN // From vertex shader			
			// ,uniform sampler2D decal: register(s0) // Base texture
			//,out float depth : DEPTH
			) : SV_Target0
{
	// Base
	float4 decalColor; //  = tex2D(decal, IN.TexCoord0.xy);
	//float rz = 0.5*((IN.zCoord.z)/IN.zCoord.w)+0.5;
	float rz = -IN.zCoord.z;
	decalColor.rgb = rz.xxx;
	decalColor.a = 1.0;
	float4 TMColor = typeMap.Sample(typeMap_Sampler, IN.zCoord.xy);
	if (TMColor.a < 1.0f)
	{
		discard;
	}
	return decalColor;
}



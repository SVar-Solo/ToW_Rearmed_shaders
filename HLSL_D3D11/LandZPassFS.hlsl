// D3D11 port of LandZPassFS.hlsl. Generated from the legacy HLSL source; see README.md.
// From vertex shader
struct vfconn
{
	float4 HPos			: SV_Position;	
    float4 zCoord		: TEXCOORD0;
};

float4 main(in vfconn IN // From vertex shader			
			// ,uniform sampler2D decal: register(s0) // Base texture
			//,out float depth : DEPTH
			) : SV_Target0
{
	// Base
	float4 decalColor; //  = tex2D(decal, IN.TexCoord0.xy);
	float rz = 0.5*((IN.zCoord.z)/IN.zCoord.w)+0.5;
	decalColor.rgb = rz.xxx;
	decalColor.a = 1.0;
	//if (decalColor.a < 0.4)
	//{
		//depth = 0.0;
		//discard;
	//}
	return decalColor;
}



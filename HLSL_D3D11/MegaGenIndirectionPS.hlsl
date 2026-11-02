// D3D11 port of MegaGenIndirectionPS.hlsl. Generated from the legacy HLSL source; see README.md.
// From vertex shader
struct VertexOUT
{
	float4 screenpos : TEXCOORD0;
	float4 coord : TEXCOORD1;
};
/*
float MipmapLevel(float2 uv, float2 textureSize)
{
  float2 dx = ddx(uv * textureSize.x);
  float2 dy = ddy(uv * textureSize.y);
  float d = max( dot(dx, dx), dot(dy, dy) );
  return log2( sqrt(d) );
}
*/

//uniform sampler2D LODtex: register(s0); // Base texture
//uniform float lodFarPlane;
cbuffer MegaGenIndirectionPS_CB0 : register(b0)
{
float fScaleDist;

};
float4 main(in VertexOUT IN // From vertex shader
	   ) : SV_Target0
{
	//float2 sspace = ((float2(IN.screenpos.x,IN.screenpos.y)/IN.screenpos.w)*0.5+0.5);
	//sspace *= IN.coord.xy;// * IN.coord.xy;// / sspace;
	//sspace*=float2(1024, 768)/256.f;
	//sspace = float2(1/sspace.x, 1/sspace.y);
	//sspace = float2(sspace.x, sspace.y)/(IN.screenpos.z/2048);
	//sspace = float2(IN.coord.x, IN.coord.y);//*(IN.screenpos.x/IN.screenpos.w);
	//float4 col = tex2D(LODtex, sspace);
	//col.xyz = float3(sspace.xy,0);
	//col.a = saturate(7/255.f-col.a);
	float4 col=float4(0,0,0,1);

	//float2 ccc = float2((IN.screenpos.z)/lodFarPlane, (IN.screenpos.z)/lodFarPlane);
	//float4 col = tex2D(LODtex, ccc);
	
	//float zzz = (IN.screenpos.z/IN.screenpos.w);///lodFarPlane;
	//float4 col = tex2D(LODtex, float2(zzz, zzz));//, zzz, zzz);

	float neardist = 4000*fScaleDist;
	if (IN.screenpos.z<neardist) col.a = 0/255.f;
	else
	if (IN.screenpos.z<2*neardist) col.a = 1/255.f;
	else
	if (IN.screenpos.z<4*neardist) col.a = 2/255.f;
	else
	if (IN.screenpos.z<8*neardist) col.a = 3/255.f;
	else
	if (IN.screenpos.z<16*neardist) col.a = 4/255.f;
	else
	if (IN.screenpos.z<32*neardist) col.a = 5/255.f;
	else
	if (IN.screenpos.z<64*neardist) col.a = 6/255.f;
	else col.a = 7/255.f;

        //float EPS = 24;///IN.screenpos.z;
	//float3 frustum = IN.screenpos.xyz/IN.screenpos.w;
	if (IN.screenpos.z<-17) // || abs(frustum.x)>(1+EPS) || abs(frustum.y)>(1+EPS))
		col = float4(0,0,0,1);
	//col.rgb = float3(frustum.xy,0);
	//col.rgb = (MipmapLevel(ccc, float2(128,128))).xxx/8;
	//col.rgb = IN.screenpos.www/1048;
	return col;
}
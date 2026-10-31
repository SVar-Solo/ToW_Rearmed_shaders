//#define OLD_SHADERS
//#define REFLECTION_VECTOR
//#define SPECULAR
//#undef REFLECTION_VECTOR


struct VertexOut
{	
    float4 NoiseUV		: TEXCOORD0;    // Noise bump texture
	float4 EyeDir_Depth : TEXCOORD1;    // eye dir plus screen depth
	float4 DSDT_Refl	: TEXCOORD2;    // dsdt uv plus reflective uv
	float4 WorldPos		: TEXCOORD3;	// world position
	float4 ScreenPos	: TEXCOORD4;    // reflection texture uv
	float2 absPos	 	: TEXCOORD5;    // Координаты для прозрачности на границах ландшафта
};


float pow16(float v)
{
	v = v*v;
	v = v*v;
	v = v*v;
	return v*v;
}

uniform float4x4	ReflectMatrix;
uniform float4		WaterLightDir;
uniform float4		AmbientColor;
uniform float4		SunDiffuseColor;
uniform float4		SunSpecularColor;
uniform float4		MatOffset;


// R0 is a constant related to the index of refraction (IOR).
// It should be computed on the CPU and passed to the shader.
uniform float R0 = 0.5f;

// The smaller this value is, the more soft the transition between
// shore and water. If you want hard edges use very big value.
// Default is 1.0f.
//uniform float shoreHardness = 1.0f;

// This value modifies current fresnel term. If you want to weaken
// reflections use bigger value. If you want to empasize them use
// value smaller then 0. Default is 0.0f.
uniform float4	WaterReflectiveColor;
uniform float4	WaterSpecularColor;
uniform float4	WaterDiffuseColor;
uniform float4	WaterAmbientColor;
uniform float4	WaterDeepColor;

uniform sampler2D	Tex0: register(s0);       // Noise bump texture
uniform sampler2D	Tex1: register(s1);       // Noise bump texture

uniform samplerCUBE Tex2: register(s2);     //normalization cube map texture

uniform sampler2D	TexDSDT: register(s3);			// Noise bump texture
uniform sampler2D	ReflectionTex: register(s4);       // Noise bump texture
uniform sampler2D	DepthMap: register(s5);       // Noise bump texture


//-----------------------------------------------------------------------------
//	Water parameters
//-----------------------------------------------------------------------------



// Function calculating fresnel term.
// - normal - normalized normal vector
// - eyeVec - normalized eye vector
// float fresnelTerm(float3 normal, float3 eye_vec)
// {
// 	float angle = 1.0f - saturate(dot(normal, eye_vec));
// 	float fresnel = angle * angle;
// 	fresnel = fresnel * fresnel;
// 	fresnel = fresnel * angle;
// 	return saturate(fresnel * (1.0f - saturate(R0)) + R0 - refractionStrength);
//}


//-----------------------------------------------------------------------------
//	main
//-----------------------------------------------------------------------------

float4 main(in VertexOut IN) : COLOR
{
	//float4 cDiffuseWaterColor = float4(0.95f*0.125, 0.85f*0.125, 0.5f*0.125, 0.25f);	

	// read screen depth buffer
	float2 screen_uv = IN.ScreenPos.xy/IN.ScreenPos.w;
	screen_uv.x	= 0.5f * (1.0f + screen_uv.x);
	screen_uv.y	= 0.5f * (1.0f - screen_uv.y);
	
	float screen_depth = tex2D(DepthMap, screen_uv.xy).r;
	//float screen_depth = tex2D(DepthMap, screen_uv.xy + 0.5f*PixelSize).r;
	
	//float depth_delta0 = 8.0f;
	float depth_delta0 = 0.5f;
	float depth_delta = screen_depth - IN.EyeDir_Depth.w;
	float depth_term = clamp(depth_delta/depth_delta0, 0.0, 1.0);
	


	// normal
	float4 Norm0 = 2.0*(tex2D(Tex0, IN.NoiseUV.xy) - 0.5);
	float4 Norm1 = 2.0*(tex2D(Tex1, IN.NoiseUV.zw) - 0.5);

	float3 normal = lerp(Norm1.rgb, Norm0.rgb, WaterLightDir.a);
	float depth_term2 = clamp(depth_delta/8, 0.0, 1.0);
	normal = lerp(float3(0, 0, 1), normal, depth_term2);

	/// need normalize Norm
	float4 light_dir = 2 * WaterLightDir - 1;
	float n_dot_l = dot (normal , -light_dir.xyz); // clamp01

	
	//float3 DiffuseLight = cDiffuseWaterColor.rgb * SunDiffuseColor.rgb * n_dot_l;


	// Eye vector
	float3 eye_dir;
	eye_dir = normalize(IN.EyeDir_Depth.xyz);

	// N . E
	float3 ne = dot(eye_dir.rgb, normal);

	// (N*(N.E) - E/2)*2
	float3 R = (normal * ne + eye_dir.xyz * (-0.5))*2;

	//float Spec = dot(light_dir.xyz, R.rgb);

	//Spec = pow(Spec, 64);
	
	// compute reflection
	float4 DSDT = tex2D(TexDSDT, IN.DSDT_Refl.xy);
	
// 	float2 reflCoord = IN.texcoord4.xy;
// 	float2 newst = float2(reflCoord.x + MatOffset.x * DSDT.x + MatOffset.z * DSDT.y, reflCoord.y + MatOffset.y * DSDT.x + MatOffset.w * DSDT.y);
// 	//float2 newst = reflCoord;
// 	float4 reflection = tex2D(ReflectionTex, newst);

	// compute reflection
    float4 reflect_dir = mul(ReflectMatrix, IN.WorldPos);
	float2 refl_uv = reflect_dir.xy/reflect_dir.w;
	//refl_uv = float2(refl_uv.x + MatOffset.x * DSDT.x + MatOffset.z * DSDT.y, refl_uv.y + MatOffset.y * DSDT.x + MatOffset.w * DSDT.y);
	refl_uv = float2(refl_uv.x + normal.x * DSDT.x + normal.z * normal.y, refl_uv.y + MatOffset.y * normal.x + MatOffset.w * normal.y);
	float4 reflection = tex2D(ReflectionTex, refl_uv);

	//	compute fresnel term
	//float fresnel = fresnelTerm(normal, -eye_dir);
	float fresnel = pow(saturate(1.0f - dot(normal, -eye_dir)), 5); 

	float3 mirror_eye = (2.0f * dot(eye_dir, normal) * normal - eye_dir);

	float spec_term = saturate(dot(mirror_eye.xyz, light_dir) * 0.5f + 0.5f);
	spec_term = pow(spec_term, 512.0f)*WaterSpecularColor.a;

	

	float4 color;
	
	float4 diffuse_color = lerp(WaterAmbientColor, WaterDiffuseColor, saturate(n_dot_l));
	diffuse_color = lerp(diffuse_color, WaterDeepColor, depth_term);

	float3 spec_color = WaterSpecularColor.rgb*SunSpecularColor.rgb*spec_term + fresnel*WaterReflectiveColor.a*reflection.rgb*WaterReflectiveColor.rgb;

	//res = float4(SunSpecularColor.rgb * Spec.xxx + DiffuseLight, WaterLightDir.a);
	


	//float4 res = float4(reflection.rgb, 1);
	//float4 res;
	//res = float4(WaterDiffuseColor.rgb, 1); //  diffuse_color.a);
	// res = float4(water_color, 1);

	//float shoreAlpha = lerp(0.0, diffuse_color.a, depth_term); // 0.3 — прозрачность у берега, diffuse_color.a — в глубине
	//float4 res = float4(diffuse_color.rgb*SunDiffuseColor.rgb + spec_color.rgb, shoreAlpha);
	float4 res = float4(diffuse_color.rgb*SunDiffuseColor.rgb + spec_color.rgb, diffuse_color.a);
	
	float fogBorder1 = 1.0f/8.0f;
	float fogBorder2 = 1.0f - fogBorder1;
	
	if (IN.absPos.x > fogBorder1 && IN.absPos.x < fogBorder2 && IN.absPos.y > fogBorder1 && IN.absPos.y < fogBorder2)
	{
		//Land.a = 1.0f;
	}
	else
	{	
		float alphaX = smoothstep(0.0f, fogBorder1, IN.absPos.x) * (1.0f - smoothstep(fogBorder2, 1.0f, IN.absPos.x));
		float alphaY = smoothstep(0.0f, fogBorder1, IN.absPos.y) * (1.0f - smoothstep(fogBorder2, 1.0f, IN.absPos.y));

		res.a *= alphaX * alphaY;
	}
	
	return res;
}

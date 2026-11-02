#ifndef SPEEDTREE_DEFAULTS_HLSLI
#define SPEEDTREE_DEFAULTS_HLSLI

// Default SpeedTree configuration matching the legacy defines.cg / compile scripts.
// Define SPEEDTREE_CUSTOM_CONFIG before including this file to supply your own set.
#ifndef SPEEDTREE_CUSTOM_CONFIG
#ifndef NUM_WIND_MATRICES
#define NUM_WIND_MATRICES 7
#endif
#ifndef MAX_NUM_LEAF_ANGLES
#define MAX_NUM_LEAF_ANGLES 20
#endif
#ifndef NUM_360_IMAGES
#define NUM_360_IMAGES 32
#endif
#ifndef INTERMEDIATE_FRONDBRANCH_FADING
#define INTERMEDIATE_FRONDBRANCH_FADING
#endif
#ifndef BRANCH_NORMAL_MAPPING
#define BRANCH_NORMAL_MAPPING
#endif
#ifndef FROND_NORMAL_MAPPING
#define FROND_NORMAL_MAPPING
#endif
#ifndef LEAF_NORMAL_MAPPING
#define LEAF_NORMAL_MAPPING
#endif
#ifndef USE_FOG
#define USE_FOG
#endif
#ifndef SELF_SHADOW_LAYER
#define SELF_SHADOW_LAYER
#endif
#ifndef SUPPORT_360_BILLBOARDS
#define SUPPORT_360_BILLBOARDS
#endif
#ifndef BILLBOARD_NORMAL_MAPPING
#define BILLBOARD_NORMAL_MAPPING
#endif
#ifndef USE_SHADOWS
#define USE_SHADOWS
#endif
#endif // SPEEDTREE_CUSTOM_CONFIG

#endif // SPEEDTREE_DEFAULTS_HLSLI

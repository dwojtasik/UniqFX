/*=============================================================================
    UniqFX : Demake
    Version: 2026.09.19
    Author : Dominik Wojtasik
    License: MIT
    Source : https://github.com/dwojtasik/UniqFX

    Simplifies graphics to achieve visuals of game demake by:
    - scaling output into low-resolution and back
    - limiting color pallete and applying dithering
    - old-hardware depth fog
    - flatten lighting, blocky shadows and reduced specular gloss
    - merging nearby high-poly faces (based on depth and normal)
      into one shared plane that fakes low-poly geometry
    - fake distance LOD (minified textures, flatter lighting, coarser vertices)
    - snapping and jittering face intersections like PS1 vertices
    - pixelating & bluring textures

    Preprocessor:
    ENABLE_DEBUG_MODE [0-1] - enables debug view output
    MAX_JOIN_RADIUS [64]    - max available radius for geometry faces join
    MAX_EDGE_FEATHER [32]   - max available edge feather for geometry faces join
    MAX_VERTEX_SNAP [16]    - max vertex snapping, in screen pixels
    MAX_VERTEX_JITTER [4]   - max vertex jitter, in screen pixels
    MAX_TEX_PIXEL [16]      - max pixelization amount for textures
    MAX_TEX_BLUR [8]        - max blur amount for textures

=============================================================================*/

#include "ReShade.fxh"

#ifndef MAX_JOIN_RADIUS
    #define MAX_JOIN_RADIUS 64
#elif MAX_JOIN_RADIUS < 1
    #undef MAX_JOIN_RADIUS
    #define MAX_JOIN_RADIUS 1
#endif
#ifndef MAX_EDGE_FEATHER
    #define MAX_EDGE_FEATHER 32
#elif MAX_EDGE_FEATHER < 1
    #undef MAX_EDGE_FEATHER
    #define MAX_EDGE_FEATHER 1
#endif
#ifndef MAX_VERTEX_SNAP
    #define MAX_VERTEX_SNAP 16
#elif MAX_VERTEX_SNAP < 1
    #undef MAX_VERTEX_SNAP
    #define MAX_VERTEX_SNAP 1
#endif
#ifndef MAX_VERTEX_JITTER
    #define MAX_VERTEX_JITTER 4
#elif MAX_VERTEX_JITTER < 1
    #undef MAX_VERTEX_JITTER
    #define MAX_VERTEX_JITTER 1
#endif
#ifndef MAX_TEX_PIXEL
    #define MAX_TEX_PIXEL 16
#elif MAX_TEX_PIXEL < 1
    #undef MAX_TEX_PIXEL
    #define MAX_TEX_PIXEL 1
#endif
#ifndef MAX_TEX_BLUR
    #define MAX_TEX_BLUR 8
#elif MAX_TEX_BLUR < 1
    #undef MAX_TEX_BLUR
    #define MAX_TEX_BLUR 1
#endif
#ifndef ENABLE_DEBUG_MODE
    #define ENABLE_DEBUG_MODE 0
#endif

/*=============================================================================
    UI
=============================================================================*/

#if ENABLE_DEBUG_MODE
uniform int UI_DEBUG <
    ui_type = "combo";
    ui_label = "Debug View";
    ui_items = "Off\0Normal\0Faces\0Simplified\0";
    ui_category = "General";
> = 0;
#else
static const int UI_DEBUG = 0;
#endif

uniform float UI_RES <
    ui_type = "slider";
    ui_label = "Resolution %";
    ui_tooltip = "Scale the finished image down to % of real resolution.";
    ui_min = 10.0; ui_max = 100.0;
    ui_step = 1.0;
    ui_category = "General";
> = 50.0;

uniform bool UI_COLOR_ON <
    ui_label = "Enable Color Limit";
    ui_tooltip = "Enables selected Color Limit on output.";
    ui_category = "General";
> = true;

uniform float UI_COLORS <
    ui_type = "slider";
    ui_label = "Color Limit";
    ui_tooltip = "Maximum number of allowed colors.\n"
                 "For value of 2 it will use black and white only.";
    ui_min = 2.0; ui_max = 65536.0;
    ui_step = 1.0;
    ui_category = "General";
> = 4096.0;

uniform bool UI_COLOR_DITHER <
    ui_label = "Dithering";
    ui_tooltip = "Enables dithering on output.";
    ui_category = "General";
> = true;

uniform bool UI_FOG_ON <
    ui_label = "Enable Fog";
    ui_tooltip = "Enables linear hardware-style fog from linearized depth.";
    ui_category = "Effects";
> = false;

uniform float UI_FOG_START <
    ui_type = "slider";
    ui_label = "Fog Start";
    ui_tooltip = "Depth where fog begins.";
    ui_min = 0.0; ui_max = 1.0;
    ui_step = 0.01;
    ui_category = "Effects";
> = 0.20;

uniform float UI_FOG_MID <
    ui_type = "slider";
    ui_label = "Fog Mid";
    ui_tooltip = "Depth where fog is half strength.";
    ui_min = 0.0; ui_max = 1.0;
    ui_step = 0.01;
    ui_category = "Effects";
> = 0.50;

uniform float UI_FOG_END <
    ui_type = "slider";
    ui_label = "Fog End";
    ui_tooltip = "Depth where fog is fully opaque.";
    ui_min = 0.0; ui_max = 1.0;
    ui_step = 0.01;
    ui_category = "Effects";
> = 0.80;

uniform float3 UI_FOG_COLOR <
    ui_type = "color";
    ui_label = "Fog Color";
    ui_tooltip = "Fog color to mix with gamebuffer.";
    ui_category = "Effects";
> = float3(0.76, 0.76, 0.73);

uniform float UI_FOG_BANDS <
    ui_type = "slider";
    ui_label = "Fog Banding";
    ui_tooltip = "Number of bands (steps) that fog should have.\n"
                 "0 = continuous fog without bands.";
    ui_min = 0.0; ui_max = 128.0;
    ui_step = 1.0;
    ui_category = "Effects";
> = 128.0;

uniform float UI_FLAT <
    ui_type = "drag";
    ui_label = "Light Flatten";
    ui_tooltip = "Reduces lighting steps, like vertex / Gouraud on old hardware.";
    ui_min = 0.0; ui_max = 1.0;
    ui_step = 0.01;
    ui_category = "Lighting";
> = 0.40;

uniform float UI_SHADOW <
    ui_type = "drag";
    ui_label = "Shadow Block";
    ui_tooltip = "Snap dark regions to a coarse pixel grid of given size so shadows look blocky.";
    ui_min = 0.0; ui_max = 32.0;
    ui_step = 1.0;
    ui_category = "Lighting";
> = 8.0;

uniform float UI_SPEC <
    ui_type = "drag";
    ui_label = "Specular Cut";
    ui_tooltip = "Pull bright highlights toward the local surface so materials look matte.";
    ui_min = 0.0; ui_max = 1.0;
    ui_step = 0.01;
    ui_category = "Lighting";
> = 0.65;

uniform float UI_RADIUS <
    ui_type = "drag";
    ui_label = "Join Radius";
    ui_tooltip = "How far, in pixels, to look for faces to join.";
    ui_min = 1.0; ui_max = MAX_JOIN_RADIUS;
    ui_step = 1.0;
    ui_category = "Geometry";
> = 42.0;

uniform float UI_ANGLE <
    ui_type = "drag";
    ui_label = "Angle Diff";
    ui_tooltip = "Join faces if their normals differ by less than this many degrees.\n"
                 "Larger values produce fewer, blockier faces.";
    ui_min = 0.0; ui_max = 45.0;
    ui_step = 0.5;
    ui_category = "Geometry";
> = 15.0;

uniform float UI_FEATHER <
    ui_type = "drag";
    ui_label = "Edge Feather";
    ui_tooltip = "Fade the face join effect to 0 at object/mesh edges, in pixels.";
    ui_min = 0.0; ui_max = MAX_EDGE_FEATHER;
    ui_step = 1.0;
    ui_category = "Geometry";
> = 0.0;

uniform float UI_SNAP <
    ui_type = "drag";
    ui_label = "Vertex Snapping";
    ui_tooltip = "Snap face-intersection points to a coarse pixel grid, like PS1 vertices.\n"
                 "Facets move with those snapped points.\n"
                 "Set to 0 to disable.";
    ui_min = 0.0; ui_max = MAX_VERTEX_SNAP;
    ui_step = 1.0;
    ui_category = "Geometry";
> = 3.0;

uniform float UI_JITTER <
    ui_type = "drag";
    ui_label = "Vertex Jitter";
    ui_tooltip = "Continuous noise that shoves snapped vertices onto neighboring grid cells.\n"
                 "Tries to simulate behavior from PS1 but in screen-space.\n"
                 "Set to 0 to disable.";
    ui_min = 0.0; ui_max = MAX_VERTEX_JITTER;
    ui_step = 0.05;
    ui_category = "Geometry";
> = 1.5;

uniform float UI_LOD_LEVELS <
    ui_type = "slider";
    ui_label = "Fake LOD Levels";
    ui_tooltip = "Number of fake LOD levels to use.\n"
                 "Each extra level minifies textures on the object, flattens its\n"
                 "shading, and snaps its silhouette harder.\n"
                 "Big flat surfaces (walls, floor, ceiling) and sky are skipped.\n"
                 "Set to 1 to disable LODs as only one will be available.";
    ui_min = 1.0; ui_max = 3.0;
    ui_step = 1.0;
    ui_category = "Geometry";
> = 3.0;

uniform float UI_LOD_START <
    ui_type = "slider";
    ui_label = "Fake LOD Start";
    ui_tooltip = "Depth where fake LOD begins to render simplified objects.";
    ui_min = 0.0; ui_max = 1.0;
    ui_step = 0.01;
    ui_category = "Geometry";
> = 0.10;

uniform float UI_LOD_END <
    ui_type = "slider";
    ui_label = "Fake LOD End";
    ui_tooltip = "At and beyond this depth the strongest extra LOD is used.";
    ui_min = 0.0; ui_max = 1.0;
    ui_step = 0.01;
    ui_category = "Geometry";
> = 0.40;

uniform float UFX_DM_TIMER < source = "timer"; >;

uniform float UI_TEXEL <
    ui_type = "drag";
    ui_label = "Pixelize";
    ui_tooltip = "Snap textures to a chunky grid, in screen pixels.\n"
                 "Stops at depth and face boundaries.";
    ui_min = 0.0; ui_max = MAX_TEX_PIXEL;
    ui_step = 1.0;
    ui_category = "Textures";
> = 4.0;

uniform float UI_TEXBLUR <
    ui_type = "drag";
    ui_label = "Blur";
    ui_tooltip = "Blur textures inside depth and face boundaries.";
    ui_min = 0.0; ui_max = MAX_TEX_BLUR;
    ui_step = 1.0;
    ui_category = "Textures";
> = 1.0;

uniform float UI_GEO_MUL <
    ui_type = "drag";
    ui_label = "Simple Geometry Multiplier";
    ui_tooltip = "Applies changed texture on joined faces (Geometry section):\n"
                 "0 = only flattened-face texture (less detailed).\n"
                 "1 = also apply Pixelize / Blur (more detailed).";
    ui_min = 0.0; ui_max = 1.0;
    ui_step = 0.01;
    ui_category = "Textures";
> = 0.70;

/*=============================================================================
    Textures
=============================================================================*/

texture UFX_DM_PrepTex
{
    Width = BUFFER_WIDTH;
    Height = BUFFER_HEIGHT;
    Format = RGBA16;
};

sampler UFX_DM_PrepSamp
{
    Texture = UFX_DM_PrepTex;
    MinFilter = POINT;
    MagFilter = POINT;
    MipFilter = POINT;
    AddressU = CLAMP;
    AddressV = CLAMP;
};

texture UFX_DM_FaceTex
{
    Width = BUFFER_WIDTH;
    Height = BUFFER_HEIGHT;
    Format = RGBA16;
};

sampler UFX_DM_FaceSamp
{
    Texture = UFX_DM_FaceTex;
    MinFilter = POINT;
    MagFilter = POINT;
    MipFilter = POINT;
    AddressU = CLAMP;
    AddressV = CLAMP;
};

texture UFX_DM_JoinTex
{
    Width = BUFFER_WIDTH;
    Height = BUFFER_HEIGHT;
    Format = RGBA16F;
};

sampler UFX_DM_JoinSamp
{
    Texture = UFX_DM_JoinTex;
    MinFilter = POINT;
    MagFilter = POINT;
    MipFilter = POINT;
    AddressU = CLAMP;
    AddressV = CLAMP;
};

texture UFX_DM_TexTex
{
    Width = BUFFER_WIDTH;
    Height = BUFFER_HEIGHT;
    Format = RGBA16F;
};

sampler UFX_DM_TexSamp
{
    Texture = UFX_DM_TexTex;
    MinFilter = POINT;
    MagFilter = POINT;
    MipFilter = POINT;
    AddressU = CLAMP;
    AddressV = CLAMP;
};

texture UFX_DM_OutTex
{
    Width = BUFFER_WIDTH;
    Height = BUFFER_HEIGHT;
    Format = RGBA16F;
};

sampler UFX_DM_OutSamp
{
    Texture = UFX_DM_OutTex;
    MinFilter = POINT;
    MagFilter = POINT;
    MipFilter = POINT;
    AddressU = CLAMP;
    AddressV = CLAMP;
};

sampler UFX_DM_BackPoint
{
    Texture = ReShade::BackBufferTex;
    MinFilter = POINT;
    MagFilter = POINT;
    MipFilter = POINT;
    AddressU = CLAMP;
    AddressV = CLAMP;
};

/*=============================================================================
    Common
=============================================================================*/

static const float3 UFX_DM_LUMA = float3(0.2126, 0.7152, 0.0722);
static const float UFX_DM_HARD_DOT = 0.57357643635; // cos(55°)
static const float UFX_DM_FACE_DOT = 0.98;
static const float UFX_DM_PLANAR_DOT = 0.99756405026; // cos(4°)
static const float UFX_DM_CREASE_DOT = 0.88294759286; // cos(28°)
static const float UFX_DM_SKY = 0.985;
static const float2 UFX_DM_DIR4[4] =
{
    float2(1.0, 0.0), float2(-1.0, 0.0),
    float2(0.0, 1.0), float2(0.0, -1.0)
};
static const float2 UFX_DM_DIR8[8] =
{
    float2( 1.0,  0.0), float2(-1.0,  0.0),
    float2( 0.0,  1.0), float2( 0.0, -1.0),
    float2( 1.0,  1.0), float2(-1.0,  1.0),
    float2( 1.0, -1.0), float2(-1.0, -1.0)
};
static const float4x4 UFX_DM_BAYER4 = float4x4(
     0.0 / 16.0,  8.0 / 16.0,  2.0 / 16.0, 10.0 / 16.0,
    12.0 / 16.0,  4.0 / 16.0, 14.0 / 16.0,  6.0 / 16.0,
     3.0 / 16.0, 11.0 / 16.0,  1.0 / 16.0,  9.0 / 16.0,
    15.0 / 16.0,  7.0 / 16.0, 13.0 / 16.0,  5.0 / 16.0
);

float ufx_dm_luma(float3 c)
{
    return dot(c, UFX_DM_LUMA);
}

float3 ufx_dm_clip_rgb(float3 c)
{
    float peak = max(c.r, max(c.g, c.b));
    if (peak > 1.0)
        c /= peak;
    return saturate(c);
}

float3 ufx_dm_relight(float3 orig, float new_luma)
{
    float l0 = ufx_dm_luma(orig);
    return ufx_dm_clip_rgb((orig / max(l0, 0.06)) * new_luma);
}

float3 ufx_dm_apply_light(float3 crunch, float face_luma, float local_luma)
{
    return ufx_dm_clip_rgb(crunch * (face_luma / max(local_luma, 0.06)));
}

float ufx_dm_bayer(float2 uv)
{
    int2 p = int2(floor(uv * BUFFER_SCREEN_SIZE)) & 3;
    return UFX_DM_BAYER4[p.y][p.x];
}

float ufx_dm_qchan(float v, float levels, float dither)
{
    float r = 0.5;
    if (levels >= 1.5)
    {
        float s = levels - 1.0;
        v = saturate(v + dither / s);
        r = round(v * s) / s;
    }
    return r;
}

float3 ufx_dm_color_limit(float3 c, float2 uv)
{
    float3 r = c;
    float dither = UI_COLOR_DITHER ? (ufx_dm_bayer(uv) - 0.5) : 0.0;

    if (UI_COLOR_ON)
    {
        float n = clamp(floor(UI_COLORS + 0.5), 2.0, 65536.0);

        if (n < 2.5)
        {
            float l = ufx_dm_luma(c) + dither;
            r = (l >= 0.5) ? float3(1.0, 1.0, 1.0) : float3(0.0, 0.0, 0.0);
        }
        else
        {
            float s = max(1.0, floor(pow(n, 1.0 / 3.0) + 1e-4));
            float sr = s;
            float sb = s;
            float sg = max(1.0, floor(n / max(sr * sb, 1.0)));
            r = saturate(float3(
                ufx_dm_qchan(c.r, sr, dither),
                ufx_dm_qchan(c.g, sg, dither),
                ufx_dm_qchan(c.b, sb, dither)));
        }
    }
    else if (UI_COLOR_DITHER)
    {
        r = saturate(c + dither / 32.0);
    }

    return r;
}

float ufx_dm_fog_factor(float d)
{
    float s = UI_FOG_START;
    float m = UI_FOG_MID;
    float e = UI_FOG_END;
    float f;

    if (d <= s)
        f = 0.0;
    else if (d >= e)
        f = 1.0;
    else if (d <= m)
        f = 0.5 * saturate((d - s) / max(m - s, 1e-4));
    else
        f = 0.5 + 0.5 * saturate((d - m) / max(e - m, 1e-4));

    float n = floor(UI_FOG_BANDS + 0.5);
    if (n >= 1.0)
        f = floor(f * n + 1e-4) / n;

    return f;
}

float3 ufx_dm_apply_fog(float3 c, float d)
{
    if (!UI_FOG_ON)
        return c;
    return lerp(c, UI_FOG_COLOR, ufx_dm_fog_factor(d));
}

float ufx_dm_min_dot()
{
    return cos(clamp(UI_ANGLE, 0.0, 89.0) * 0.01745329251);
}

int ufx_dm_lod_level(float d)
{
    float n = floor(UI_LOD_LEVELS + 0.5);
    if (n < 1.5)
        return 0;

    float s = saturate(UI_LOD_START);
    float e = saturate(UI_LOD_END);
    if (e < s)
    {
        float tmp = s;
        s = e;
        e = tmp;
    }

    if (d < s)
        return 0;

    float span = e - s;
    if (span < 1e-4)
        return (int)n;

    float step = span / n;
    int lod = (int)floor((d - s) / step) + 1;
    if (d >= e)
        return (int)n;
    return min(lod, (int)n);
}

int ufx_dm_light_n()
{
    return (int)clamp(max(UI_TEXEL, 1.0) * 2.0, 4.0, 16.0);
}

bool ufx_dm_same_depth(float a, float b)
{
    return abs(a - b) < lerp(0.0015, 0.03, max(a, b));
}

float3 ufx_dm_normal_signed(float2 texcoord, float d_center)
{
    float3 offset = float3(BUFFER_PIXEL_SIZE, 0.0);
    float2 posNorth = texcoord - offset.zy;
    float2 posEast  = texcoord + offset.xz;

    float3 vertCenter = float3(texcoord - 0.5, 1.0) * d_center;
    float3 vertNorth  = float3(posNorth  - 0.5, 1.0) * ReShade::GetLinearizedDepth(posNorth);
    float3 vertEast   = float3(posEast   - 0.5, 1.0) * ReShade::GetLinearizedDepth(posEast);

    return normalize(cross(vertCenter - vertNorth, vertCenter - vertEast));
}

float3 ufx_dm_normal_view(float2 texcoord)
{
    return ufx_dm_normal_signed(texcoord, ReShade::GetLinearizedDepth(texcoord)) * 0.5 + 0.5;
}

float2 ufx_dm_oct_pack(float3 n)
{
    n /= max(abs(n.x) + abs(n.y) + abs(n.z), 1e-8);
    if (n.z < 0.0)
        n.xy = (1.0 - abs(n.yx)) * (step(0.0, n.xy) * 2.0 - 1.0);
    return n.xy * 0.5 + 0.5;
}

float3 ufx_dm_oct_unpack(float2 e)
{
    e = e * 2.0 - 1.0;
    float3 n = float3(e.x, e.y, 1.0 - abs(e.x) - abs(e.y));
    float t = saturate(-n.z);
    n.xy += (n.xy >= 0.0) ? -t : t;
    return n * rsqrt(max(dot(n, n), 1e-8));
}

float3 ufx_dm_snap(float3 n, float ang)
{
    float k = 180.0 / max(ang, 1.0);
    float3 q = round(n * k) / k;
    float len2 = dot(q, q);
    return len2 > 1e-8 ? q * rsqrt(len2) : n;
}

float4 ufx_dm_prep(float2 uv)
{
    return tex2Dlod(UFX_DM_PrepSamp, float4(uv, 0.0, 0.0));
}

bool ufx_dm_arch_hit(float4 g0, float3 n0, float2 uv1)
{
    float4 g1 = ufx_dm_prep(uv1);
    if (g1.b > UFX_DM_SKY)
        return false;
    return ufx_dm_same_depth(g0.b, g1.b) &&
        dot(n0, ufx_dm_oct_unpack(g1.rg)) >= 0.985;
}

bool ufx_dm_is_arch(float4 g0, float3 n0, float2 uv)
{
    if (g0.b > UFX_DM_SKY)
        return true;

    float2 o = 32.0 * BUFFER_PIXEL_SIZE;
    int n = 0;
    if (ufx_dm_arch_hit(g0, n0, uv + float2(o.x, 0.0))) n++;
    if (ufx_dm_arch_hit(g0, n0, uv - float2(o.x, 0.0))) n++;
    if (ufx_dm_arch_hit(g0, n0, uv + float2(0.0, o.y))) n++;
    if (ufx_dm_arch_hit(g0, n0, uv - float2(0.0, o.y))) n++;
    return n >= 3;
}

float3 ufx_dm_out(float2 uv)
{
    return tex2Dlod(UFX_DM_OutSamp, float4(uv, 0.0, 0.0)).rgb;
}

bool ufx_dm_lit_ok_d(float d0, float2 uv1)
{
    float d1 = ufx_dm_prep(uv1).b;
    if (d0 > UFX_DM_SKY || d1 > UFX_DM_SKY)
        return false;
    return ufx_dm_same_depth(d0, d1);
}

float ufx_dm_luma_out(float2 uv)
{
    return ufx_dm_luma(ufx_dm_out(uv));
}

float4 ufx_dm_face(float2 uv)
{
    return tex2Dlod(UFX_DM_FaceSamp, float4(uv, 0.0, 0.0));
}

float3 ufx_dm_sample_fogged(float2 uv_tex)
{
    float3 c = tex2Dlod(UFX_DM_TexSamp, float4(uv_tex, 0.0, 0.0)).rgb;
    if (!UI_FOG_ON)
        return c;
    return ufx_dm_apply_fog(c, ufx_dm_face(uv_tex).b);
}

bool ufx_dm_lod_obj(float4 gb, int lod)
{
    return lod >= 1 && gb.a >= 0.5 && gb.b <= UFX_DM_SKY;
}

float3 ufx_dm_back(float2 uv)
{
    return tex2Dlod(UFX_DM_BackPoint, float4(uv, 0.0, 0.0)).rgb;
}

void ufx_dm_lod_acc_back(float2 uv, float4 gb, float3 n0, inout float3 acc, inout float w)
{
    float4 g1 = ufx_dm_face(uv);
    if (g1.a < 0.5)
        return;
    if (!ufx_dm_same_depth(gb.b, g1.b))
        return;
    if (dot(n0, ufx_dm_oct_unpack(g1.rg)) < UFX_DM_FACE_DOT)
        return;
    acc += ufx_dm_back(uv);
    w += 1.0;
}

float3 ufx_dm_lod_mip(float2 uv, float4 gb, float3 n0, int lod)
{
    float3 acc = ufx_dm_back(uv);
    float w = 1.0;
    float step = 3.0 + 2.0 * (float)lod;
    int rings = min(lod + 1, 3);

    [loop]
    for (int r = 1; r <= 3; r++)
    {
        if (r > rings)
            break;
        float2 s = (step * (float)r) * BUFFER_PIXEL_SIZE;
        ufx_dm_lod_acc_back(uv + float2(s.x, 0.0), gb, n0, acc, w);
        ufx_dm_lod_acc_back(uv - float2(s.x, 0.0), gb, n0, acc, w);
        ufx_dm_lod_acc_back(uv + float2(0.0, s.y), gb, n0, acc, w);
        ufx_dm_lod_acc_back(uv - float2(0.0, s.y), gb, n0, acc, w);
        if (lod < 2)
            continue;
        ufx_dm_lod_acc_back(uv + float2(s.x, s.y), gb, n0, acc, w);
        ufx_dm_lod_acc_back(uv + float2(-s.x, s.y), gb, n0, acc, w);
        ufx_dm_lod_acc_back(uv + float2(s.x, -s.y), gb, n0, acc, w);
        ufx_dm_lod_acc_back(uv + float2(-s.x, -s.y), gb, n0, acc, w);
    }

    return acc / max(w, 1.0);
}

float4 ufx_dm_tex4(float2 uv)
{
    return tex2Dlod(UFX_DM_TexSamp, float4(uv, 0.0, 0.0));
}

float ufx_dm_join(float2 uv)
{
    return tex2Dlod(UFX_DM_JoinSamp, float4(uv, 0.0, 0.0)).r;
}

bool ufx_dm_is_edge_sample(float d0, float3 n0, float2 uv1, float crease_dot)
{
    float4 g1 = ufx_dm_prep(uv1);
    if (!ufx_dm_same_depth(d0, g1.b))
        return true;
    return dot(n0, ufx_dm_oct_unpack(g1.rg)) < crease_dot;
}

float ufx_dm_edge_fade(float2 uv, float d0, float3 n0)
{
    float feather = clamp(UI_FEATHER, 0.0, (float)MAX_EDGE_FEATHER);
    if (feather < 0.5)
        return 1.0;
    float crease_dot = min(ufx_dm_min_dot(), UFX_DM_CREASE_DOT);
    float dist = feather;

    [loop]
    for (int i = 1; i <= MAX_EDGE_FEATHER; i++)
    {
        float di = (float)i;
        if (di > feather)
            break;
        for (int k = 0; k < 8; k++)
        {
            float2 stepv = UFX_DM_DIR8[k] * (di * BUFFER_PIXEL_SIZE);
            if (ufx_dm_is_edge_sample(d0, n0, uv + stepv, crease_dot))
            {
                float hit = (k < 4) ? (di - 1.0) : ((di - 1.0) * 1.41421356);
                dist = min(dist, hit);
            }
        }
    }

    return saturate(dist / max(feather, 1.0));
}

bool ufx_dm_same_face_n(float4 g0, float3 n0, float4 g1)
{
    if (g1.a < 0.5)
        return false;
    if (!ufx_dm_same_depth(g0.b, g1.b))
        return false;
    return dot(n0, ufx_dm_oct_unpack(g1.rg)) >= UFX_DM_FACE_DOT;
}

bool ufx_dm_bound(float4 g0, float3 n0, float2 uv1, float min_dot)
{
    float4 g1 = ufx_dm_face(uv1);
    if (g0.b > UFX_DM_SKY || g1.b > UFX_DM_SKY)
        return false;
    if (!ufx_dm_same_depth(g0.b, g1.b))
        return false;
    return dot(n0, ufx_dm_oct_unpack(g1.rg)) >= min_dot;
}

void ufx_dm_accum(float2 uv, float dist_px, float d0, float3 n0, float min_dot, float planar_dot, float hard_dot,
    inout float3 acc, inout float planar_n, inout float planar_ok, inout float big_n, inout float hard)
{
    float4 g1 = ufx_dm_prep(uv);
    if (!ufx_dm_same_depth(d0, g1.b))
    {
        if (dist_px <= 2.0)
            hard = 1.0;
        return;
    }

    float3 n1 = ufx_dm_oct_unpack(g1.rg);
    float nd = dot(n0, n1);

    if (dist_px <= 2.0 && nd < hard_dot)
        hard = 1.0;

    if (nd < hard_dot)
        return;

    big_n += 1.0;
    planar_n += 1.0;
    planar_ok += nd >= planar_dot ? 1.0 : 0.0;

    if (nd < min_dot)
        return;

    acc += n1;
}

void ufx_dm_accum_far(float2 uv, float d0, float3 n0, float min_dot, float planar_dot, float hard_dot,
    inout float3 acc, inout float planar_n, inout float planar_ok, inout float big_n)
{
    float4 g1 = ufx_dm_prep(uv);
    if (!ufx_dm_same_depth(d0, g1.b))
        return;

    float3 n1 = ufx_dm_oct_unpack(g1.rg);
    float nd = dot(n0, n1);

    if (nd < hard_dot)
        return;

    big_n += 1.0;
    planar_n += 1.0;
    planar_ok += nd >= planar_dot ? 1.0 : 0.0;

    if (nd < min_dot)
        return;

    acc += n1;
}

float ufx_dm_gather_light(float2 uv, float2 axis, float l0)
{
    float4 g0 = ufx_dm_face(uv);
    if (g0.a < 0.5)
        return l0;

    float3 n0 = ufx_dm_oct_unpack(g0.rg);
    float r = clamp(UI_RADIUS, 1.0, (float)MAX_JOIN_RADIUS);
    float acc = l0;
    float wsum = 1.0;
    float2 step_uv = axis * BUFFER_PIXEL_SIZE;

    [loop]
    for (int i = 1; i <= MAX_JOIN_RADIUS; i++)
    {
        if ((float)i > r)
            break;
        float2 o = step_uv * (float)i;
        float2 uv1 = uv + o;
        if (ufx_dm_same_face_n(g0, n0, ufx_dm_face(uv1)))
        {
            acc += ufx_dm_tex4(uv1).a;
            wsum += 1.0;
        }
        uv1 = uv - o;
        if (ufx_dm_same_face_n(g0, n0, ufx_dm_face(uv1)))
        {
            acc += ufx_dm_tex4(uv1).a;
            wsum += 1.0;
        }
    }

    return acc / max(wsum, 1e-4);
}

float ufx_dm_hash11(float2 p)
{
    return frac(sin(dot(p, float2(127.1, 311.7))) * 43758.5453);
}

float ufx_dm_vnoise(float2 p)
{
    float2 i = floor(p);
    float2 f = frac(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = ufx_dm_hash11(i);
    float b = ufx_dm_hash11(i + float2(1.0, 0.0));
    float c = ufx_dm_hash11(i + float2(0.0, 1.0));
    float d = ufx_dm_hash11(i + float2(1.0, 1.0));
    return lerp(lerp(a, b, f.x), lerp(c, d, f.x), f.y);
}

float2 ufx_dm_place_vertex(float2 uv, float snap, float jit)
{
    float2 v = uv * BUFFER_SCREEN_SIZE;

    if (jit >= 1e-3)
    {
        float z = max(saturate(ReShade::GetLinearizedDepth(uv)), 1e-4);
        float t = UFX_DM_TIMER * 0.001;
        float2 vs = (uv - 0.5) / z;
        float2 q = vs * 5.0 + float2(t * 0.35, t * 0.28);
        float2 n = float2(ufx_dm_vnoise(q), ufx_dm_vnoise(q + float2(19.2, 7.3)));
        v += (n * 2.0 - 1.0) * jit;
    }

    if (snap >= 0.5)
        v = floor(v / snap + 0.5) * snap;
    else if (jit >= 1e-3)
        v = floor(v + 0.5);

    return v * BUFFER_PIXEL_SIZE;
}

float2 ufx_dm_face_edge(float2 uv, float2 axis, float4 g0, float3 n0, float min_dot, int n, float step_px, out bool hit)
{
    hit = false;
    float2 last = uv;
    float2 step_uv = axis * step_px * BUFFER_PIXEL_SIZE;

    [loop]
    for (int i = 1; i <= MAX_VERTEX_SNAP; i++)
    {
        if (i > n)
            break;
        float2 uv1 = uv + step_uv * (float)i;
        float4 g1 = ufx_dm_face(uv1);
        if (g1.b > UFX_DM_SKY || !ufx_dm_same_depth(g0.b, g1.b) ||
            dot(n0, ufx_dm_oct_unpack(g1.rg)) < min_dot)
        {
            hit = true;
            return last;
        }
        last = uv1;
    }

    return last;
}

void ufx_dm_warp_axis(float2 uv, float2 a, float2 b, bool ha, bool hb,
    float snap, float jit, inout float2 acc, inout float w)
{
    if (ha && hb)
    {
        float2 ab = (b - a) * BUFFER_SCREEN_SIZE;
        float t = saturate(dot((uv - a) * BUFFER_SCREEN_SIZE, ab) / max(dot(ab, ab), 1e-4));
        acc += lerp(ufx_dm_place_vertex(a, snap, jit), ufx_dm_place_vertex(b, snap, jit), t);
        w += 1.0;
    }
    else if (ha)
    {
        acc += uv + (ufx_dm_place_vertex(a, snap, jit) - a);
        w += 1.0;
    }
    else if (hb)
    {
        acc += uv + (ufx_dm_place_vertex(b, snap, jit) - b);
        w += 1.0;
    }
}

float2 ufx_dm_warp_uv(float2 uv)
{
    if (UI_SNAP < 0.5 && UI_JITTER < 1e-3 && UI_LOD_LEVELS < 1.5)
        return uv;

    float4 g0 = ufx_dm_face(uv);
    if (g0.b > UFX_DM_SKY)
        return uv;

    float3 n0 = ufx_dm_oct_unpack(g0.rg);
    int lod = ufx_dm_lod_level(g0.b);
    bool lod_obj = ufx_dm_lod_obj(g0, lod);
    float snap = UI_SNAP;
    float jit = UI_JITTER;
    if (lod_obj)
    {
        snap = max(snap, 3.0 * (float)lod);
        jit = max(jit, 0.4 * (float)lod);
    }
    if (snap < 0.5 && jit < 1e-3)
        return uv;

    float min_dot = g0.a >= 0.5 ? UFX_DM_FACE_DOT : UFX_DM_HARD_DOT;
    float step_px = max(snap, 1.0);
    int n = (int)clamp(ceil((float)MAX_VERTEX_SNAP / step_px), 1.0, (float)MAX_VERTEX_SNAP);

    bool hl = false;
    bool hr = false;
    bool hu = false;
    bool hd = false;
    float2 left  = ufx_dm_face_edge(uv, float2(-1.0,  0.0), g0, n0, min_dot, n, step_px, hl);
    float2 right = ufx_dm_face_edge(uv, float2( 1.0,  0.0), g0, n0, min_dot, n, step_px, hr);
    float2 up    = ufx_dm_face_edge(uv, float2( 0.0, -1.0), g0, n0, min_dot, n, step_px, hu);
    float2 down  = ufx_dm_face_edge(uv, float2( 0.0,  1.0), g0, n0, min_dot, n, step_px, hd);

    float2 acc = 0.0;
    float w = 0.0;
    ufx_dm_warp_axis(uv, left, right, hl, hr, snap, jit, acc, w);
    ufx_dm_warp_axis(uv, up, down, hu, hd, snap, jit, acc, w);
    if (w >= 0.5)
        return acc / w;
    return uv;
}

/*=============================================================================
    Passes
=============================================================================*/

float4 PS_Prep(float4 pos : SV_Position, float2 uv : TEXCOORD) : SV_Target
{
    float d_raw = ReShade::GetLinearizedDepth(uv);
    float d = saturate(d_raw);
    return float4(ufx_dm_oct_pack(ufx_dm_normal_signed(uv, d_raw)), d, 1.0);
}

float4 PS_Face(float4 pos : SV_Position, float2 uv : TEXCOORD) : SV_Target
{
    float4 g0 = ufx_dm_prep(uv);
    float3 n0 = ufx_dm_oct_unpack(g0.rg);

    if (g0.b > UFX_DM_SKY)
        return float4(ufx_dm_oct_pack(n0), g0.b, 0.0);

    if (UI_ANGLE < 0.5)
        return float4(ufx_dm_oct_pack(n0), g0.b, 0.0);

    if (ufx_dm_lod_level(g0.b) > 0 && ufx_dm_is_arch(g0, n0, uv))
        return float4(ufx_dm_oct_pack(n0), g0.b, 0.0);

    float r = clamp(UI_RADIUS, 1.0, (float)MAX_JOIN_RADIUS);
    float min_dot = ufx_dm_min_dot();
    float planar_dot = UFX_DM_PLANAR_DOT;
    float hard_dot = UFX_DM_HARD_DOT;

    float3 acc = n0;
    float planar_n = 0.0;
    float planar_ok = 0.0;
    float big_n = 0.0;
    float hard = 0.0;

    float2 px = BUFFER_PIXEL_SIZE;
    if (r >= 1.0)
    {
        ufx_dm_accum(uv + float2(px.x, 0.0), 1.0, g0.b, n0, min_dot, planar_dot, hard_dot, acc, planar_n, planar_ok, big_n, hard);
        ufx_dm_accum(uv - float2(px.x, 0.0), 1.0, g0.b, n0, min_dot, planar_dot, hard_dot, acc, planar_n, planar_ok, big_n, hard);
        ufx_dm_accum(uv + float2(0.0, px.y), 1.0, g0.b, n0, min_dot, planar_dot, hard_dot, acc, planar_n, planar_ok, big_n, hard);
        ufx_dm_accum(uv - float2(0.0, px.y), 1.0, g0.b, n0, min_dot, planar_dot, hard_dot, acc, planar_n, planar_ok, big_n, hard);
    }
    if (r >= 2.0)
    {
        float2 d2 = 2.0 * px;
        ufx_dm_accum(uv + float2(d2.x, 0.0), 2.0, g0.b, n0, min_dot, planar_dot, hard_dot, acc, planar_n, planar_ok, big_n, hard);
        ufx_dm_accum(uv - float2(d2.x, 0.0), 2.0, g0.b, n0, min_dot, planar_dot, hard_dot, acc, planar_n, planar_ok, big_n, hard);
        ufx_dm_accum(uv + float2(0.0, d2.y), 2.0, g0.b, n0, min_dot, planar_dot, hard_dot, acc, planar_n, planar_ok, big_n, hard);
        ufx_dm_accum(uv - float2(0.0, d2.y), 2.0, g0.b, n0, min_dot, planar_dot, hard_dot, acc, planar_n, planar_ok, big_n, hard);
    }

    [loop]
    for (int i = 3; i <= MAX_JOIN_RADIUS; i++)
    {
        if ((float)i > r)
            break;

        float2 d = (float)i * px;
        ufx_dm_accum_far(uv + float2(d.x, 0.0), g0.b, n0, min_dot, planar_dot, hard_dot, acc, planar_n, planar_ok, big_n);
        ufx_dm_accum_far(uv - float2(d.x, 0.0), g0.b, n0, min_dot, planar_dot, hard_dot, acc, planar_n, planar_ok, big_n);
        ufx_dm_accum_far(uv + float2(0.0, d.y), g0.b, n0, min_dot, planar_dot, hard_dot, acc, planar_n, planar_ok, big_n);
        ufx_dm_accum_far(uv - float2(0.0, d.y), g0.b, n0, min_dot, planar_dot, hard_dot, acc, planar_n, planar_ok, big_n);
    }

    bool big_surface = big_n > max(40.0, r * 2.0);
    bool large_plane = planar_n > 8.0 && (planar_ok / max(planar_n, 1.0)) > 0.85;
    if ((big_surface && large_plane) || (big_surface && hard > 0.5))
        return float4(ufx_dm_oct_pack(n0), g0.b, 0.0);

    float3 n_avg = acc * rsqrt(max(dot(acc, acc), 1e-8));
    return float4(ufx_dm_oct_pack(ufx_dm_snap(n_avg, UI_ANGLE)), g0.b, 1.0);
}

float4 PS_LightH(float4 pos : SV_Position, float2 uv : TEXCOORD) : SV_Target
{
    float l0 = ufx_dm_luma(ufx_dm_back(uv));
#if ENABLE_DEBUG_MODE
    if (UI_DEBUG != 0)
        return float4(l0, 0.0, 0.0, 1.0);
#endif

    float4 g0 = ufx_dm_face(uv);
    if (g0.b > UFX_DM_SKY)
        return float4(l0, 0.0, 0.0, 1.0);

    float3 n0 = ufx_dm_oct_unpack(g0.rg);
    int n = ufx_dm_light_n();
    float acc = l0;
    float wsum = 1.0;

    [loop]
    for (int i = 1; i <= 16; i++)
    {
        if (i > n)
            break;
        float2 o = float2((float)i * BUFFER_PIXEL_SIZE.x, 0.0);
        float2 uv1 = uv + o;
        if (ufx_dm_bound(g0, n0, uv1, UFX_DM_HARD_DOT))
        {
            acc += ufx_dm_luma(ufx_dm_back(uv1));
            wsum += 1.0;
        }
        uv1 = uv - o;
        if (ufx_dm_bound(g0, n0, uv1, UFX_DM_HARD_DOT))
        {
            acc += ufx_dm_luma(ufx_dm_back(uv1));
            wsum += 1.0;
        }
    }

    return float4(acc / max(wsum, 1.0), 0.0, 0.0, 1.0);
}

float4 PS_Tex(float4 pos : SV_Position, float2 uv : TEXCOORD) : SV_Target
{
    float3 orig = ufx_dm_back(uv);
    float light = ufx_dm_join(uv);

#if ENABLE_DEBUG_MODE
    if (UI_DEBUG != 0)
        return float4(orig, light);
#endif

    float4 gb = ufx_dm_face(uv);
    if (gb.b > UFX_DM_SKY)
        return float4(orig, light);

    float3 n0 = ufx_dm_oct_unpack(gb.rg);
    int ln = ufx_dm_light_n();
    float lacc = light;
    float lw = 1.0;

    [loop]
    for (int i = 1; i <= 16; i++)
    {
        if (i > ln)
            break;
        float2 o = float2(0.0, (float)i * BUFFER_PIXEL_SIZE.y);
        float2 uv1 = uv + o;
        if (ufx_dm_bound(gb, n0, uv1, UFX_DM_HARD_DOT))
        {
            lacc += ufx_dm_join(uv1);
            lw += 1.0;
        }
        uv1 = uv - o;
        if (ufx_dm_bound(gb, n0, uv1, UFX_DM_HARD_DOT))
        {
            lacc += ufx_dm_join(uv1);
            lw += 1.0;
        }
    }

    light = lacc / max(lw, 1.0);

    int lod = ufx_dm_lod_level(gb.b);
    bool lod_obj = ufx_dm_lod_obj(gb, lod);
    float pixel = max(UI_TEXEL, 0.0);
    float blur = max(UI_TEXBLUR, 0.0);
    float3 crunch = orig;
    float tex_dot = gb.a >= 0.5 ? UFX_DM_HARD_DOT : UFX_DM_FACE_DOT;

    if (lod_obj)
        crunch = ufx_dm_lod_mip(uv, gb, n0, lod);
    else if (pixel >= 0.5 || blur >= 0.5)
    {
        float cell = max(pixel, 1.0);
        float2 grid = floor(uv * BUFFER_SCREEN_SIZE / cell);
        float2 uv_cell = (grid + 0.5) * cell * BUFFER_PIXEL_SIZE;
        if (pixel < 0.5 || !ufx_dm_bound(gb, n0, uv_cell, tex_dot))
            uv_cell = uv;

        crunch = ufx_dm_back(uv_cell);
        int br = (int)blur;
        if (br > 0)
        {
            float3 acc = crunch;
            float wsum = 1.0;
            float2 step_uv = cell * BUFFER_PIXEL_SIZE;
            int n = min(br, MAX_TEX_BLUR);

            [loop]
            for (int j = 1; j <= MAX_TEX_BLUR; j++)
            {
                if (j > n)
                    break;
                float fj = (float)j;
                float2 u1 = uv_cell + float2(fj, 0.0) * step_uv;
                if (ufx_dm_bound(gb, n0, u1, tex_dot)) { acc += ufx_dm_back(u1); wsum += 1.0; }
                u1 = uv_cell - float2(fj, 0.0) * step_uv;
                if (ufx_dm_bound(gb, n0, u1, tex_dot)) { acc += ufx_dm_back(u1); wsum += 1.0; }
                u1 = uv_cell + float2(0.0, fj) * step_uv;
                if (ufx_dm_bound(gb, n0, u1, tex_dot)) { acc += ufx_dm_back(u1); wsum += 1.0; }
                u1 = uv_cell - float2(0.0, fj) * step_uv;
                if (ufx_dm_bound(gb, n0, u1, tex_dot)) { acc += ufx_dm_back(u1); wsum += 1.0; }
            }

            crunch = acc / max(wsum, 1.0);
        }
    }

    return float4(crunch, light);
}

float4 PS_JoinH(float4 pos : SV_Position, float2 uv : TEXCOORD) : SV_Target
{
    float l = ufx_dm_tex4(uv).a;
#if ENABLE_DEBUG_MODE
    if (UI_DEBUG != 0)
        return float4(l, 0.0, 0.0, 1.0);
#endif
    if (UI_ANGLE < 0.5 && UI_LOD_LEVELS < 1.5)
        return float4(l, 0.0, 0.0, 1.0);
    return float4(ufx_dm_gather_light(uv, float2(1.0, 0.0), l), 0.0, 0.0, 1.0);
}

float4 PS_JoinV(float4 pos : SV_Position, float2 uv : TEXCOORD) : SV_Target
{
#if ENABLE_DEBUG_MODE
    if (UI_DEBUG == 1)
        return float4(ufx_dm_normal_view(uv), 1.0);
#endif

    float4 gb = ufx_dm_face(uv);

#if ENABLE_DEBUG_MODE
    if (UI_DEBUG == 2)
        return float4(ufx_dm_oct_unpack(gb.rg) * 0.5 + 0.5, 1.0);
    if (UI_DEBUG == 3)
        return float4(gb.a.xxx, 1.0);
#endif

    float4 t = ufx_dm_tex4(uv);
    float3 crunch = t.rgb;

    if (gb.b > UFX_DM_SKY || gb.a < 0.5)
        return float4(crunch, 1.0);

    float3 n0 = ufx_dm_oct_unpack(gb.rg);
    int lod = ufx_dm_lod_level(gb.b);
    bool lod_obj = ufx_dm_lod_obj(gb, lod);
    float mul = saturate(UI_GEO_MUL);
    if (lod_obj)
        mul *= saturate(1.0 - 0.42 * (float)lod);

    float3 src = ufx_dm_back(uv);
    float3 albedo = lerp(src, crunch, mul);

    float fade = 1.0;
    if (UI_FEATHER >= 0.5)
    {
        float3 n_prep = ufx_dm_oct_unpack(ufx_dm_prep(uv).rg);
        fade = ufx_dm_edge_fade(uv, gb.b, n_prep);
        if (fade < 1e-4)
            return float4(albedo, 1.0);
    }

    float lit = ufx_dm_join(uv);
    float r = clamp(UI_RADIUS, 1.0, (float)MAX_JOIN_RADIUS);
    float wsum = 1.0;
    float acc = lit;
    float2 step_uv = float2(0.0, BUFFER_PIXEL_SIZE.y);

    [loop]
    for (int i = 1; i <= MAX_JOIN_RADIUS; i++)
    {
        if ((float)i > r)
            break;
        float2 o = step_uv * (float)i;
        float2 uv1 = uv + o;
        if (ufx_dm_same_face_n(gb, n0, ufx_dm_face(uv1)))
        {
            acc += ufx_dm_join(uv1);
            wsum += 1.0;
        }
        uv1 = uv - o;
        if (ufx_dm_same_face_n(gb, n0, ufx_dm_face(uv1)))
        {
            acc += ufx_dm_join(uv1);
            wsum += 1.0;
        }
    }

    lit = acc / max(wsum, 1e-4);

    float3 facet = ufx_dm_relight(src, lit);
    float3 detailed = ufx_dm_apply_light(crunch, lit, t.a);
    float3 simplified = lerp(facet, detailed, mul);
    return float4(lerp(albedo, simplified, fade), 1.0);
}

float4 PS_Lit(float4 pos : SV_Position, float2 uv : TEXCOORD) : SV_Target
{
    float3 c = ufx_dm_out(uv);

#if ENABLE_DEBUG_MODE
    if (UI_DEBUG != 0)
        return float4(c, 1.0);
#endif

    float flat = saturate(UI_FLAT);
    float spec = saturate(UI_SPEC);
    float cell = max(UI_SHADOW, 0.0);

    float4 gb = ufx_dm_face(uv);
    if (gb.b > UFX_DM_SKY)
        return float4(c, 1.0);

    int lod = ufx_dm_lod_level(gb.b);
    bool lod_obj = ufx_dm_lod_obj(gb, lod);
    if (lod_obj)
        flat = max(flat, 0.45 + 0.18 * (float)(lod - 1));
    if (flat < 1e-4 && spec < 1e-4 && cell < 0.5)
        return float4(c, 1.0);

    float d0 = gb.b;
    float l = ufx_dm_luma(c);

    if (spec > 1e-4)
    {
        float acc = l;
        float w = 1.0;
        for (int k = 0; k < 4; k++)
        {
            float2 u1 = uv + UFX_DM_DIR4[k] * (4.0 * BUFFER_PIXEL_SIZE);
            if (ufx_dm_lit_ok_d(d0, u1)) { acc += ufx_dm_luma_out(u1); w += 1.0; }
            u1 = uv + UFX_DM_DIR4[k] * (8.0 * BUFFER_PIXEL_SIZE);
            if (ufx_dm_lit_ok_d(d0, u1)) { acc += ufx_dm_luma_out(u1); w += 1.0; }
        }
        float base = acc / max(w, 1.0);
        l = lerp(l, min(l, base), spec);
    }

    if (cell >= 0.5)
    {
        float2 uv_c = (floor(uv * BUFFER_SCREEN_SIZE / cell) + 0.5) * cell * BUFFER_PIXEL_SIZE;
        float l_b = l;
        if (ufx_dm_lit_ok_d(d0, uv_c))
            l_b = ufx_dm_luma_out(uv_c);

        float2 h = cell * 0.35 * BUFFER_PIXEL_SIZE;
        float2 u1 = uv_c + float2(h.x, h.y);
        if (ufx_dm_lit_ok_d(d0, u1)) l_b = min(l_b, ufx_dm_luma_out(u1));
        u1 = uv_c + float2(-h.x, h.y);
        if (ufx_dm_lit_ok_d(d0, u1)) l_b = min(l_b, ufx_dm_luma_out(u1));
        u1 = uv_c + float2(h.x, -h.y);
        if (ufx_dm_lit_ok_d(d0, u1)) l_b = min(l_b, ufx_dm_luma_out(u1));
        u1 = uv_c + float2(-h.x, -h.y);
        if (ufx_dm_lit_ok_d(d0, u1)) l_b = min(l_b, ufx_dm_luma_out(u1));

        float umbra = saturate((0.48 - l) / 0.48);
        l = lerp(l, min(l, l_b), umbra);
    }

    if (flat > 1e-4)
    {
        float steps = lerp(18.0, 4.0, flat);
        float lq = round(l * steps) / max(steps, 1.0);
        l = lerp(l, lq, flat);
    }

    return float4(ufx_dm_relight(c, l), 1.0);
}

float4 PS_Scale(float4 pos : SV_Position, float2 uv : TEXCOORD) : SV_Target
{
#if ENABLE_DEBUG_MODE
    if (UI_DEBUG != 0)
        return tex2Dlod(UFX_DM_TexSamp, float4(uv, 0.0, 0.0));
#endif

    float2 uv_j = ufx_dm_warp_uv(uv);

    float pct = clamp(UI_RES, 10.0, 100.0) * 0.01;
    if (pct > 0.995)
        return float4(ufx_dm_color_limit(ufx_dm_sample_fogged(uv_j), uv), 1.0);

    float2 grid = max(floor(BUFFER_SCREEN_SIZE * pct + 0.5), 1.0);
    float2 lo = uv_j * grid - 0.5;
    float2 i = floor(lo);
    float2 f = saturate(lo - i);
    float2 i0 = clamp(i, 0.0, grid - 1.0);
    float2 i1 = clamp(i + 1.0, 0.0, grid - 1.0);

    float3 c00 = ufx_dm_sample_fogged((i0 + 0.5) / grid);
    float3 c10 = ufx_dm_sample_fogged((float2(i1.x, i0.y) + 0.5) / grid);
    float3 c01 = ufx_dm_sample_fogged((float2(i0.x, i1.y) + 0.5) / grid);
    float3 c11 = ufx_dm_sample_fogged((i1 + 0.5) / grid);

    float3 c = lerp(lerp(c00, c10, f.x), lerp(c01, c11, f.x), f.y);
    return float4(ufx_dm_color_limit(c, uv), 1.0);
}

/*=============================================================================
    Technique
=============================================================================*/

technique UniqFX_Demake
<
    ui_label = "UniqFX: Demake";
    ui_tooltip =
        "Simplifies graphics to achieve visuals of game demake by:\n"
        "- scaling output into low-resolution and back\n"
        "- limiting color pallete and applying dithering\n"
        "- old-hardware depth fog\n"
        "- flatten lighting, blocky shadows and reduced specular gloss\n"
        "- merging nearby high-poly faces (based on depth and normal)\n"
        "  into one shared plane that fakes low-poly geometry\n"
        "- fake distance LOD (minified textures, flatter lighting, coarser vertices)\n"
        "- snapping and jittering face intersections like PS1 vertices\n"
        "- pixelating & bluring textures";
>
{
    pass Prep
    {
        VertexShader = PostProcessVS;
        PixelShader = PS_Prep;
        RenderTarget = UFX_DM_PrepTex;
    }
    pass Face
    {
        VertexShader = PostProcessVS;
        PixelShader = PS_Face;
        RenderTarget = UFX_DM_FaceTex;
    }
    pass LightH
    {
        VertexShader = PostProcessVS;
        PixelShader = PS_LightH;
        RenderTarget = UFX_DM_JoinTex;
    }
    pass Tex
    {
        VertexShader = PostProcessVS;
        PixelShader = PS_Tex;
        RenderTarget = UFX_DM_TexTex;
    }
    pass JoinH
    {
        VertexShader = PostProcessVS;
        PixelShader = PS_JoinH;
        RenderTarget = UFX_DM_JoinTex;
    }
    pass JoinV
    {
        VertexShader = PostProcessVS;
        PixelShader = PS_JoinV;
        RenderTarget = UFX_DM_OutTex;
    }
    pass Lit
    {
        VertexShader = PostProcessVS;
        PixelShader = PS_Lit;
        RenderTarget = UFX_DM_TexTex;
    }
    pass Scale
    {
        VertexShader = PostProcessVS;
        PixelShader = PS_Scale;
    }
}

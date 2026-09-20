/*=============================================================================
    UniqFX : FakeBumpMap
    Version: 2026.09.20
    Author : Dominik Wojtasik
    License: MIT
    Source : https://github.com/dwojtasik/UniqFX

    Requires iMMERSE by Marty McFly shaders installed:
    https://github.com/martymcmodding/iMMERSE

    Relights large planes with a textured normal: colour *= (Nt·L+a)/(Ng·L+a)
    Experimentally allows to extrude surface fragments by pixel walk.

    Place below selected Smoothed+Textured Normal Map provider:
    • iMMERSE: Launchpad (https://github.com/martymcmodding/iMMERSE)
    • LUMENITE: Kernel 2.0 (https://github.com/umar-afzaal/LumeniteFX)

    Preprocessor:
    TEXTURED_NORMAL_PROVIDER [0-1]  - 0 = iMMERSE Launchpad, 1 = LUMENITE Kernel 2.0
    ENABLE_DEBUG_MODE [0-1]         - 0 = hide debug views, 1 = show debug views
=============================================================================*/

#ifndef TEXTURED_NORMAL_PROVIDER
    #define TEXTURED_NORMAL_PROVIDER 0
#endif
#if TEXTURED_NORMAL_PROVIDER < 0
    #undef TEXTURED_NORMAL_PROVIDER
    #define TEXTURED_NORMAL_PROVIDER 0
#elif TEXTURED_NORMAL_PROVIDER > 1
    #undef TEXTURED_NORMAL_PROVIDER
    #define TEXTURED_NORMAL_PROVIDER 1
#endif

#ifndef ENABLE_DEBUG_MODE
    #define ENABLE_DEBUG_MODE 0
#endif
#if ENABLE_DEBUG_MODE < 0
    #undef ENABLE_DEBUG_MODE
    #define ENABLE_DEBUG_MODE 0
#elif ENABLE_DEBUG_MODE > 1
    #undef ENABLE_DEBUG_MODE
    #define ENABLE_DEBUG_MODE 1
#endif

#if exists(".\MartysMods\mmx_global.fxh") \
 && exists(".\MartysMods\mmx_depth.fxh") \
 && exists(".\MartysMods\mmx_math.fxh") \
 && exists(".\MartysMods\mmx_camera.fxh") \
 && exists(".\MartysMods\mmx_deferred.fxh")

    texture ColorInputTex : COLOR;
    texture DepthInputTex : DEPTH;
    sampler ColorInput { Texture = ColorInputTex; };
    sampler DepthInput { Texture = DepthInputTex; };

    #include ".\MartysMods\mmx_global.fxh"
    #include ".\MartysMods\mmx_depth.fxh"
    #include ".\MartysMods\mmx_math.fxh"
    #include ".\MartysMods\mmx_camera.fxh"
    #include ".\MartysMods\mmx_deferred.fxh"

#if TEXTURED_NORMAL_PROVIDER == 1
    namespace Kernel
    {
        texture tNormals
        {
            Width = BUFFER_WIDTH;
            Height = BUFFER_HEIGHT;
            Format = RGBA16F;
            MipLevels = 4;
        };
        sampler sNormals { Texture = tNormals; };
    }
#endif

    texture FBM_EdgeTex { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; Format = R8; };
    texture FBM_BlurTex { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; Format = R8; };
    sampler FBM_EdgeSamp
    {
        Texture = FBM_EdgeTex;
        MinFilter = LINEAR; MagFilter = LINEAR; MipFilter = POINT;
        AddressU = CLAMP; AddressV = CLAMP;
    };
    sampler FBM_BlurSamp
    {
        Texture = FBM_BlurTex;
        MinFilter = LINEAR; MagFilter = LINEAR; MipFilter = POINT;
        AddressU = CLAMP; AddressV = CLAMP;
    };

    /*=============================================================================
        UI
    =============================================================================*/

    uniform int UI_HELP <
        ui_type = "radio";
        ui_label = " ";
        ui_category = "Help";
        ui_category_closed = false;
        ui_text =
            "Set TEXTURED_NORMAL_PROVIDER to given provider:\n"
            "• 0 for iMMERSE: Launchpad\n"
            "  Enable with Smoothed + Textured Normal Map Mode and place on top.\n"
            "• 1 for LUMENITE Kernel 2.0\n"
            "  LUMENITE Kernel 2.0: Enable with SMOOTH_NORMALS and place on top.\n"
            "\n"
            "ENABLE_DEBUG_MODE [0-1]\n"
            "• 0: hide debug views.\n"
            "• 1: show debug views.";
    >;

#if ENABLE_DEBUG_MODE
    uniform int UI_VIEW <
        ui_type = "combo";
        ui_label = "Debug View";
        ui_items = "Normal Mapping\0Debug: Filtered Normal\0Debug: Lighting\0Debug: Mask\0Debug: Walk\0";
        ui_tooltip = "Mask: red = HUD, green = depth fade, blue = 1 − edge feather.\n"
                    "Walk: extend offset (floors should barely move).";
        ui_category = "Debug";
    > = 0;
#endif

#if TEXTURED_NORMAL_PROVIDER == 1
    uniform float UI_KERNEL_BUMP <
        ui_type = "drag";
        ui_label = "Kernel Bump Scale";
        ui_tooltip = "Lower = finer grout. 0 = use Kernel's stored field as-is\n"
                    "(including Kernel Surface Relief).";
        ui_min = 0.0; ui_max = 1.0;
        ui_category = "Normal Mapping";
    > = 0.5;
#endif

    uniform float UI_STRENGTH <
        ui_type = "drag";
        ui_label = "Normal Strength";
        ui_tooltip = "How hard the bump relights vs the original flat lighting.";
        ui_min = 0.0; ui_max = 5.0;
        ui_category = "Normal Mapping";
    > = 3.0;

    uniform float UI_GLOSS <
        ui_type = "drag";
        ui_label = "Gloss";
        ui_tooltip = "Specular from the bump. Helps plates catch the flashlight.";
        ui_min = 0.0; ui_max = 5.0;
        ui_category = "Normal Mapping";
    > = 2.0;

    uniform float UI_CAVITY <
        ui_type = "drag";
        ui_label = "Cavity";
        ui_tooltip = "Darkens grout and cracks where the bump leaves the surface.";
        ui_min = 0.0; ui_max = 5.0;
        ui_category = "Normal Mapping";
    > = 2.0;

    uniform float UI_EXTEND <
        ui_type = "drag";
        ui_label = "Extend";
        ui_tooltip = "Walk uphill along the bump so grout samples the neighbouring\n"
                    "plate. Full on walls; shortened on floors/ceilings. 0 = off.";
        ui_min = 0.0; ui_max = 12.0;
        ui_category = "Normal Mapping";
    > = 2.5;

    uniform bool UI_EXTEND_INVERT <
        ui_label = "Invert Extend";
        ui_tooltip = "Reverse the pixel-walk direction. Off = current uphill walk.";
        ui_category = "Normal Mapping";
    > = false;

    uniform bool UI_INVERT <
        ui_label = "Invert Normal";
        ui_tooltip = "Flip the bump if relief looks inside-out.";
        ui_category = "Normal Mapping";
    > = false;

    uniform float UI_PLANAR <
        ui_type = "drag";
        ui_label = "Large Planes Only";
        ui_tooltip = "Limits bump to large walls/floors/ceilings.\n"
                    "0 = every surface with depth.\n"
                    "1 = large planes at full strength.\n"
                    "High (100–1000) = only the flattest planes.";
        ui_min = 0.0; ui_max = 1000.0;
        ui_category = "Limits";
    > = 250.0;

#if TEXTURED_NORMAL_PROVIDER == 1
    uniform float UI_PLANAR_MULT <
        ui_type = "drag";
        ui_label = "Large Planes Multiplier";
        ui_tooltip = "Scales Large Planes Only for LUMENITE Kernel.\n"
                    "Default 0.004 makes 250 behave like ~1.0.";
        ui_min = 0.0; ui_max = 1.0;
        ui_category = "Limits";
    > = 0.004;
#else
    #define UI_PLANAR_MULT 1.0
#endif

    uniform float UI_SKIP_SMALL <
        ui_type = "drag";
        ui_label = "Skip Small / Noisy Mesh";
        ui_tooltip = "Stricter large-plane test. Leave at 1; edges are feathered\n"
                    "separately. Raising this flattens wall bump.";
        ui_min = 0.0; ui_max = 1.0;
        ui_category = "Limits";
    > = 1.0;

    uniform float UI_FADE_START <
        ui_type = "drag";
        ui_label = "Depth Fade Start";
        ui_tooltip = "Linear depth where bump begins to fade out.";
        ui_min = 0.0; ui_max = 1.0;
        ui_category = "Limits";
    > = 0.10;

    uniform float UI_FADE_LEN <
        ui_type = "drag";
        ui_label = "Depth Fade Length";
        ui_tooltip = "Distance past the start over which bump fades to nothing.";
        ui_min = 0.0; ui_max = 1.0;
        ui_category = "Limits";
    > = 0.10;

    uniform float4 UI_BOX0 <
        ui_type = "drag";
        ui_label = "HUD Box 0 (x,y,w,h)";
        ui_tooltip = "Optional HUD exclusion box. Zero size = unused.";
        ui_min = 0.0; ui_max = 1.0;
        ui_category = "HUD";
    > = float4(0.0, 0.0, 0.0, 0.0);

    uniform float4 UI_BOX1 <
        ui_type = "drag";
        ui_label = "HUD Box 1 (x,y,w,h)";
        ui_tooltip = "Optional HUD exclusion box. Zero size = unused.";
        ui_min = 0.0; ui_max = 1.0;
        ui_category = "HUD";
    > = float4(0.0, 0.0, 0.0, 0.0);

    uniform float4 UI_BOX2 <
        ui_type = "drag";
        ui_label = "HUD Box 2 (x,y,w,h)";
        ui_tooltip = "Optional HUD exclusion box. Zero size = unused.";
        ui_min = 0.0; ui_max = 1.0;
        ui_category = "HUD";
    > = float4(0.0, 0.0, 0.0, 0.0);

    uniform float4 UI_BOX3 <
        ui_type = "drag";
        ui_label = "HUD Box 3 (x,y,w,h)";
        ui_tooltip = "Optional HUD exclusion box. Zero size = unused.";
        ui_min = 0.0; ui_max = 1.0;
        ui_category = "HUD";
    > = float4(0.0, 0.0, 0.0, 0.0);

    uniform float4 UI_BOX4 <
        ui_type = "drag";
        ui_label = "HUD Box 4 (x,y,w,h)";
        ui_tooltip = "Optional HUD exclusion box. Zero size = unused.";
        ui_min = 0.0; ui_max = 1.0;
        ui_category = "HUD";
    > = float4(0.0, 0.0, 0.0, 0.0);

    uniform float4 UI_BOX5 <
        ui_type = "drag";
        ui_label = "HUD Box 5 (x,y,w,h)";
        ui_tooltip = "Optional HUD exclusion box. Zero size = unused.";
        ui_min = 0.0; ui_max = 1.0;
        ui_category = "HUD";
    > = float4(0.0, 0.0, 0.0, 0.0);

    uniform float UI_BOX_FEATHER <
        ui_type = "drag";
        ui_label = "HUD Feather (px)";
        ui_tooltip = "Soft falloff around HUD boxes, in pixels.";
        ui_min = 0.0; ui_max = 200.0;
        ui_category = "HUD";
    > = 30.0;

    /*=============================================================================
        Common
    =============================================================================*/

    struct VSOut
    {
        float4 pos : SV_Position;
        float2 uv  : TEXCOORD0;
    };

    VSOut VS_Full(uint id : SV_VertexID)
    {
        VSOut o;
        FullscreenTriangleVS(id, o.pos, o.uv);
        return o;
    }

    static const float3 FBM_LUMA = float3(0.2126, 0.7152, 0.0722);

    static const float2 FBM_DIRS[8] =
    {
        float2( 0.9238795,  0.3826834),
        float2( 0.3826834,  0.9238795),
        float2(-0.3826834,  0.9238795),
        float2(-0.9238795,  0.3826834),
        float2(-0.9238795, -0.3826834),
        float2(-0.3826834, -0.9238795),
        float2( 0.3826834, -0.9238795),
        float2( 0.9238795, -0.3826834)
    };

    static const float2 FBM_CREASE[8] =
    {
        float2( 1.0,  0.0), float2(-1.0,  0.0),
        float2( 0.0,  1.0), float2( 0.0, -1.0),
        float2( 3.0,  0.0), float2(-3.0,  0.0),
        float2( 0.0,  3.0), float2( 0.0, -3.0)
    };

    static const float FBM_GAUSS_W[9] =
    {
        1.000000, 0.982161, 0.930549, 0.850437, 0.749809,
        0.637628, 0.523131, 0.413986, 0.315964
    };

    bool fbm_has_depth(float z)
    {
        return z > 1e-4 && z < 0.999;
    }

    float3 fbm_unit(float3 n, float min_len2)
    {
        float len2 = dot(n, n);
        return (len2 > min_len2) ? n * rsqrt(len2) : float3(0.0, 0.0, 1.0);
    }

#if TEXTURED_NORMAL_PROVIDER == 1
    float3 fbm_kernel_geo(float2 uv)
    {
        return fbm_unit(tex2Dlod(Kernel::sNormals, float4(uv, 0, 0)).rgb, 1e-8);
    }

    float3 fbm_kernel_macro(float2 uv)
    {
        float2 d = BUFFER_PIXEL_SIZE * 4.0;
        float3 n = fbm_kernel_geo(uv) * 4.0;
        n += fbm_kernel_geo(uv + float2(d.x, 0.0));
        n += fbm_kernel_geo(uv - float2(d.x, 0.0));
        n += fbm_kernel_geo(uv + float2(0.0, d.y));
        n += fbm_kernel_geo(uv - float2(0.0, d.y));
        return fbm_unit(n, 1e-8);
    }

    float3 fbm_kernel_bump(float2 uv, float3 geo)
    {
        float2 texel = BUFFER_PIXEL_SIZE * UI_KERNEL_BUMP;
        float lc = dot(tex2Dlod(ColorInput, uv, 0).rgb, FBM_LUMA);
        float lr = dot(tex2Dlod(ColorInput, uv + float2(texel.x, 0.0), 0).rgb, FBM_LUMA);
        float lb = dot(tex2Dlod(ColorInput, uv + float2(0.0, texel.y), 0).rgb, FBM_LUMA);
        float dx = (lr - lc) * 2.5;
        float dy = (lb - lc) * 2.5;
        float3 up = abs(geo.z) < 0.999 ? float3(0.0, 0.0, 1.0) : float3(1.0, 0.0, 0.0);
        float3 T = normalize(cross(up, geo));
        float3 B = cross(geo, T);
        float3 bump = normalize(float3(-dx, -dy, 1.0));
        return normalize(T * bump.x + B * bump.y + geo * bump.z);
    }
#endif

    void fbm_NgNt(float2 uv, out float3 ng, out float3 nt)
    {
        ng = float3(0.0, 0.0, 1.0);
        nt = ng;

#if TEXTURED_NORMAL_PROVIDER == 1
        float3 kn = fbm_kernel_geo(uv);
        [flatten]
        if(UI_KERNEL_BUMP <= 0.001)
        {
            ng = fbm_kernel_macro(uv);
            nt = kn;
        }
        else
        {
            ng = kn;
            nt = fbm_kernel_bump(uv, kn);
        }
#else
        nt = normalize(Deferred::get_normals(uv));
        float3 g = Deferred::get_geometry_normals(uv);
        ng = dot(g, g) > 1e-4 ? normalize(g) : nt;
#endif
    }

    float3 fbm_Ng(float2 uv)
    {
        float3 n = float3(0.0, 0.0, 1.0);

#if TEXTURED_NORMAL_PROVIDER == 1
        float3 kn = fbm_kernel_geo(uv);
        n = (UI_KERNEL_BUMP <= 0.001) ? fbm_kernel_macro(uv) : kn;
#else
        float3 g = Deferred::get_geometry_normals(uv);
        n = dot(g, g) > 1e-4 ? normalize(g)
                            : normalize(Deferred::get_normals(uv));
#endif
        return n;
    }

    float3 fbm_Nt(float2 uv)
    {
        float3 n = float3(0.0, 0.0, 1.0);

#if TEXTURED_NORMAL_PROVIDER == 1
        float3 kn = fbm_kernel_geo(uv);
        n = (UI_KERNEL_BUMP <= 0.001) ? kn : fbm_kernel_bump(uv, kn);
#else
        n = normalize(Deferred::get_normals(uv));
#endif

        return n;
    }

    float3 fbm_guide(float2 uv, float3 fallback)
    {
        float3 g = fallback;

#if TEXTURED_NORMAL_PROVIDER != 1
        float3 a = Deferred::get_albedo(uv);
        if(dot(a, 1.0) > 1e-5)
            g = a;
#endif
        return g;
    }

    float fbm_on_plane(float2 uv, float3 p, float3 n, float z, float plane_s_rcp)
    {
        if(!fbm_has_depth(z))
            return 0.0;
        float3 q = Camera::uv_to_proj(uv, Camera::depth_to_z(z));
        return saturate(1.0 - abs(dot(q - p, n)) * plane_s_rcp);
    }

    float3 fbm_view_p(float2 uv)
    {
        return Camera::uv_to_proj(uv);
    }

    float3 fbm_view_p(float2 uv, float z)
    {
        return Camera::uv_to_proj(uv, Camera::depth_to_z(z));
    }

    float3 fbm_raw_Ng(float2 uv, float3 p)
    {
        float2 d = BUFFER_PIXEL_SIZE * 2.0;
        return fbm_unit(
            cross(fbm_view_p(uv + float2(d.x, 0.0)) - p,
                fbm_view_p(uv + float2(0.0, d.y)) - p),
            1e-24);
    }

    float fbm_tap_crease(float2 uv1, float z0, float z0_rcp, float3 n_plane, float3 n_raw0, float facing)
    {
        if(!Math::inside_screen(uv1))
            return 0.0;
        float z1 = Depth::get_linear_depth(uv1);
        if(!fbm_has_depth(z1))
            return 0.0;
        float rel = (z1 - z0) * z0_rcp;
        if(rel < -0.012)
            return 0.0;

        float3 p1 = fbm_view_p(uv1, z1);
        float n_lp = saturate((0.76 - saturate(dot(n_plane, fbm_Ng(uv1)))) / 0.30);
        float n_rw = saturate((0.88 - saturate(dot(n_raw0, fbm_raw_Ng(uv1, p1)))) / 0.32);
        float d_br = saturate((abs(rel) - 0.0022) / 0.012);
        return max(n_lp, facing * max(n_rw, d_br));
    }

    void fbm_tbn(float2 uv, float3 p, float3 n, out float3 T, out float3 B)
    {
        float3 du = Camera::uv_to_proj(uv + float2(BUFFER_PIXEL_SIZE.x, 0)) - p;
        float3 dv = Camera::uv_to_proj(uv + float2(0, BUFFER_PIXEL_SIZE.y)) - p;
        T = normalize(du - n * dot(du, n) + 1e-8);
        B = normalize(dv - n * dot(dv, n) + 1e-8);
        if(dot(cross(T, B), n) < 0.0)
            B = -B;
    }

    float fbm_box_dist(float2 uv, float4 r)
    {
        if(r.z <= 0.0 || r.w <= 0.0)
            return 1e6;
        float2 half_px = 0.5 * r.zw * BUFFER_SCREEN_SIZE;
        float2 q = abs((uv - (r.xy + 0.5 * r.zw)) * BUFFER_SCREEN_SIZE) - half_px;
        return length(max(q, 0.0));
    }

    float fbm_hud(float2 uv)
    {
        float d = fbm_box_dist(uv, UI_BOX0);
        d = min(d, fbm_box_dist(uv, UI_BOX1));
        d = min(d, fbm_box_dist(uv, UI_BOX2));
        d = min(d, fbm_box_dist(uv, UI_BOX3));
        d = min(d, fbm_box_dist(uv, UI_BOX4));
        d = min(d, fbm_box_dist(uv, UI_BOX5));
        return smoothstep(0.0, max(UI_BOX_FEATHER, 1.0), d);
    }

    float3 fbm_encode_n(float3 n)
    {
        return n * 0.5 + 0.5;
    }

    float fbm_ndl(float3 n, float3 l, float wrap)
    {
        float d = dot(n, l);
        return lerp(saturate(d), d * 0.5 + 0.5, wrap) + 0.28;
    }

    float fbm_wrap(float3 ng, float3 L)
    {
#if TEXTURED_NORMAL_PROVIDER == 1
        return saturate((0.35 - dot(ng, L)) / 0.50);
#else
        return 0.0;
#endif
    }

    float fbm_pow12(float x)
    {
        x = saturate(x);
        float x4 = x * x;
        x4 *= x4;
        return x4 * x4 * x4;
    }

    float fbm_gauss_axis(sampler2D samp, float2 uv, float2 axis)
    {
        float z = Depth::get_linear_depth(uv);
        float z_rcp = rcp(max(z, 1e-4));
        float acc = 0.0;
        float wsum = 1e-4;

        [loop]
        for(int k = -8; k <= 8; k++)
        {
            float2 uvk = uv + axis * k;
            if(!Math::inside_screen(uvk))
                continue;
            float zk = Depth::get_linear_depth(uvk);
            if((zk - z) * z_rcp < -0.012)
                continue;
            int ak = k < 0 ? -k : k;
            float wk = FBM_GAUSS_W[ak];
            acc += tex2Dlod(samp, uvk, 0).r * wk;
            wsum += wk;
        }
        return acc * rcp(wsum);
    }

    /*=============================================================================
        Passes
    =============================================================================*/

    void PS_Edge(VSOut i, out float o : SV_Target0)
    {
        float z = Depth::get_linear_depth(i.uv);
        [branch]
        if(!fbm_has_depth(z))
        {
            o = 0.0;
            return;
        }

        float z_rcp = rcp(max(z, 1e-4));
        float3 p0      = fbm_view_p(i.uv, z);
        float3 n_plane = fbm_Ng(i.uv);
        float3 n_raw   = fbm_raw_Ng(i.uv, p0);
        float  facing  = saturate((abs(dot(n_plane, normalize(-p0))) - 0.16) / 0.28);
        float2 px = BUFFER_PIXEL_SIZE;
        float e = 0.0;

        [loop]
        for(int t = 0; t < 8; t++)
            e = max(e, fbm_tap_crease(i.uv + FBM_CREASE[t] * px, z, z_rcp, n_plane, n_raw, facing));

        o = smoothstep(0.12, 0.48, e);
    }

    void PS_BlurH(VSOut i, out float o : SV_Target0)
    {
        o = fbm_gauss_axis(FBM_EdgeSamp, i.uv, float2(BUFFER_PIXEL_SIZE.x, 0.0));
    }

    void PS_BlurV(VSOut i, out float o : SV_Target0)
    {
        o = fbm_gauss_axis(FBM_BlurSamp, i.uv, float2(0.0, BUFFER_PIXEL_SIZE.y));
    }

    void PS_Map(VSOut i, out float3 o : SV_Target0)
    {
        float3 src = tex2Dlod(ColorInput, i.uv, 0).rgb;
        o = src;

        float z = Depth::get_linear_depth(i.uv);
        [branch]
        if(!fbm_has_depth(z))
            return;

        float z_rcp = rcp(max(z, 1e-4));
        float fade = saturate(1.0 - (z - UI_FADE_START) / max(UI_FADE_LEN, 1e-4));
        float hud  = fbm_hud(i.uv);

        float3 p = fbm_view_p(i.uv, z);
        float3 ng = float3(0.0, 0.0, 1.0);
        float3 nt = ng;
        fbm_NgNt(i.uv, ng, nt);

        float  lum0 = dot(src, FBM_LUMA);
        float3 g0 = fbm_guide(i.uv, src);
        float lg = max(dot(g0, FBM_LUMA), 1e-3);
        float2 chroma0 = g0.rg / lg;
        float plane_s_rcp = rcp(0.035 * max(abs(p.z), 1.0));

        float4 nacc = 0.0;
        float2 pacc = float2(0.0, 1e-4);
        float  occ  = 0.0;
        float2 chr_src = src.rg / max(lum0, 1e-3);
        float2 acc_f = 0.0;
        float3 acc_w = 0.0;
        float2 acc_l = float2(0.0, 1e-4);

        [loop]
        for(int s = 0; s < 8; s++)
        {
            float2 dir = FBM_DIRS[s];

            float2 uv_p = i.uv + dir * 32.0 * BUFFER_PIXEL_SIZE;
            if(Math::inside_screen(uv_p))
            {
                float zp = Depth::get_linear_depth(uv_p);
                float rp = (zp - z) * z_rcp;
                if(rp > -0.012)
                {
                    float pw = fbm_on_plane(uv_p, p, ng, zp, plane_s_rcp);
                    float ngd = saturate(dot(ng, fbm_Ng(uv_p)));
                    if(pw > 0.04 && ngd > 0.65)
                    {
                        pacc.x += ngd * pw;
                        pacc.y += pw;
                    }
                }
            }

            float2 uv_n = i.uv + dir * 2.5 * BUFFER_PIXEL_SIZE;
            if(Math::inside_screen(uv_n))
            {
                float zn = Depth::get_linear_depth(uv_n);
                float rn = (zn - z) * z_rcp;
                if(rn < -0.010)
                    occ = max(occ, saturate((-rn - 0.010) / 0.035));
                else if(fbm_on_plane(uv_n, p, ng, zn, plane_s_rcp) > 0.2)
                {
                    float3 c1 = tex2Dlod(ColorInput, uv_n, 0).rgb;
                    float3 a1 = fbm_guide(uv_n, c1);
                    float l1 = max(dot(a1, FBM_LUMA), 1e-3);
                    float2 dc = a1.rg / l1 - chroma0;
                    float wc = exp(-dot(dc, dc) * 40.0);
                    nacc += float4(fbm_Nt(uv_n) * wc, wc);

                    float ln = max(dot(max(c1, 0.0), FBM_LUMA), 1e-4);
                    acc_f.x += abs(log2(ln) - log2(max(lum0, 1e-4)));
                    acc_f.y += 1.0;
                    acc_l.x += ln;
                    acc_l.y += 1.0;
                }
            }

            float2 uv_o = i.uv + dir * 6.0 * BUFFER_PIXEL_SIZE;
            if(Math::inside_screen(uv_o))
            {
                float ro = (Depth::get_linear_depth(uv_o) - z) * z_rcp;
                if(ro < -0.010)
                    occ = max(occ, saturate((-ro - 0.010) / 0.035) * 0.65);
            }

            float2 uv_b = i.uv + dir * 10.0 * BUFFER_PIXEL_SIZE;
            if(Math::inside_screen(uv_b))
            {
                float zb = Depth::get_linear_depth(uv_b);
                float rb = (zb - z) * z_rcp;
                if(rb > -0.012 && fbm_on_plane(uv_b, p, ng, zb, plane_s_rcp) > 0.15)
                {
                    float3 cb = tex2Dlod(ColorInput, uv_b, 0).rgb;
                    float lb = max(dot(cb, FBM_LUMA), 1e-4);
                    float2 chb = cb.rg / lb;
                    acc_w.x += abs(log2(lb) - log2(max(lum0, 1e-4)));
                    acc_w.y += length(chb - chr_src);
                    acc_w.z += 1.0;
                }
            }
        }

        nacc += float4(nt * 2.0 * (1.0 - occ), 2.0 * (1.0 - occ));
        nt = (nacc.w > 0.12) ? normalize(nacc.xyz / max(nacc.w, 1e-3))
                            : ng;

        float g_f = acc_f.x / max(acc_f.y, 1e-3);
        float g_w = acc_w.x / max(acc_w.z, 1e-3);
        float ch  = acc_w.y / max(acc_w.z, 1e-3);
        float sharp  = g_f / (g_w + 0.05);
        float shadow = saturate(g_w * 2.0)
                    * saturate(1.05 - sharp)
                    * exp(-ch * 18.0);
        nt = normalize(lerp(nt, ng, shadow));
        if(UI_INVERT)
            nt = normalize(2.0 * ng * dot(nt, ng) - nt);

        float edge_feather = tex2Dlod(FBM_EdgeSamp, i.uv, 0).r;
        nt = normalize(lerp(nt, ng, edge_feather));

        float planar = pacc.x / pacc.y;
        float cut = lerp(0.12, 0.62, UI_SKIP_SMALL);
        float mask = saturate((planar - cut) / max(1.0 - cut, 0.10));
        mask = saturate(lerp(1.0, mask * mask, UI_PLANAR * UI_PLANAR_MULT));
        mask *= 1.0 - edge_feather;

        float w = fade * mask * hud;
        float2 uvh = i.uv;

#if ENABLE_DEBUG_MODE
        [branch]
        if(UI_VIEW == 1)
        {
            o = fbm_encode_n(nt);
            return;
        }
        if(UI_VIEW == 3)
        {
            o = lerp(float3(1, 0, 0), float3(mask, fade, 1.0 - edge_feather), hud);
            return;
        }
        if(UI_VIEW == 2)
        {
            float3 Vn = normalize(-p);
            float3 Ld = normalize(Vn + float3(0.0, 1.0, 0.0) * 0.35 + ng * 0.15);
            float wrap = fbm_wrap(ng, Ld);
            o = saturate(0.5 * fbm_ndl(nt, Ld, wrap)
                    / max(fbm_ndl(ng, Ld, wrap), 1e-3)).xxx;
            return;
        }
#endif

        [branch]
        if(w > 0.002 && (UI_STRENGTH > 0.01 || UI_EXTEND > 0.05))
        {
            float3 V = normalize(-p);

            [branch]
            if(UI_EXTEND > 0.05)
            {
                float3 T, B;
                fbm_tbn(i.uv, p, ng, T, B);
                float2 sl = -float2(dot(nt, T), dot(nt, B)) / max(dot(nt, ng), 0.22);
                if(UI_EXTEND_INVERT)
                    sl = -sl;
                float mag = length(sl);
                float horiz = saturate((abs(ng.y) - 0.48) / 0.38);
                float facing = saturate(abs(dot(ng, V)));
                float walk = UI_EXTEND * w * (1.0 - shadow) * (1.0 - occ) * (1.0 - edge_feather);
                walk *= lerp(1.0, 0.10 * facing, horiz);
                [branch]
                if(mag > 0.045 && walk > 0.08)
                {
                    float2 dir = sl / mag;
                    float step_px = walk / 8.0;
                    float pmin = lerp(0.18, 0.34, horiz);
                    float zmax = lerp(0.02, 0.007, horiz);
                    [loop]
                    for(int k = 0; k < 8; k++)
                    {
                        float2 nxt = uvh + dir * step_px * BUFFER_PIXEL_SIZE;
                        if(!Math::inside_screen(nxt))
                            break;
                        float z1 = Depth::get_linear_depth(nxt);
                        if(fbm_on_plane(nxt, p, ng, z1, plane_s_rcp) < pmin)
                            break;
                        if(abs(z1 - z) * z_rcp > zmax)
                            break;
                        uvh = nxt;
                    }
                }
            }

#if ENABLE_DEBUG_MODE
            [branch]
            if(UI_VIEW == 4)
            {
                o = float3(saturate((uvh - i.uv) / BUFFER_PIXEL_SIZE * 0.12 + 0.5), 0.5);
                return;
            }
#endif

            float3 L = normalize(V + float3(0.0, 1.0, 0.0) * 0.35 + ng * 0.15);
            float3 samp = max(tex2Dlod(ColorInput, uvh, 0).rgb, 0.0);
            float lum_s = dot(samp, FBM_LUMA);
            float lum_o = max(dot(max(src, 0.0), FBM_LUMA), 0.0);
            float hole = smoothstep(0.20, 0.48, lum_o)
                    * saturate((lum_o - lum_s) / max(lum_o, 1e-3));
            samp = lerp(samp, max(src, 0.0), hole);
            lum_s = dot(samp, FBM_LUMA);

            float wrap = fbm_wrap(ng, L);
            float geom = fbm_ndl(ng, L, wrap);
            float bump = fbm_ndl(nt, L, wrap);
            float ratio = bump / max(geom, 1e-3);

            float spec = max(fbm_pow12(dot(nt, V)) - fbm_pow12(dot(ng, V)), 0.0) * UI_GLOSS;

            float ndot = saturate(dot(nt, ng));
            float cavity = (UI_CAVITY <= 0.001) ? 1.0 : pow(ndot, UI_CAVITY);

            float shade = 1.0 + (ratio - 1.0) * UI_STRENGTH;
            shade = clamp(shade, 0.20, 3.5) * cavity;

            float neigh = acc_l.x / acc_l.y;
            float peak = saturate((lum_s - neigh) / max(neigh, 0.04));
            float hl_protect = max(smoothstep(0.32, 0.68, lum_s),
                                smoothstep(0.08, 0.30, peak));
            float hl_spec = smoothstep(0.58, 0.92, lum_s);
            shade = max(shade, lerp(0.20, 0.90, hl_protect));
            shade = lerp(shade, max(shade, 1.0), hl_protect);
            spec *= (1.0 - shadow) * (1.0 - hl_spec);

            float3 col = max(samp * shade + spec * samp, 0.0);
            o = lerp(src, col, w);
        }
#if ENABLE_DEBUG_MODE
        else if(UI_VIEW == 4)
            o = float3(0.5, 0.5, 0.5);
#endif
    }

    /*=============================================================================
        Technique
    =============================================================================*/

    technique FakeBumpMap
    <
        ui_label = "UniqFX: FakeBumpMap";
        ui_tooltip =
            "Relights large planes with a textured normal.\n"
            "Requires iMMERSE by Marty McFly shaders installed:\n"
            "https://github.com/martymcmodding/iMMERSE\n"
            "\n"
            "Set TEXTURED_NORMAL_PROVIDER and place this shader below the provider:\n"
            "• 0: iMMERSE Launchpad (Smoothed + Textured Normal Map Mode).\n"
            "• 1: LUMENITE Kernel 2.0 (SMOOTH_NORMALS=1).";
    >
    {
#if TEXTURED_NORMAL_PROVIDER == 0 && defined(IPC_REQUEST_FEATURE)
        IPC_REQUEST_FEATURE(MARTYSMODS_IPC_FEATURE_NORMALS)
#endif
        pass Edge { VertexShader = VS_Full; PixelShader = PS_Edge; RenderTarget = FBM_EdgeTex; }
        pass BlurH { VertexShader = VS_Full; PixelShader = PS_BlurH; RenderTarget = FBM_BlurTex; }
        pass BlurV { VertexShader = VS_Full; PixelShader = PS_BlurV; RenderTarget = FBM_EdgeTex; }
        pass Map { VertexShader = VS_Full; PixelShader = PS_Map; }
    }

#else

    uniform int UI_HELP <
        ui_type = "radio";
        ui_label = " ";
        ui_text =
            "This shader requires iMMERSE by Marty McFly shaders installed:\n"
            "https://github.com/martymcmodding/iMMERSE\n"
            "\n"
            "Download shaders from GitHub or install via shader-list during ReShade installation.\n"
            "Currently they are not installed so this shader does nothing.";
    >;

    technique FakeBumpMap
    <
        ui_label = "UniqFX: FakeBumpMap";
        ui_tooltip =
            "Relights large planes with a textured normal.\n"
            "This shader requires iMMERSE by Marty McFly shaders installed:\n"
            "https://github.com/martymcmodding/iMMERSE\n"
            "\n"
            "Download shaders from GitHub or install via shader-list during ReShade installation.\n"
            "Currently they are not installed so this shader does nothing.";
    >
    {
    }

#endif

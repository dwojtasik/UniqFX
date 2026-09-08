/*=============================================================================
    UniqFX: FakeBumpMap
    Author: Dominik Wojtasik
    Source: https://github.com/dwojtasik/UniqFX

    Requires iMMERSE shaders installed: https://github.com/martymcmodding/iMMERSE

    Relights large planes with a textured normal: colour *= (Nt·L+a)/(Ng·L+a)
    Optionally allows to extrude surface fragments by pixel walk.

    Place below selected Smoothed+Textured Normal Map provider:
    - iMMERSE: Launchpad (https://github.com/martymcmodding/iMMERSE)
    - LUMENITE: Kernel 2.0 (https://github.com/umar-afzaal/LumeniteFX)
=============================================================================*/

texture ColorInputTex : COLOR;
texture DepthInputTex : DEPTH;
sampler ColorInput { Texture = ColorInputTex; };
sampler DepthInput { Texture = DepthInputTex; };

#include ".\MartysMods\mmx_global.fxh"
#include ".\MartysMods\mmx_depth.fxh"
#include ".\MartysMods\mmx_math.fxh"
#include ".\MartysMods\mmx_camera.fxh"
#include ".\MartysMods\mmx_deferred.fxh"

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

texture FBM_EdgeTex { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; Format = RGBA8; };
texture FBM_BlurTex { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; Format = RGBA8; };
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

uniform int UI_VIEW <
    ui_type = "combo";
    ui_label = "View";
    ui_items = "Normal Mapping\0Debug: Filtered Normal\0Debug: Lighting\0Debug: Mask\0Debug: Walk\0";
    ui_tooltip = "Mask: red = HUD, green = depth fade, blue = 1 − edge feather.\n"
                 "Walk: extend offset (floors should barely move).";
    ui_category = "Normal Mapping";
> = 0;

uniform int UI_PROVIDER <
    ui_type = "combo";
    ui_label = "Textured Normal Provedier";
    ui_items = "iMMERSE: Launchpad\0LUMENITE: Kernel 2.0\0";
    ui_tooltip = "iMMERSE Launchpad: Enable with Smoothed + Textured\n"
                 "Normal Map Mode and place on top.\n"
                 "LUMENITE Kernel 2.0: Enable with SMOOTH_NORMALS and place on top.\n"
                 "With LUMENITE, set Large Planes to a low value (e.g. 1.0).";
    ui_category = "Normal Mapping";
> = 0;

uniform float UI_KERNEL_BUMP <
    ui_type = "drag";
    ui_label = "Kernel Bump Scale";
    ui_tooltip = "LUMENITE Kernel only. Lower = finer grout. 0 = use Kernel's\n"
                 "stored field as-is (including Kernel Surface Relief).";
    ui_min = 0.0; ui_max = 1.0;
    ui_category = "Normal Mapping";
> = 0.5;

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
                 "High (100–1000) = only the flattest planes (for Launchpad).\n"
                 "With Lumenite Kernel, use a low value (e.g. 1.0).";
    ui_min = 0.0; ui_max = 1000.0;
    ui_category = "Limits";
> = 250.0;

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

bool fbm_has_depth(float z)
{
    return z > 1e-4 && z < 0.999;
}

float3 fbm_kernel_geo(float2 uv)
{
    float3 n = tex2Dlod(Kernel::sNormals, float4(uv, 0, 0)).rgb;
    float len = length(n);
    return (len > 1e-4) ? n / len : float3(0.0, 0.0, 1.0);
}

float3 fbm_kernel_macro(float2 uv)
{
    float2 d = BUFFER_PIXEL_SIZE * 4.0;
    float3 n = fbm_kernel_geo(uv) * 4.0;
    n += fbm_kernel_geo(uv + float2(d.x, 0.0));
    n += fbm_kernel_geo(uv - float2(d.x, 0.0));
    n += fbm_kernel_geo(uv + float2(0.0, d.y));
    n += fbm_kernel_geo(uv - float2(0.0, d.y));
    return normalize(n);
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

float3 fbm_Ng(float2 uv)
{
    [branch]
    if(UI_PROVIDER == 1)
    {
        float3 kn = fbm_kernel_geo(uv);
        return (UI_KERNEL_BUMP <= 0.001) ? fbm_kernel_macro(uv) : kn;
    }

    float3 g = Deferred::get_geometry_normals(uv);
    float3 t = Deferred::get_normals(uv);
    return dot(g, g) > 1e-4 ? normalize(g) : normalize(t);
}

float3 fbm_Nt(float2 uv)
{
    [branch]
    if(UI_PROVIDER == 1)
    {
        float3 kn = fbm_kernel_geo(uv);
        return (UI_KERNEL_BUMP <= 0.001) ? kn : fbm_kernel_bump(uv, kn);
    }
    return normalize(Deferred::get_normals(uv));
}

float fbm_on_plane(float2 uv, float3 p, float3 n)
{
    float z = Depth::get_linear_depth(uv);
    if(!fbm_has_depth(z))
        return 0.0;
    float3 q = Camera::uv_to_proj(uv, Camera::depth_to_z(z));
    return saturate(1.0 - abs(dot(q - p, n)) / (0.035 * max(abs(p.z), 1.0)));
}

float3 fbm_view_p(float2 uv)
{
    float z = Depth::get_linear_depth(uv);
    return Camera::uv_to_proj(uv, Camera::depth_to_z(z));
}

float3 fbm_raw_Ng(float2 uv)
{
    float2 d = BUFFER_PIXEL_SIZE * 2.0;
    float3 p  = fbm_view_p(uv);
    float3 pr = fbm_view_p(uv + float2(d.x, 0.0));
    float3 pu = fbm_view_p(uv + float2(0.0, d.y));
    float3 n = cross(pr - p, pu - p);
    float len = length(n);
    return (len > 1e-12) ? n / len : float3(0.0, 0.0, 1.0);
}

float fbm_tap_crease(float2 uv1, float z0, float3 n_plane, float3 n_raw0, float facing)
{
    if(!Math::inside_screen(uv1))
        return 0.0;
    float z1 = Depth::get_linear_depth(uv1);
    if(!fbm_has_depth(z1))
        return 0.0;
    float rel = (z1 - z0) / max(z0, 1e-4);
    if(rel < -0.012)
        return 0.0;

    float n_lp = saturate((0.76 - saturate(dot(n_plane, fbm_Ng(uv1)))) / 0.30);
    float n_rw = saturate((0.88 - saturate(dot(n_raw0, fbm_raw_Ng(uv1)))) / 0.32);
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

float fbm_gauss_axis(sampler2D samp, float2 uv, float2 axis)
{
    float z = Depth::get_linear_depth(uv);
    float acc = 0.0;
    float wsum = 1e-4;

    [loop]
    for(int k = -8; k <= 8; k++)
    {
        float2 uvk = uv + axis * k;
        if(!Math::inside_screen(uvk))
            continue;
        float zk = Depth::get_linear_depth(uvk);
        float rel = (zk - z) / max(z, 1e-4);
        if(rel < -0.012)
            continue;
        float wk = exp(-k * k * 0.018);
        acc += tex2Dlod(samp, uvk, 0).r * wk;
        wsum += wk;
    }
    return acc / wsum;
}

/*=============================================================================
	Passes
=============================================================================*/

void PS_Edge(VSOut i, out float4 o : SV_Target0)
{
    float z = Depth::get_linear_depth(i.uv);
    [branch]
    if(!fbm_has_depth(z))
    {
        o = 0.0;
        return;
    }

    float3 p0      = fbm_view_p(i.uv);
    float3 n_plane = fbm_Ng(i.uv);
    float3 n_raw   = fbm_raw_Ng(i.uv);
    float  facing  = saturate((abs(dot(n_plane, normalize(-p0))) - 0.16) / 0.28);
    float2 px = BUFFER_PIXEL_SIZE;
    float e = 0.0;

    e = max(e, fbm_tap_crease(i.uv + float2( px.x,  0.0) * 1.0, z, n_plane, n_raw, facing));
    e = max(e, fbm_tap_crease(i.uv + float2(-px.x,  0.0) * 1.0, z, n_plane, n_raw, facing));
    e = max(e, fbm_tap_crease(i.uv + float2( 0.0,  px.y) * 1.0, z, n_plane, n_raw, facing));
    e = max(e, fbm_tap_crease(i.uv + float2( 0.0, -px.y) * 1.0, z, n_plane, n_raw, facing));
    e = max(e, fbm_tap_crease(i.uv + float2( px.x,  0.0) * 3.0, z, n_plane, n_raw, facing));
    e = max(e, fbm_tap_crease(i.uv + float2(-px.x,  0.0) * 3.0, z, n_plane, n_raw, facing));
    e = max(e, fbm_tap_crease(i.uv + float2( 0.0,  px.y) * 3.0, z, n_plane, n_raw, facing));
    e = max(e, fbm_tap_crease(i.uv + float2( 0.0, -px.y) * 3.0, z, n_plane, n_raw, facing));

    e = smoothstep(0.12, 0.48, e);
    o = float4(e, e, e, 1.0);
}

void PS_BlurH(VSOut i, out float4 o : SV_Target0)
{
    float e = fbm_gauss_axis(FBM_EdgeSamp, i.uv, float2(BUFFER_PIXEL_SIZE.x, 0.0));
    o = float4(e, e, e, 1.0);
}

void PS_BlurV(VSOut i, out float4 o : SV_Target0)
{
    float e = fbm_gauss_axis(FBM_BlurSamp, i.uv, float2(0.0, BUFFER_PIXEL_SIZE.y));
    o = float4(e, e, e, 1.0);
}

void PS_Map(VSOut i, out float3 o : SV_Target0)
{
    float3 src = tex2Dlod(ColorInput, i.uv, 0).rgb;
    o = src;

    float z = Depth::get_linear_depth(i.uv);
    [branch]
    if(!fbm_has_depth(z))
        return;

    float fade = saturate(1.0 - (z - UI_FADE_START) / max(UI_FADE_LEN, 1e-4));
    float hud  = fbm_hud(i.uv);

    float3 p  = Camera::uv_to_proj(i.uv, Camera::depth_to_z(z));
    float3 ng = fbm_Ng(i.uv);
    float3 nt = fbm_Nt(i.uv);
    float3 col0 = src;
    float  lum0 = dot(src, FBM_LUMA);

    float3 g0;
    {
        float3 a = Deferred::get_albedo(i.uv);
        g0 = dot(a, 1.0) > 1e-5 ? a : src;
    }
    float lg = max(dot(g0, FBM_LUMA), 1e-3);
    float2 chroma0 = g0.rg / lg;

    float4 nacc = 0.0;
    float2 pacc = float2(0.0, 1e-4);
    float  occ  = 0.0;
    float2 chr_src = src.rg / max(lum0, 1e-3);
    float2 acc_f = 0.0;
    float3 acc_w = 0.0;

    [loop]
    for(int s = 0; s < 8; s++)
    {
        float ang = 0.78539816 * (s + 0.5);
        float2 dir; sincos(ang, dir.y, dir.x);

        float2 uv_p = i.uv + dir * 32.0 * BUFFER_PIXEL_SIZE;
        if(Math::inside_screen(uv_p))
        {
            float zp = Depth::get_linear_depth(uv_p);
            float rp = (zp - z) / max(z, 1e-4);
            if(rp > -0.012)
            {
                float pw = fbm_on_plane(uv_p, p, ng);
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
            float rn = (zn - z) / max(z, 1e-4);
            if(rn < -0.010)
                occ = max(occ, saturate((-rn - 0.010) / 0.035));
            else if(fbm_on_plane(uv_n, p, ng) > 0.2)
            {
                float3 a1 = Deferred::get_albedo(uv_n);
                if(dot(a1, 1.0) < 1e-5)
                    a1 = tex2Dlod(ColorInput, uv_n, 0).rgb;
                float l1 = max(dot(a1, FBM_LUMA), 1e-3);
                float2 dc = a1.rg / l1 - chroma0;
                float wc = exp(-dot(dc, dc) * 40.0);
                nacc += float4(fbm_Nt(uv_n) * wc, wc);

                float3 c1 = tex2Dlod(ColorInput, uv_n, 0).rgb;
                float ln = max(dot(c1, FBM_LUMA), 1e-4);
                acc_f.x += abs(log2(ln) - log2(max(lum0, 1e-4)));
                acc_f.y += 1.0;
            }
        }

        float2 uv_e = i.uv + dir * 3.0 * BUFFER_PIXEL_SIZE;
        float2 uv_o = i.uv + dir * 6.0 * BUFFER_PIXEL_SIZE;
        float re = (Depth::get_linear_depth(uv_e) - z) / max(z, 1e-4);
        float ro = (Depth::get_linear_depth(uv_o) - z) / max(z, 1e-4);

        if(re < -0.010)
            occ = max(occ, saturate((-re - 0.010) / 0.035));
        if(ro < -0.010)
            occ = max(occ, saturate((-ro - 0.010) / 0.035) * 0.65);

        float2 uv_b = i.uv + dir * 10.0 * BUFFER_PIXEL_SIZE;
        if(Math::inside_screen(uv_b))
        {
            float zb = Depth::get_linear_depth(uv_b);
            float rb = (zb - z) / max(z, 1e-4);
            if(rb > -0.012 && fbm_on_plane(uv_b, p, ng) > 0.15)
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
    mask = saturate(lerp(1.0, mask * mask, UI_PLANAR));
    mask *= 1.0 - edge_feather;

    float w = fade * mask * hud;
    float2 uvh = i.uv;

    [branch]
    if(w > 0.002 && (UI_STRENGTH > 0.01 || UI_EXTEND > 0.05))
    {
        float3 V = normalize(-p);
        float3 Up = float3(0.0, 1.0, 0.0);
        float3 L = normalize(V + Up * 0.35 + ng * 0.15);

        [branch]
        if(UI_EXTEND > 0.05)
        {
            float3 T, B;
            fbm_tbn(i.uv, p, ng, T, B);
            float2 sl = -float2(dot(nt, T), dot(nt, B)) / max(dot(nt, ng), 0.22);
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
                    if(!Math::inside_screen(nxt) || fbm_on_plane(nxt, p, ng) < pmin)
                        break;
                    float z1 = Depth::get_linear_depth(nxt);
                    if(abs(z1 - z) / max(z, 1e-4) > zmax)
                        break;
                    uvh = nxt;
                }
            }
        }

        float3 samp = tex2Dlod(ColorInput, uvh, 0).rgb;
        float lum_s = dot(samp, FBM_LUMA);

        float geom = saturate(dot(ng, L)) + 0.28;
        float bump = saturate(dot(nt, L)) + 0.28;
        float ratio = bump / geom;

        float spec_g = pow(saturate(dot(ng, V)), 12.0);
        float spec_n = pow(saturate(dot(nt, V)), 12.0);
        float spec = max(spec_n - spec_g, 0.0) * UI_GLOSS;

        float ndot = saturate(dot(nt, ng));
        float cavity = (UI_CAVITY <= 0.001) ? 1.0 : pow(ndot, UI_CAVITY);

        float shade = lerp(1.0, ratio, UI_STRENGTH) * cavity;
        shade = clamp(shade, 0.20, 3.5);

        float hl = smoothstep(0.58, 0.92, lum_s);
        shade = lerp(shade, 1.0, hl);
        spec *= (1.0 - shadow);

        float lum1 = lum_s * shade + spec * lum_s * (1.0 - hl);
        float3 chroma = samp / max(lum_s, 1e-4);
        float3 col = chroma * lum1;

        o = lerp(src, col, w);
    }

    [branch]
    if(UI_VIEW == 1)
        o = fbm_encode_n(nt);
    else if(UI_VIEW == 2)
        o = saturate(0.5 * (saturate(dot(nt, normalize(-p))) + 0.28)
                   / (saturate(dot(ng, normalize(-p))) + 0.28)).xxx;
    else if(UI_VIEW == 3)
        o = lerp(float3(1, 0, 0), float3(mask, fade, 1.0 - edge_feather), hud);
    else if(UI_VIEW == 4)
        o = float3(saturate((uvh - i.uv) / BUFFER_PIXEL_SIZE * 0.12 + 0.5), 0.5);
}

/*=============================================================================
	Technique
=============================================================================*/

technique FakeBumpMap
<
    ui_label = "UniqFX: FakeBumpMap";
    ui_tooltip =
        "Relights large planes with a textured normal.\n"
        "Requires iMMERSE shaders installed: https://github.com/martymcmodding/iMMERSE\n"
        "Place below the chosen provider:\n"
        "- iMMERSE Launchpad: Smoothed + Textured Normal Map Mode.\n"
        "- LUMENITE Kernel 2.0: SMOOTH_NORMALS=1.\n"
        "With LUMENITE, set Large Planes to ~1.";
>
{
#ifdef IPC_REQUEST_FEATURE
    IPC_REQUEST_FEATURE(MARTYSMODS_IPC_FEATURE_NORMALS | MARTYSMODS_IPC_FEATURE_ALBEDO)
#endif
    pass Edge { VertexShader = VS_Full; PixelShader = PS_Edge; RenderTarget = FBM_EdgeTex; }
    pass BlurH { VertexShader = VS_Full; PixelShader = PS_BlurH; RenderTarget = FBM_BlurTex; }
    pass BlurV { VertexShader = VS_Full; PixelShader = PS_BlurV; RenderTarget = FBM_EdgeTex; }
    pass Map { VertexShader = VS_Full; PixelShader = PS_Map; }
}

// Copyright Inigo Quilez, 2016 - https://iquilezles.org/
// I am the sole copyright owner of this Work.
// You cannot host, display, distribute or share this Work in any form,
// including physical and digital. You cannot use this Work in any
// commercial or non-commercial product, website or project. You cannot
// sell this Work and you cannot mint an NFTs of it.
// I share this Work for educational purposes, and you can link to it,
// through an URL, proper attribution and unmodified screenshot, as part
// of your educational material. If these conditions are too restrictive
// please contact me and we'll definitely work it out.

// on the derivatives based noise: https://iquilezles.org/articles/morenoise
// on the soft shadow technique: https://iquilezles.org/articles/rmshadows
// on the fog calculations: https://iquilezles.org/articles/fog
// on the lighting: https://iquilezles.org/articles/outdoorslighting
// on the raymarching: https://iquilezles.org/articles/terrainmarching

import Shadertoy;
import GBuffer;

#define AA 0   // make this 2 or even 3 if you have a really powerful GPU

#define USE_SMOOTH_NOISE 0   // enable to prevent discontinuities

#define SC (250.0)

// value noise, and its analytical derivatives
float3 noised( in float2 x )
{
    float2 f = frac(x);
#if USE_SMOOTH_NOISE==0
    float2 u = f*f*(3.0-2.0*f);
    float2 du = 6.0*f*(1.0-f);
#else
    float2 u = f * f * f * (f * (f * 6.0-15.0) + 10.0);
    float2 du = 30.0 * f * f * ( f *(f - 2.0)+1.0);
#endif

    // texel fetch version
    int2 p = int2(floor(x));
    float a = gBlueNoiseTex.Load(int3((p + int2(0, 0)) & 255, 0)).x;
    float b = gBlueNoiseTex.Load(int3((p + int2(1, 0)) & 255, 0)).x;
    float c = gBlueNoiseTex.Load(int3((p + int2(0, 1)) & 255, 0)).x;
    float d = gBlueNoiseTex.Load(int3((p + int2(1, 1)) & 255, 0)).x;
    
	return float3(a + (b - a) * u.x + (c - a) * u.y + (a - b - c + d) * u.x * u.y,
				du*(float2(b-a,c-a)+(a-b-c+d)*u.yx));
}

static const float2x2 m2 = float2x2(0.8,-0.6,0.6,0.8);

float terrainH( in float2 x )
{
	float2  p = x * 0.003 / SC;
    float a = 0.0;
    float b = 1.0;
	float2 d = float2(0.0);
    for( int i=0; i<16; i++ )
    {
        float3 n = noised(p);
        d += n.yz;
        a += b*n.x/(1.0+dot(d,d));
		b *= 0.5;
        p = mul(p, m2) * 2.0;
    }

    #if USE_SMOOTH_NOISE==1
    a *= 0.9;
    #endif
	return SC*120.0*a;
}

float terrainM( in float2 x )
{
	float2 p = x * 0.003 / SC;
    float a = 0.0;
    float b = 1.0;
	float2  d = float2(0.0);
    for (int i = 0; i < 9; i++)
    {
        float3 n = noised(p);
        d += n.yz;
        a += b*n.x/(1.0+dot(d,d));
        b *= 0.5;
        p = mul(p, m2) * 2.0;
    }
#if USE_SMOOTH_NOISE == 1
    a *= 0.9;
#endif
	return SC * 120.0 * a;
}

float terrainL( in float2 x )
{
	float2  p = x*0.003/SC;
    float a = 0.0;
    float b = 1.0;
	float2  d = float2(0.0);
    for (int i = 0; i < 3; i++)
    {
        float3 n = noised(p);
        d += n.yz;
        a += b*n.x/(1.0+dot(d,d));
        b *= 0.5;
        p = mul(p, m2) * 2.0;
    }
    #if USE_SMOOTH_NOISE==1
    a *= 0.9;
    #endif
	return SC*120.0*a;
}

float raycast( in float3 ro, in float3 rd, in float tmin, in float tmax )
{
    float t = tmin;
	for( int i=0; i<300; i++ )
	{
        float3 pos = ro + t*rd;
		float h = pos.y - terrainM( pos.xz );
		if( abs(h)<(0.0015*t) || t>tmax ) break;
		t += 0.4*h;
	}

	return t;
}

float softShadow(in float3 ro, in float3 rd, float dis )
{
    float minStep = clamp(dis*0.01,SC*0.5,SC*50.0);

    float res = 1.0;
    float t = 0.001;
	for( int i=0; i<80; i++ )
	{
	    float3  p = ro + t*rd;
        float h = p.y - terrainM( p.xz );
		res = min( res, 16.0*h/t );
		t += max(minStep,h);
		if( res<0.001 ||p.y>(SC*200.0) ) break;
	}
	return clamp( res, 0.0, 1.0 );
}

float3 calcNormal( in float3 pos, float t )
{
    float2  eps = float2( 0.001*t, 0.0 );
    return normalize( float3( terrainH(pos.xz-eps.xy) - terrainH(pos.xz+eps.xy),
                            2.0*eps.x,
                            terrainH(pos.xz-eps.yx) - terrainH(pos.xz+eps.yx) ) );
}

float fbm( float2 p )
{
    float f = 0.0;
    f += 0.5000 * gBlueNoiseTex.SampleLevel(gLinearRepeatSampler, p / 256.0f, 0.0f).x; p = mul(p, m2) * 2.02;
    f += 0.2500 * gBlueNoiseTex.SampleLevel(gLinearRepeatSampler, p / 256.0f, 0.0f).x; p = mul(p, m2) * 2.03;
    f += 0.1250 * gBlueNoiseTex.SampleLevel(gLinearRepeatSampler, p / 256.0f, 0.0f).x; p = mul(p, m2) * 2.01;
    f += 0.0625 * gBlueNoiseTex.SampleLevel(gLinearRepeatSampler, p / 256.0f, 0.0f).x;
    return f / 0.9375;
}

static const float kMaxT = 5000.0 * SC;

float4 render(in float3 ro, in float3 rd, inout GBuffer gbuffer)
{
    float3 light1 = normalize(float3(-0.8,0.4,-0.3));
    // bounding plane
    float tmin = 1.0;
    float tmax = kMaxT;

#if 1
    float maxh = 250.0 * SC;
    float tp = (maxh - ro.y) / rd.y;
    if(tp > 0.0)
    {
        if (ro.y > maxh)
        {
            tmin = max(tmin, tp);
        }
        else
        {
            tmax = min(tmax, tp);
        }
    }
#endif

	float sundot = clamp(dot(rd,light1),0.0,1.0);
	float3 col;
    float t = raycast(ro, rd, tmin, tmax);
    
    gbuffer.V = -rd;

    if(t > tmax)
    {
        // sky		
        col = float3(0.3, 0.5, 0.85) - rd.y * rd.y * 0.5;
        col = lerp( col, 0.85*float3(0.7,0.75,0.85), pow( 1.0-max(rd.y,0.0), 4.0 ) );
        // sun
		col += 0.25 * float3(1.0,0.7,0.4) * pow(sundot, 5.0 );
		col += 0.25 * float3(1.0,0.8,0.6) * pow(sundot, 64.0 );
		col += 0.2*float3(1.0,0.8,0.6) * pow(sundot,512.0 );
        // clouds
		float2 sc = ro.xz + rd.xz*(SC*1000.0-ro.y)/rd.y;
		col = lerp( col, float3(1.0,0.95,1.0), 0.5*smoothstep(0.5,0.8,fbm(0.0005*sc/SC)) );
        // horizon
        col = lerp( col, 0.68*float3(0.4,0.65,1.0), pow( 1.0-max(rd.y,0.0), 16.0 ) );
        t = -1.0;
	}
	else
	{
        // mountains		
		float3 pos = ro + t*rd;
        float3 nor = calcNormal( pos, t );
        //nor = normalize( nor + 0.5*( float3(-1.0,0.0,-1.0) + float3(2.0,1.0,2.0)*texture(iChannel1,0.01*pos.xz).xyz) );
        float3 ref = reflect( rd, nor );
        float fre = clamp(1.0 + dot(rd, nor), 0.0, 1.0 );
        float3 hal = normalize(light1 - rd);

        gbuffer.posW = pos;
        gbuffer.normal = nor;

        // rock
        float r = gBlueNoiseTex.SampleLevel(gLinearRepeatSampler, (7.0 / SC) * pos.xz / 256.0, 0.0f).x;
        col = (r * 0.25 + 0.75) * 0.9 * lerp(float3(0.08, 0.05, 0.03), float3(0.10, 0.09, 0.08), 
                                     gBlueNoiseTex.SampleLevel(gLinearRepeatSampler, 0.00007 * float2(pos.x, pos.y * 48.0) / SC, 0.0f).x);
		col = lerp( col, 0.20*float3(0.45, .30, 0.15) * (0.50 + 0.50 * r), smoothstep(0.70,0.9,nor.y) );
        
        
        col = lerp( col, 0.15*float3(0.30,.30,0.10)*(0.25+0.75*r),smoothstep(0.95,1.0,nor.y) );
		col *= 0.1+1.8*sqrt(fbm(pos.xz*0.04)*fbm(pos.xz*0.005));

		// snow
		float h = smoothstep(55.0,80.0,pos.y/SC + 25.0*fbm(0.01*pos.xz/SC) );
        float e = smoothstep(1.0-0.5*h,1.0-0.1*h,nor.y);
        float o = 0.3 + 0.7*smoothstep(0.0,0.1,nor.x+h*h);
        float s = h*e*o;
        col = lerp( col, 0.29*float3(0.62,0.65,0.7), smoothstep( 0.1, 0.9, s ) );

        gbuffer.diffuse = col;

         // lighting		
        float amb = clamp(0.5+0.5*nor.y,0.0,1.0);
		float dif = clamp( dot( light1, nor ), 0.0, 1.0 );
		float bac = clamp( 0.2 + 0.8*dot( normalize( float3(-light1.x, 0.0, light1.z ) ), nor ), 0.0, 1.0 );
		float sh = 1.0; if( dif>=0.0001 ) sh = softShadow(pos+light1*SC*0.05,light1,t);
		
		float3 lin  = float3(0.0);
		lin += dif*float3(8.00,5.00,3.00)*1.3*float3( sh, sh*sh*0.5+0.5*sh, sh*sh*0.8+0.2*sh );
		lin += amb*float3(0.40,0.60,1.00)*1.2;
        lin += bac*float3(0.40,0.50,0.60);
		col *= lin;
        
        col += (0.7+0.3*s)*(0.04+0.96*pow(clamp(1.0+dot(hal,rd),0.0,1.0),5.0))*
               float3(7.0,5.0,3.0) * dif * sh *
               pow( clamp(dot(nor,hal), 0.0, 1.0),16.0);

        col += s * 0.65 * pow(fre, 4.0) * float3(0.3, 0.5, 0.6) * smoothstep(0.0, 0.6, ref.y);
        gbuffer.specular = float3(0.3, 0.5, 0.6) * smoothstep(0.0, 0.6, ref.y);

        //col = col*3.0/(1.5+col);
        
		// fog
        float fo = 1.0 - exp(-pow(0.001 * t / SC, 1.5));
        float3 fco = 0.65 * float3(0.4, 0.65, 1.0);// + 0.1*float3(1.0,0.8,0.5)*pow( sundot, 4.0 );
        col = lerp(col, fco, fo);
	}

    // sun scatter
    col += 0.3 * float3(1.0, 0.7, 0.3) * pow(sundot, 8.0 );

    // gamma
	col = sqrt(col);
    
	return float4( col, t );
}

float3 camPath( float time )
{
	return SC*1100.0*float3( cos(0.0+0.23*time), 0.0, cos(1.5+0.21*time) );
}

float3x3 setCamera( in float3 ro, in float3 ta, in float cr )
{
	float3 cw = normalize(ta-ro);
	float3 cp = float3(sin(cr), cos(cr),0.0);
	float3 cu = normalize( cross(cw,cp) );
	float3 cv = normalize( cross(cu,cw) );
    return float3x3( cu, cv, cw );
}

void moveCamera( float time, out float3 oRo, out float3 oTa, out float oCr, out float oFl )
{
	float3 ro = camPath( time );
	float3 ta = camPath( time + 3.0 );
	ro.y = terrainL( ro.xz ) + 22.0*SC;
	ta.y = ro.y - 20.0*SC;
	float cr = 0.2*cos(0.1*time);
    oRo = ro;
    oTa = ta;
    oCr = cr;
    oFl = 3.0;
}

GBuffer mainImage( out float4 fragColor, in float2 fragCoord )
{
    GBuffer gbuffer = (GBuffer)0;
    float time = iTime * 0.1 - 0.1 + 0.3 + 2.0;

    // camera position
    float3 ro, ta; float cr, fl;
    moveCamera( time, ro, ta, cr, fl );

    // camera2world transform    
    float3x3 cam = setCamera( ro, ta, cr );

    // pixel
    float2 p = (-iResolution.xy + 2.0 * fragCoord) / iResolution.y;

    float t = kMaxT;
    float3 tot = float3(0.0); 
    float2 s = p;

    // camera ray
    float3 rd = mul(normalize(float3(s, fl)), cam);
    float4 res = render(ro, rd, gbuffer);
    t = min( t, res.w );
    tot += res.xyz;

    fragColor = float4( tot, 1 );

    return gbuffer;
}
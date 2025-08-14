import Shadertoy;

// #define LOWQUALITY

//==========================================================================================
// general utilities
//==========================================================================================
#define ZERO (min(iFrame,0))

float sdEllipsoidY( in float3 p, in float2 r )
{
    float k0 = length(p / r.xyx);
    float k1 = length(p / (r.xyx * r.xyx));
    return k0 * (k0 - 1.0) / k1;
}
float sdEllipsoid( in float3 p, in float3 r )
{
    float k0 = length(p / r);
    float k1 = length(p / (r * r));
    return k0 * (k0 - 1.0) / k1;
}

// return smoothstep and its derivative
float2 smoothstepd( float a, float b, float x)
{
	if( x<a ) return float2( 0.0, 0.0 );
	if( x>b ) return float2( 1.0, 0.0 );
    float ir = 1.0/(b-a);
    x = (x-a)*ir;
    return float2( x*x*(3.0-2.0*x), 6.0*x*(1.0-x)*ir );
}

float3x3 setCamera( in float3 ro, in float3 ta, float cr )
{
	float3 cw = normalize(ta-ro);
	float3 cp = float3(sin(cr), cos(cr),0.0);
	float3 cu = normalize( cross(cw,cp) );
	float3 cv = normalize( cross(cu,cw) );
    return float3x3( cu, cv, cw );
}

//==========================================================================================
// hashes (low quality, do NOT use in production)
//==========================================================================================

float hash1( float2 p )
{
    p = 50.0 * frac(p * 0.3183099);
    return frac( p.x*p.y*(p.x+p.y) );
}

float hash1( float n )
{
    return frac( n*17.0*frac( n*0.3183099 ) );
}

float2 hash2( float2 p ) 
{
    const float2 k = float2( 0.3183099, 0.3678794 );
    float n = 111.0*p.x + 113.0*p.y;
    return frac(n*frac(k*n));
}

//==========================================================================================
// noises
//==========================================================================================

// value noise, and its analytical derivatives
float4 noised( in float3 x )
{
    float3 p = floor(x);
    float3 w = frac(x);
    #if 1
    float3 u = w*w*w*(w*(w*6.0-15.0)+10.0);
    float3 du = 30.0*w*w*(w*(w-2.0)+1.0);
    #else
    float3 u = w*w*(3.0-2.0*w);
    float3 du = 6.0*w*(1.0-w);
    #endif

    float n = p.x + 317.0*p.y + 157.0*p.z;
    
    float a = hash1(n+0.0);
    float b = hash1(n+1.0);
    float c = hash1(n+317.0);
    float d = hash1(n+318.0);
    float e = hash1(n+157.0);
	float f = hash1(n+158.0);
    float g = hash1(n+474.0);
    float h = hash1(n+475.0);

    float k0 =   a;
    float k1 =   b - a;
    float k2 =   c - a;
    float k3 =   e - a;
    float k4 =   a - b - c + d;
    float k5 =   a - c - e + g;
    float k6 =   a - b - e + f;
    float k7 = - a + b + c - d + e - f - g + h;

    return float4( -1.0+2.0*(k0 + k1*u.x + k2*u.y + k3*u.z + k4*u.x*u.y + k5*u.y*u.z + k6*u.z*u.x + k7*u.x*u.y*u.z), 
                      2.0* du * float3( k1 + k4*u.y + k6*u.z + k7*u.y*u.z,
                                      k2 + k5*u.z + k4*u.x + k7*u.z*u.x,
                                      k3 + k6*u.x + k5*u.y + k7*u.x*u.y ) );
}

float noise( in float3 x )
{
    float3 p = floor(x);
    float3 w = frac(x);
    
    #if 1
    float3 u = w*w*w*(w*(w*6.0-15.0)+10.0);
    #else
    float3 u = w*w*(3.0-2.0*w);
    #endif
    


    float n = p.x + 317.0*p.y + 157.0*p.z;
    
    float a = hash1(n+0.0);
    float b = hash1(n+1.0);
    float c = hash1(n+317.0);
    float d = hash1(n+318.0);
    float e = hash1(n+157.0);
	float f = hash1(n+158.0);
    float g = hash1(n+474.0);
    float h = hash1(n+475.0);

    float k0 =   a;
    float k1 =   b - a;
    float k2 =   c - a;
    float k3 =   e - a;
    float k4 =   a - b - c + d;
    float k5 =   a - c - e + g;
    float k6 =   a - b - e + f;
    float k7 = - a + b + c - d + e - f - g + h;

    return -1.0+2.0*(k0 + k1*u.x + k2*u.y + k3*u.z + k4*u.x*u.y + k5*u.y*u.z + k6*u.z*u.x + k7*u.x*u.y*u.z);
}

float3 noised( in float2 x )
{
    float2 p = floor(x);
    float2 w = frac(x);
    #if 1
    float2 u = w*w*w*(w*(w*6.0-15.0)+10.0);
    float2 du = 30.0*w*w*(w*(w-2.0)+1.0);
    #else
    float2 u = w*w*(3.0-2.0*w);
    float2 du = 6.0*w*(1.0-w);
    #endif
    
    float a = hash1(p+float2(0,0));
    float b = hash1(p+float2(1,0));
    float c = hash1(p+float2(0,1));
    float d = hash1(p+float2(1,1));

    float k0 = a;
    float k1 = b - a;
    float k2 = c - a;
    float k4 = a - b - c + d;

    return float3( -1.0+2.0*(k0 + k1*u.x + k2*u.y + k4*u.x*u.y), 
                 2.0*du * float2( k1 + k4*u.y,
                            k2 + k4*u.x ) );
}

float noise( in float2 x )
{
    float2 p = floor(x);
    float2 w = frac(x);
    #if 1
    float2 u = w*w*w*(w*(w*6.0-15.0)+10.0);
    #else
    float2 u = w*w*(3.0-2.0*w);
    #endif

    float a = hash1(p+float2(0,0));
    float b = hash1(p+float2(1,0));
    float c = hash1(p+float2(0,1));
    float d = hash1(p+float2(1,1));
    
    return -1.0+2.0*(a + (b-a)*u.x + (c-a)*u.y + (a - b - c + d)*u.x*u.y);
}

//==========================================================================================
// fbm constructions
//==========================================================================================

static const float3x3 m3 = float3x3(0.00, 0.80, 0.60,
                                    -0.80, 0.36, -0.48,
                                    -0.60, -0.48, 0.64);
static const float3x3 m3i = float3x3(0.00, -0.80, -0.60,
                                     0.80, 0.36, -0.48,
                                     0.60, -0.48, 0.64);
static const float2x2 m2 = float2x2(0.80, 0.60,
                                    -0.60, 0.80);
static const float2x2 m2i = float2x2( 0.80, -0.60,
                       0.60,  0.80 );

//------------------------------------------------------------------------------------------

float fbm_4( in float2 x )
{
    float f = 1.9;
    float s = 0.55;
    float a = 0.0;
    float b = 0.5;
    for( int i=ZERO; i<4; i++ )
    {
        float n = noise(x);
        a += b*n;
        b *= s;
        x = f * mul(x, m2);
    }
	return a;
}

float fbm_4( in float3 x )
{
    float f = 2.0;
    float s = 0.5;
    float a = 0.0;
    float b = 0.5;
    for( int i=ZERO; i<4; i++ )
    {
        float n = noise(x);
        a += b*n;
        b *= s;
        x = f * mul(x, m3);
    }
	return a;
}

float4 fbmd_7( in float3 x )
{
    float f = 1.92;
    float s = 0.5;
    float a = 0.0;
    float b = 0.5;
    float3  d = float3(0.0);
    float3x3  m = float3x3(1.0,0.0,0.0,
                   0.0,1.0,0.0,
                   0.0,0.0,1.0);
    for( int i=ZERO; i<7; i++ )
    {
        float4 n = noised(x);
        a += b * n.x; // accumulate values
        d += b * mul(n.yzw, m); // accumulate derivatives
        b *= s;
        x = f * mul(x, m3);
        m = f*m3i*m;
    }
	return float4( a, d );
}

float4 fbmd_8( in float3 x )
{
    float f = 2.0;
    float s = 0.65;
    float a = 0.0;
    float b = 0.5;
    float3  d = float3(0.0);
    float3x3  m = float3x3(1.0,0.0,0.0,
                   0.0,1.0,0.0,
                   0.0,0.0,1.0);
    for( int i=ZERO; i<8; i++ )
    {
        float4 n = noised(x);
        a += b*n.x;          // accumulate values
        if (i < 4)
            d += b * mul(n.yzw, m);  // accumulate derivatives
        b *= s;
        x = f * mul(x, m3);
        m = f*m3i*m;
    }
	return float4( a, d );
}

float fbm_9( in float2 x )
{
    float f = 1.9;
    float s = 0.55;
    float a = 0.0;
    float b = 0.5;
    for(int i = ZERO; i < 9; i++)
    {
        float n = noise(x);
        a += b*n;
        b *= s;
        x = f * mul(x, m2);
    }
    
	return a;
}

float3 fbmd_9( in float2 x )
{
    float f = 1.9;
    float s = 0.55;
    float a = 0.0;
    float b = 0.5;
    float2  d = float2(0.0);
    float2x2  m = float2x2(1.0,0.0,0.0,1.0);
    for( int i=ZERO; i<9; i++ )
    {
        float3 n = noised(x);
        a += b * n.x; // accumulate values
        d += b * mul(n.yz, m); // accumulate derivatives
        b *= s;
        x = f * mul(x, m2);
        m = f*m2i*m;
    }

	return float3( a, d );
}

//==========================================================================================
// specifics to the actual painting
//==========================================================================================


//------------------------------------------------------------------------------------------
// global
//------------------------------------------------------------------------------------------

static const float3 kSunDir = float3(-0.624695, 0.468521, -0.624695);
static const float kMaxTreeHeight = 4.8;
static const float kMaxHeight = 840.0;

float3 fog( in float3 col, float t )
{
    float3 ext = exp2(-t*0.00025*float3(1,1.5,4)); 
    return col*ext + (1.0-ext)*float3(0.55,0.55,0.58); // 0.55
}

//------------------------------------------------------------------------------------------
// clouds
//------------------------------------------------------------------------------------------

float4 cloudsFbm( in float3 pos )
{
    return fbmd_8(pos*0.0015+float3(2.0,1.1,1.0)+0.07*float3(iTime,0.5*iTime,-0.15*iTime));
}

float4 cloudsMap( in float3 pos, out float nnd )
{
    float d = abs(pos.y-900.0)-40.0;
    float3 gra = float3(0.0,sign(pos.y-900.0),0.0);
    
    float4 n = cloudsFbm(pos);
    d += 400.0*n.x * (0.7+0.3*gra.y);
    
    if( d>0.0 ) return float4(-d,0.0,0.0,0.0);
    
    nnd = -d;
    d = min(-d/100.0,0.25);
    
    //gra += 0.1*n.yzw *  (0.7+0.3*gra.y);
    
    return float4( d, gra );
}

float cloudsShadowFlat( in float3 ro, in float3 rd )
{
    float t = (900.0-ro.y)/rd.y;
    if( t<0.0 ) return 1.0;
    float3 pos = ro + rd*t;
    return cloudsFbm(pos).x;
}

float terrainShadow( in float3 ro, in float3 rd, in float mint );

float4 renderClouds( in float3 ro, in float3 rd, float tmin, float tmax, inout float resT, in float2 px )
{
    float4 sum = float4(0.0);

    // bounding volume!!
    float tl = ( 600.0-ro.y)/rd.y;
    float th = (1200.0-ro.y)/rd.y;
    if( tl>0.0 ) tmin = max( tmin, tl ); else return sum;
    if( th>0.0 ) tmax = min( tmax, th );

    float t = tmin;
    //t += 1.0*hash1(gl_FragCoord.xy);
    float lastT = -1.0;
    float thickness = 0.0;
    for(int i=ZERO; i<128; i++)
    { 
        float3  pos = ro + t*rd; 
        float nnd;
        float4  denGra = cloudsMap( pos, nnd ); 
        float den = denGra.x;
        float dt = max(0.2,0.011*t);
        //dt *= hash1(px+float(i));
        if( den>0.001 ) 
        { 
            float kk;
            cloudsMap( pos+kSunDir*70.0, kk );
            float sha = 1.0-smoothstep(-200.0,200.0,kk); sha *= 1.5;
            
            float3 nor = normalize(denGra.yzw);
            float dif = clamp( 0.4+0.6*dot(nor,kSunDir), 0.0, 1.0 )*sha; 
            float fre = clamp( 1.0+dot(nor,rd), 0.0, 1.0 )*sha;
            float occ = 0.2+0.7*max(1.0-kk/200.0,0.0) + 0.1*(1.0-den);
            // lighting
            float3 lin  = float3(0.0);
                 lin += float3(0.70,0.80,1.00)*1.0*(0.5+0.5*nor.y)*occ;
                 lin += float3(0.10,0.40,0.20)*1.0*(0.5-0.5*nor.y)*occ;
                 lin += float3(1.00,0.95,0.85)*3.0*dif*occ + 0.1;

            // color
            float3 col = float3(0.8,0.8,0.8)*0.45;

            col *= lin;

            col = fog( col, t );

            // front to back blending    
            float alp = clamp(den*0.5*0.125*dt,0.0,1.0);
            col.rgb *= alp;
            sum = sum + float4(col,alp)*(1.0-sum.a);

            thickness += dt*den;
            if( lastT<0.0 ) lastT = t;            
        }
        else 
        {
            dt = abs(den)+0.2;

        }
        t += dt;
        if( sum.a>0.995 || t>tmax ) break;
    }
    
    //resT = min(resT, (150.0-ro.y)/rd.y );
    if( lastT>0.0 ) resT = min(resT,lastT);
    //if( lastT>0.0 ) resT = lerp( resT, lastT, sum.w );
    
    
    sum.xyz += max(0.0,1.0-0.0125*thickness)*float3(1.00,0.60,0.40)*0.3*pow(clamp(dot(kSunDir,rd),0.0,1.0),32.0);

    return clamp( sum, 0.0, 1.0 );
}


//------------------------------------------------------------------------------------------
// terrain
//------------------------------------------------------------------------------------------

float2 terrainMap( in float2 p )
{
    float e = fbm_9( p/2000.0 + float2(1.0,-2.0) );
    float a = 1.0-smoothstep( 0.12, 0.13, abs(e+0.12) ); // flag high-slope areas (-0.25, 0.0)
    e = 600.0*e + 600.0;
    
    // cliff
    e += 90.0*smoothstep( 552.0, 594.0, e );
    //e += 90.0*smoothstep( 550.0, 600.0, e );
    
    return float2(e,a);
}

float4 terrainMapD( in float2 p )
{
    float3 e = fbmd_9( p/2000.0 + float2(1.0,-2.0) );
    e.x  = 600.0*e.x + 600.0;
    e.yz = 600.0*e.yz;

    // cliff
    float2 c = smoothstepd( 550.0, 600.0, e.x );
	e.x  = e.x  + 90.0*c.x;
	e.yz = e.yz + 90.0*c.y*e.yz;     // chain rule
    
    e.yz /= 2000.0;
    return float4( e.x, normalize( float3(-e.y,1.0,-e.z) ) );
}

float3 terrainNormal( in float2 pos )
{
#if 1
    return terrainMapD(pos).yzw;
#else    
    float2 e = float2(0.03,0.0);
	return normalize( float3(terrainMap(pos-e.xy).x - terrainMap(pos+e.xy).x,
                           2.0*e.x,
                           terrainMap(pos-e.yx).x - terrainMap(pos+e.yx).x ) );
#endif    
}

float terrainShadow( in float3 ro, in float3 rd, in float mint )
{
    float res = 1.0;
    float t = mint;
#ifdef LOWQUALITY
    for( int i=ZERO; i<32; i++ )
    {
        float3  pos = ro + t*rd;
        float2  env = terrainMap( pos.xz );
        float hei = pos.y - env.x;
        res = min( res, 32.0*hei/t );
        if( res<0.0001 || pos.y>kMaxHeight ) break;
        t += clamp( hei, 2.0+t*0.1, 100.0 );
    }
#else
    for( int i=ZERO; i<128; i++ )
    {
        float3  pos = ro + t*rd;
        float2  env = terrainMap( pos.xz );
        float hei = pos.y - env.x;
        res = min( res, 32.0*hei/t );
        if( res<0.0001 || pos.y>kMaxHeight  ) break;
        t += clamp( hei, 0.5+t*0.05, 25.0 );
    }
#endif
    return clamp( res, 0.0, 1.0 );
}

float2 raymarchTerrain( in float3 ro, in float3 rd, float tmin, float tmax )
{
    // bounding plane
    float tp = (kMaxHeight+kMaxTreeHeight-ro.y)/rd.y;
    if( tp>0.0 ) tmax = min( tmax, tp );
    
    // raymarch
    float dis, th;
    float t2 = -1.0;
    float t = tmin; 
    float ot = t;
    float odis = 0.0;
    float odis2 = 0.0;
    for( int i=ZERO; i<400; i++ )
    {
        th = 0.001*t;

        float3  pos = ro + t*rd;
        float2  env = terrainMap( pos.xz );
        float hei = env.x;

        // tree envelope
        float dis2 = pos.y - (hei+kMaxTreeHeight*1.1);
        if( dis2<th ) 
        {
            if( t2<0.0 )
            {
                t2 = ot + (th-odis2)*(t-ot)/(dis2-odis2); // linear interpolation for better accuracy
            }
        }
        odis2 = dis2;
        
        // terrain
        dis = pos.y - hei;
        if( dis<th ) break;
        
        ot = t;
        odis = dis;
        t += dis*0.8*(1.0-0.75*env.y); // slow down in step areas
        if( t>tmax ) break;
    }

    if( t>tmax ) t = -1.0;
    else t = ot + (th-odis)*(t-ot)/(dis-odis); // linear interpolation for better accuracy
    
    return float2(t,t2);
}

//------------------------------------------------------------------------------------------
// trees
//------------------------------------------------------------------------------------------

float treesMap( in float3 p, in float rt, out float oHei, out float oMat, out float oDis )
{
    oHei = 1.0;
    oDis = 0.0;
    oMat = 0.0;
        
    float base = terrainMap(p.xz).x; 
    
    float bb = fbm_4(p.xz*0.075);

    float d = 20.0;
    float2 n = floor( p.xz/2.0 );
    float2 f = frac( p.xz/2.0 );
    for( int j=0; j<=1; j++ )
    for( int i=0; i<=1; i++ )
    {
        float2  g = float2( float(i), float(j) ) - step(f,float2(0.5));
        float2  o = hash2( n + g );
        float2  v = hash2( n + g + float2(13.1,71.7) );
        float2  r = g - f + o;

        float height = kMaxTreeHeight * (0.4+0.8*v.x);
        float width = 0.5 + 0.2*v.x + 0.3*v.y;

        if( bb<0.0 ) width *= 0.5; else height *= 0.7;
        
        float3  q = float3(r.x,p.y-base-height*0.5,r.y);
        
        float k = sdEllipsoidY( q, float2(width,0.5*height) );

        if( k<d )
        { 
            d = k;
            oMat = 0.5*hash1(n+g+111.0);
            if( bb>0.0 ) oMat += 0.5;
            oHei = (p.y - base)/height;
            oHei *= 0.5 + 0.5*length(q) / width;
        }
    }

    // distort ellipsoids to make them look like trees (works only in the distance really)
    if( rt<1200.0 )
    {
        p.y -= 600.0;
        float s = fbm_4( p*3.0 );
        s = s*s;
        float att = 1.0-smoothstep(100.0,1200.0,rt);
        d += 4.0*s*att;
        oDis = s*att;
    }
    
    return d;
}

float treesShadow( in float3 ro, in float3 rd )
{
    float res = 1.0;
    float t = 0.02;
#ifdef LOWQUALITY
    for( int i=ZERO; i<64; i++ )
    {
        float kk1, kk2, kk3;
        float3 pos = ro + rd*t;
        float h = treesMap( pos, t, kk1, kk2, kk3 );
        res = min( res, 32.0*h/t );
        t += h;
        if( res<0.001 || t>50.0 || pos.y>kMaxHeight+kMaxTreeHeight ) break;
    }
#else
    for( int i=ZERO; i<150; i++ )
    {
        float kk1, kk2, kk3;
        float h = treesMap( ro + rd*t, t, kk1, kk2, kk3 );
        res = min( res, 32.0*h/t );
        t += h;
        if( res<0.001 || t>120.0 ) break;
    }
#endif
    return clamp( res, 0.0, 1.0 );
}

float3 treesNormal( in float3 pos, in float t )
{
    float kk1, kk2, kk3;
#if 0    
    const float eps = 0.005;
    float2 e = float2(1.0,-1.0)*0.5773*eps;
    return normalize( e.xyy*treesMap( pos + e.xyy, t, kk1, kk2, kk3 ) + 
                      e.yyx*treesMap( pos + e.yyx, t, kk1, kk2, kk3 ) + 
                      e.yxy*treesMap( pos + e.yxy, t, kk1, kk2, kk3 ) + 
                      e.xxx*treesMap( pos + e.xxx, t, kk1, kk2, kk3 ) );            
#else
    // inspired by tdhooper and klems - a way to prevent the compiler from inlining map() 4 times
    float3 n = float3(0.0);
    for( int i=ZERO; i<4; i++ )
    {
        float3 e = 0.5773*(2.0*float3((((i+3)>>1)&1),((i>>1)&1),(i&1))-1.0);
        n += e*treesMap(pos+0.005*e, t, kk1, kk2, kk3);
    }
    return normalize(n);
#endif    
}

//------------------------------------------------------------------------------------------
// sky
//------------------------------------------------------------------------------------------

float3 renderSky( in float3 ro, in float3 rd )
{
    // background sky     
    //float3 col = float3(0.45,0.6,0.85)/0.85 - rd.y*float3(0.4,0.36,0.4);
    //float3 col = float3(0.4,0.6,1.1) - rd.y*0.4;
    float3 col = float3(0.42,0.62,1.1) - rd.y*0.4;

    // clouds
    float t = (2500.0-ro.y)/rd.y;
    if( t>0.0 )
    {
        float2 uv = (ro+t*rd).xz;
        float cl = fbm_9( uv*0.00104 );
        float dl = smoothstep(-0.2,0.6,cl);
        col = lerp( col, float3(1.0), 0.12*dl );
    }
    
	// sun glare    
    float sun = clamp( dot(kSunDir,rd), 0.0, 1.0 );
    col += 0.2*float3(1.0,0.6,0.3)*pow( sun, 32.0 );
    
	return col;
}

//------------------------------------------------------------------------------------------
// main image making function
//------------------------------------------------------------------------------------------

void mainImage( out float4 fragColor, in float2 fragCoord )
{
    float2 o = hash2( float2(iFrame,1) ) - 0.5;
    
    float2 p = (2.0*(fragCoord+o)-iResolution.xy)/ iResolution.y;
    
    //----------------------------------
    // setup
    //----------------------------------

    // camera
    float time = iTime;
    float3 ro = float3(0.0, 401.5, 6.0);
    float3 ta = float3(0.0, 403.5, -90.0 + ro.z );
    
    //ro += float3(10.0*sin(0.02*time),0.0,-10.0*sin(0.2+0.031*time))
    
    ro.x -= 80.0*sin(0.01*time);
    ta.x -= 86.0*sin(0.01*time);

    // ray
    float3x3 ca = setCamera(ro, ta, 0.0);
    float3 rd = mul(normalize(float3(p, 1.5)), ca);

	float resT = 2000.0;

    //----------------------------------
    // sky
    //----------------------------------

    float3 col = renderSky( ro, rd );


    //----------------------------------
    // raycast terrain and tree envelope
    //----------------------------------
    {
    const float tmax = 2000.0;
    int   obj = 0;
    float2 t = raymarchTerrain( ro, rd, 15.0, tmax );
    if( t.x>0.0 )
    {
        resT = t.x;
        obj = 1;
    }

    //----------------------------------
    // raycast trees, if needed
    //----------------------------------
    float hei, mid, displa;
    
    if( t.y>0.0 )
    {
        float tf = t.y;
        float tfMax = (t.x>0.0)?t.x:tmax;
        for(int i=ZERO; i<64; i++) 
        { 
            float3  pos = ro + tf*rd; 
            float dis = treesMap( pos, tf, hei, mid, displa); 
            if( dis<(0.000125*tf) ) break;
            tf += dis;
            if( tf>tfMax ) break;
        }
        if( tf<tfMax )
        {
            resT = tf;
            obj = 2;
        }
    }

    //----------------------------------
    // shade
    //----------------------------------
    if( obj>0 )
    {
        float3 pos  = ro + resT*rd;
        float3 epos = pos + float3(0.0,4.8,0.0);

        float sha1  = terrainShadow( pos+float3(0,0.02,0), kSunDir, 0.02 );
        //sha1 *= smoothstep(-0.3,0.0,cloudsShadowFlat(epos, kSunDir));
        sha1 *= smoothstep(-0.325,-0.075,cloudsShadowFlat(epos, kSunDir));
        
        #ifndef LOWQUALITY
        float sha2  = treesShadow( pos+float3(0,0.02,0), kSunDir );
        #endif

        float3 tnor = terrainNormal( pos.xz );
        float3 nor;
        
        float3 speC = float3(1.0);
        //----------------------------------
        // terrain
        //----------------------------------
        if( obj==1 )
        {
            // bump map
            nor = normalize( tnor + 0.8*(1.0-abs(tnor.y))*0.8*fbmd_7( (pos-float3(0,600,0))*0.15*float3(1.0,0.2,1.0) ).yzw );

            col = float3(0.18,0.12,0.10)*.85;

            col = 1.0*lerp( col, float3(0.1,0.1,0.0)*0.2, smoothstep(0.7,0.9,nor.y) );      
            float dif = clamp( dot( nor, kSunDir), 0.0, 1.0 ); 
            dif *= sha1;
            #ifndef LOWQUALITY
            dif *= sha2;
            #endif

            float bac = clamp( dot(normalize(float3(-kSunDir.x,0.0,-kSunDir.z)),nor), 0.0, 1.0 );
            float foc = clamp( (pos.y/2.0-180.0)/130.0, 0.0,1.0);
            float dom = clamp( 0.5 + 0.5*nor.y, 0.0, 1.0 );
            float3  lin  = 1.0*0.2*lerp(0.1*float3(0.1,0.2,0.1),float3(0.7,0.9,1.5)*3.0,dom)*foc;
                  lin += 1.0*8.5*float3(1.0,0.9,0.8)*dif;        
                  lin += 1.0*0.27*float3(1.1,1.0,0.9)*bac*foc;
            speC = float3(4.0)*dif*smoothstep(20.0,0.0,abs(pos.y/2.0-310.0)-20.0);

            col *= lin;
        }
        //----------------------------------
        // trees
        //----------------------------------
        else //if( obj==2 )
        {
            float3 gnor = treesNormal( pos, resT );
            
            nor = normalize( gnor + 2.0*tnor );

            // --- lighting ---
            float3  ref = reflect(rd,nor);
            float occ = clamp(hei,0.0,1.0) * pow(1.0-2.0*displa,3.0);
            float dif = clamp( 0.1 + 0.9*dot( nor, kSunDir), 0.0, 1.0 ); 
            dif *= sha1;
            if( dif>0.0001 )
            {
                float a = clamp( 0.5+0.5*dot(tnor,kSunDir), 0.0, 1.0);
                a = a*a;
                a *= occ;
                a *= 0.6;
                a *= smoothstep(60.0,200.0,resT);
                // tree shadows with fake transmission
                #ifdef LOWQUALITY
                float sha2  = treesShadow( pos+kSunDir*0.1, kSunDir );
                #endif
                dif *= a+(1.0-a)*sha2;
            }
            float dom = clamp( 0.5 + 0.5*nor.y, 0.0, 1.0 );
            float bac = clamp( 0.5+0.5*dot(normalize(float3(-kSunDir.x,0.0,-kSunDir.z)),nor), 0.0, 1.0 );                 
            float fre = clamp(1.0+dot(nor,rd),0.0,1.0);
            //float spe = pow( clamp(dot(ref,kSunDir),0.0, 1.0), 9.0 )*dif*(0.2+0.8*pow(fre,5.0))*occ;

            // --- lights ---
            float3 lin  = 12.0*float3(1.2,1.0,0.7)*dif*occ*(2.5-1.5*smoothstep(0.0,120.0,resT));
                 lin += 0.55*lerp(0.1*float3(0.1,0.2,0.0),float3(0.6,1.0,1.0),dom*occ);
                 lin += 0.07*float3(1.0,1.0,0.9)*bac*occ;
                 lin += 1.10*float3(0.9,1.0,0.8)*pow(fre,5.0)*occ*(1.0-smoothstep(100.0,200.0,resT));
            speC = dif*float3(1.0,1.1,1.5)*1.2;

            // --- material ---
            float brownAreas = fbm_4( pos.zx*0.015 );
            col = float3(0.2,0.2,0.05);
            col = lerp( col, float3(0.32,0.2,0.05), smoothstep(0.2,0.9,frac(2.0*mid)) );
            col *= (mid<0.5)?0.65+0.35*smoothstep(300.0,600.0,resT)*smoothstep(700.0,500.0,pos.y):1.0;
            col = lerp( col, float3(0.25,0.16,0.01)*0.825, 0.7*smoothstep(0.1,0.3,brownAreas)*smoothstep(0.5,0.8,tnor.y) );
            col *= 1.0-0.5*smoothstep(400.0,700.0,pos.y);
            col *= lin;
        }

        // spec
        float3  ref = reflect(rd,nor);            
        float fre = clamp(1.0+dot(nor,rd),0.0,1.0);
        float spe = 3.0*pow( clamp(dot(ref,kSunDir),0.0, 1.0), 9.0 )*(0.05+0.95*pow(fre,5.0));
        col += spe*speC;

        col = fog(col,resT);
    }
    }

    float isCloud = 0.0;
    //----------------------------------
    // clouds
    //----------------------------------
    {
        float4 res = renderClouds( ro, rd, 0.0, resT, resT, fragCoord );
        col = col*(1.0-res.w) + res.xyz;
        isCloud = res.w;
    }

    //----------------------------------
    // final
    //----------------------------------
    
    // sun glare    
    float sun = clamp( dot(kSunDir,rd), 0.0, 1.0 );
    col += 0.25*float3(0.8,0.4,0.2)*pow( sun, 4.0 );
 

    // gamma
    //col = sqrt( clamp(col,0.0,1.0) );
    col = pow( clamp(col*1.1-0.02,0.0,1.0), float3(0.4545) );

    // contrast
    col = col*col*(3.0-2.0*col);            
    
    // color grade    
    col = pow( col, float3(1.0,0.92,1.0) );   // soft green
    col *= float3(1.02,0.99,0.9 );            // tint red
    col.z = col.z+0.1;                      // bias blue
    
    fragColor = float4(col, 1.0);
}
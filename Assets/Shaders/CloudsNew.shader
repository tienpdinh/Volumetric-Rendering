Shader "Unlit/CloudsNew"
{
    Properties
    {
        _MainTex("", 2D) = "white" {}
    }
    SubShader
    {
        Cull Off
        ZWrite Off
        ZTest Always

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            struct v2f
            {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 view : TEXCOORD1;
            };

            float _MinHeight;
            float _MaxHeight;
            float _FadeDistance;
            float _Scale;
            float _StepScale;
            float _Steps;
            float4 _SunDir;
            sampler2D _CameraDepthTexture;
            sampler2D _MainTex;
            sampler2D _ValueNoise;
            float4x4 _GlobalFrustumCorners;
            float4 _GlobalCameraPos;
            float4x4 _CamInvViewMatrix;

            #define MARCH(steps, noiseMap, camPos, viewDir, bgCol, sum, depth, t) { \
                for (int i = 0; i < steps; i++) \
                { \
                    if (t > depth) \
                        break; \
                    float3 pos = camPos + t * viewDir; \
                    if (pos.y < _MinHeight || pos.y > _MaxHeight || sum.a > 0.99) \
                    { \
                        t += max(0.1, 0.02*t); \
                        continue; \
                    } \
                    float density = noiseMap(pos); \
                    if (density > 0.01) \
                    { \
                        float diffuse = clamp((density - noiseMap(pos + 0.3 * _SunDir)) / 0.6, 0.0, 1.0); \
                        sum = integrate(sum, diffuse, density, bgCol, t); \
                    } \
                    t += max(0.1, 0.02 * t); \
                } \
            }

            fixed4 integrate(fixed4 sum, float diffuse, float density, fixed4 bgcol, float t)
            {
                fixed3 lighting = fixed3(0.65, 0.68, 0.7) * 1.3 + 0.5 * fixed3(0.7, 0.5, 0.3) * diffuse;
                fixed3 colrgb = lerp( fixed3(1.0, 0.95, 0.8), fixed3(0.65, 0.65, 0.65), density);
                fixed4 col = fixed4(colrgb.r, colrgb.g, colrgb.b, density);
                col.rgb *= lighting;
                col.rgb = lerp(col.rgb, bgcol, 1.0 - exp(-0.003*t*t));
                col.a *= 0.5;
                col.rgb *= col.a;
                return sum + col*(1.0 - sum.a);
            }

            #define NOISEPROC(N, P) 1.75 * N * saturate((_MaxHeight - P.y)/_FadeDistance)

            float noiseFromImage(float3 x)
            {
                x *= _Scale;
                float3 p = floor(x);
                float3 f = frac(x);
                // f = smoothstep(0,1,f);
                f = f * f * (3.0 - 2.0 * f);
                
                float2 uv = (p.xy + float2(37.0, -17.0) * p.z) + f.xy;
                float2 rg = tex2Dlod(_ValueNoise, float4((uv+0.5)/256, 0, 0)).rg;
                return -1.0 + 2.0 * lerp(rg.g, rg.r, f.z);
            }
            
            float map5(float3 q)
            {
                float3 p = q;
                float f;
                f = 0.5 * noiseFromImage(q); q = q * 2.02;
                f += 0.25 * noiseFromImage(q); q = q * 2.03;
                f += 0.125 * noiseFromImage(q); q = q * 2.01;
                f += 0.06250 * noiseFromImage(q); q = q * 2.02;
                f += 0.03125 * noiseFromImage(q);
                return NOISEPROC(f, p);
            } 
            
            float map4(float3 q)
            {
                float3 p = q;
                float f;
                f = 0.5 * noiseFromImage(q); q = q * 2.02;
                f += 0.25 * noiseFromImage(q); q = q * 2.03;
                f += 0.125 * noiseFromImage(q); q = q * 2.01;
                f += 0.06250 * noiseFromImage(q);
                return NOISEPROC(f, p);
            } 
            
            float map3(float3 q)
            {
                float3 p = q;
                float f;
                f = 0.5 * noiseFromImage(q); q = q * 2.02;
                f += 0.25 * noiseFromImage(q); q = q * 2.03;
                f += 0.125 * noiseFromImage(q);
                return NOISEPROC(f, p);
            } 
            
            float map2(float3 q)
            {
                float3 p = q;
                float f;
                f = 0.5 * noiseFromImage(q); q = q * 2.02;
                f += 0.25 * noiseFromImage(q);
                return NOISEPROC(f, p);
            } 
            
            float map1(float3 q)
            {
                float3 p = q;
                float f;
                f = 0.5 * noiseFromImage(q);
                return NOISEPROC(f, p);
            }

            fixed4 Raymarch(float3 camPos, float3 viewDir, fixed4 bgcol, float depth)
            {
                fixed4 col = fixed4(0,0,0,0);
                float ct = 0;
                
                MARCH(_Steps, map5, camPos, viewDir, bgcol, col, depth*5, ct);
                MARCH(_Steps, map4, camPos, viewDir, bgcol, col, depth*4, ct);
                MARCH(_Steps, map3, camPos, viewDir, bgcol, col, depth*3, ct);
                MARCH(_Steps, map2, camPos, viewDir, bgcol, col, depth*2, ct);
                MARCH(_Steps, map1, camPos, viewDir, bgcol, col, depth, ct);
                
                return clamp(col, 0.0, 1.0);
            }

            v2f vert (appdata_img v)
            {
                v2f o;
                half index = v.vertex.z;
                v.vertex.z = 0.1;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = v.texcoord.xy;
                #if UNITY_UV_START_AT_TOP
                    if (_MainTexSize.y < 0)
                        o.uv.y = 1 - o.uv.y;
                #endif
                o.view = _GlobalFrustumCorners[(int) index];
                o.view /= abs(o.view.z);
                o.view = mul(_CamInvViewMatrix, o.view);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                float3 start = _GlobalCameraPos;
                float2 uv = i.uv;
                #if UNITY_UV_START_AT_TOP
                    if (_MainTexSize.y < 0)
                        uv.y = 1 - uv.y;
                #endif
                float depth = LinearEyeDepth(tex2D(_CameraDepthTexture, uv).r);
                depth *= length(normalize(i.view));
                fixed4 col = tex2D(_MainTex, i.uv);
                fixed4 sum = Raymarch(start, normalize(i.view), col, depth);
                fixed3 color = col*(1.0-sum.a)+sum.rgb;
                color += 0.2*fixed3(1.0,0.4,0.2)*pow( _SunDir, 3.0 );
                return fixed4(color,1.0);
            }
            ENDCG
        }
    }
}

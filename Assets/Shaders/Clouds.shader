Shader "Unlit/Clouds"
{
    Properties
    {
        _Scale("Scale", Range(0.1,10.0)) = 2.0
        _StepScale("StepScale", Range(0.1,100.0)) = 1.0
        _Steps("Steps", Range(1.0,200.0)) = 50.0
        _MinHeight("MinHeight", Range(0.0,5.0)) = 0.0
        _MaxHeight("MaxHeight", Range(6.0,10.0)) = 10.0
        _FadeDistance("FaceDistance", Range(0.0,10.0)) = 0.5
        _SunDir("SunDirection", Vector) = (1,0,0,0)
    }
    SubShader
    {
        Tags { "Queue"="Transparent" }
        Blend SrcAlpha OneMinusSrcAlpha
        Cull Off
        Lighting Off
        ZWrite Off
        ZTest Always

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float4 pos : SV_POSITION;
                // float2 uv : TEXCOORD0;
                float3 view : TEXCOORD0;
                float4 projPos : TEXCOORD1;
                float3 wPos : TEXCOORD2;
            };

            float _MinHeight;
            float _MaxHeight;
            float _FadeDistance;
            float _Scale;
            float _StepScale;
            float _Steps;
            float4 _SunDir;
            sampler2D _CameraDepthTexture;

            float random(float3 val, float3 dotDir)
            {
                float3 smallV = sin(val);
                float random = dot(smallV, dotDir);
                random = frac(sin(random) * 18946.647);
                return random;
            }

            float3 random3d(float3 val)
            {
                return float3(random(val, float3(45.1246, 12.9812, 97.1502)),
                                random(val, float3(52.1246, 82.9812, 77.1502)),
                                random(val, float3(40.1246, 25.9812, 107.1502)));
            }

            float noise3d(float3 val)
            {
                val *= _Scale;
                // val.x *= _Time.x * 2;
                float3 interp = frac(val);
                interp = smoothstep(0.0, 1.0, interp);
                float3 zVal[2];
                for(int z = 0; z < 2; z++)
                {
                    float3 yVal[2];
                    for (int y = 0; y < 2; y++)
                    {
                        float3 xVal[2];
                        for (int x = 0; x < 2; x++)
                        {
                            float3 cell = floor(val) + float3(x,y,z);
                            xVal[x] = random3d(cell);
                        }
                        yVal[y] = lerp(xVal[0], xVal[1], interp.x);
                    }
                    zVal[z] = lerp(yVal[0], yVal[1], interp.y);
                }
                float noise = -1.0 + 2.0 * lerp(zVal[0], zVal[1], interp.z);
                return noise;
            }

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

            fixed4 integrate(fixed4 sum, float diffuse, float density, fixed4 bgCol, float t)
            {
                fixed3 lighting = fixed3(0.77, 0.74, 0.89) * 1.3 + 0.5 * fixed3(0.7, 0.5, 0.3) * diffuse;
                fixed3 colrgb = lerp(fixed3(1.0, 0.95, 0.8), fixed3(0.65, 0.65, 0.65), density);
                fixed4 col = fixed4(colrgb, density);
                col.rgb *= lighting;
                col.rgb = lerp(col.rgb, bgCol, 1.0 - exp(-0.003*t*t));
                col.a *= 0.5;
                col.rgb *= col.a;
                return sum + col*(1.0-sum.a);
            }

            #define NOISEPROC(N, P) 1.75 * N * saturate((_MaxHeight - P.y)/_FadeDistance)

            float map1(float3 q)
            {
                float3 p = q;
                float f;
                f = 0.5 * noise3d(q);
                q = q * 2;
                f += 0.25 * noise3d(q);
                q = q * 3;
                f += 0.1 * noise3d(q);
                return NOISEPROC(f, p);
            }

            float map2(float3 q)
            {
                float3 p = q;
                float f;
                f = 0.8 * noise3d(q);
                q = q * 1.3;
                f += 0.7 * noise3d(q);
                q = q * 3;
                f += 0.4 * noise3d(q);
                return NOISEPROC(f, p);
            }

            fixed4 Raymarch(float3 camPos, float3 viewDir, fixed4 bgCol, float depth)
            {
                fixed4 color = fixed4(0,0,0,0);
                float ct = 0;
                MARCH(_Steps, map1, camPos, viewDir, bgCol, color, depth, ct);
                MARCH(_Steps, map2, camPos, viewDir, bgCol, color, depth*2, ct);
                MARCH(_Steps, map2, camPos, viewDir, bgCol, color, depth*3, ct);
                return clamp(color, 0.0, 1.0);
            }

            v2f vert (appdata v)
            {
                v2f o;
                o.wPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.view = o.wPos - _WorldSpaceCameraPos;
                o.projPos = ComputeScreenPos(o.pos);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                float depth = 1;
                depth *= length(i.view);
                fixed4 col = fixed4(1,1,1,0);
                fixed4 clouds = Raymarch(_WorldSpaceCameraPos, normalize(i.view)*_StepScale, col, depth);
                fixed3 mixedCol = col * (1.0 - clouds.a) + clouds.rgb;
                return fixed4(mixedCol, clouds.a);
            }
            ENDCG
        }
    }
}

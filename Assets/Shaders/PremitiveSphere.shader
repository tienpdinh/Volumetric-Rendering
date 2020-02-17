Shader "Unlit/Sphere"
{
    SubShader
    {
        Tags { "Queue"="Transparent" }
        Blend SrcAlpha OneMinusSrcAlpha

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"
            #include "UnityLightingCommon.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                //float3 normal : NORMAL;
            };

            struct v2f
            {
                float3 wPos : TEXCOORD0;
                float4 pos : SV_POSITION;
                //fixed4 diff : COLOR0;
            };

            v2f vert (appdata v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.wPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                return o;
            }

            #define STEPS 128
            #define STEPS_SIZE 0.01

            bool SphereHit(float3 p, float3 c, float r)
            {
                return distance(p, c) <= r;
            }

            float3 RaymarchHit(float3 position, float3 direction)
            {
                for(int i = 0; i < STEPS; i++)
                {
                    if (SphereHit(position, float3(0,0,0), 0.5))
                    {
                        return position;
                    }
                    position += direction * STEPS_SIZE;
                }
                return float3(0,0,0);
            }

            fixed4 frag (v2f i) : SV_Target
            {
                float3 viewDir = normalize(i.wPos - _WorldSpaceCameraPos);
                float3 depth = RaymarchHit(i.wPos, viewDir);

                half3 worldNorm = depth - float3(0,0,0);
                half nl = max(0, dot(worldNorm, _WorldSpaceLightPos0.xyz));

                if (length(depth) != 0)
                {
                    depth *= nl * _LightColor0 * 3;
                    return fixed4(depth,1);
                    // return fixed4(0,1,1,1);
                }
                else
                {
                    return fixed4(0,0,0,0);
                }
            }
            ENDCG
        }
    }
}

using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[ExecuteInEditMode]
public class Clouds : MonoBehaviour
{
    public Shader CloudShader;
    public float minHeight = 0.0f;
    public float maxHeight = 5.0f;
    public float fadeDist = 2f;
    public float scale = 5f;
    public float steps = 50f;
    public Texture ValueNoiseTexture;
    public Transform sun;

    Camera _Cam;
    Material _Material;

    public Material Material
    {
        get
        {
            if (_Material == null && CloudShader != null)
            {
                _Material = new Material(CloudShader);
            }
            if (_Material != null && CloudShader == null)
            {
                DestroyImmediate(_Material);
            }
            if (_Material != null && CloudShader != null && CloudShader != _Material.shader)
            {
                DestroyImmediate(_Material);
                _Material = new Material(CloudShader);
            }
            return _Material;
        }
    }

    // Start is called before the first frame update
    void Start()
    {
        if (_Material)
            DestroyImmediate(_Material);
    }

    // use camera frustum
    Matrix4x4 getFrustumCorners()
    {
        Matrix4x4 corners = Matrix4x4.identity;
        Vector3[] c = new Vector3[4];
        _Cam.CalculateFrustumCorners(new Rect(0,0,1,1), _Cam.farClipPlane, Camera.MonoOrStereoscopicEye.Mono, c);
        corners.SetRow(0, Vector3.Scale(c[1], new Vector3(1,1,-1)));
        corners.SetRow(1, Vector3.Scale(c[2], new Vector3(1,1,-1)));
        corners.SetRow(2, Vector3.Scale(c[3], new Vector3(1,1,-1)));
        corners.SetRow(3, Vector3.Scale(c[0], new Vector3(1,1,-1)));
        return corners;
    }

    [ImageEffectOpaque]
    void OnRenderImage(RenderTexture src, RenderTexture des)
    {
        if (Material == null || ValueNoiseTexture == null)
        {
            // nothing is rendered
            Graphics.Blit(src, des);
            return;
        }

        if (_Cam == null)
            _Cam = GetComponent<Camera>();
        
        Material.SetTexture("_ValueNoise", ValueNoiseTexture);
        if(sun != null) Material.SetVector("_SunDir", -sun.forward);
        else Material.SetVector("_SunDir", Vector3.up);
        Material.SetFloat("_MinHeight", minHeight);
        Material.SetFloat("_MaxHeight", maxHeight);
        Material.SetFloat("_FadeDistance", fadeDist);
        Material.SetFloat("_Scale", scale);
        Material.SetFloat("_Steps", steps);

        Material.SetMatrix("_GlobalFrustumCorners", getFrustumCorners());
        Material.SetMatrix("_CamInvViewMatrix", _Cam.cameraToWorldMatrix);
        Material.SetVector("_GlobalCameraPos", _Cam.transform.position);

        CustomBlit(src, des, Material, 0);
    }

    static void CustomBlit(RenderTexture src, RenderTexture des, Material material, int pass)
    {
        RenderTexture.active = des;
        material.SetTexture("_MainTex", src);
        GL.PushMatrix();
        GL.LoadOrtho();
        material.SetPass(pass);
        GL.Begin(GL.QUADS);
        GL.MultiTexCoord2(0, 0.0f, 0.0f);
        GL.Vertex3(0.0f, 0.0f, 3.0f);
        GL.MultiTexCoord2(0, 1.0f, 0.0f);
        GL.Vertex3(1.0f, 0.0f, 2.0f);
        GL.MultiTexCoord2(0, 1.0f, 1.0f);
        GL.Vertex3(1.0f, 1.0f, 1.0f);
        GL.MultiTexCoord2(0, 0.0f, 1.0f);
        GL.Vertex3(0.0f, 1.0f, 0.0f);
        GL.End();
        GL.PopMatrix();
    }

    protected virtual void OnDisable()
    {
        if (_Material)
            DestroyImmediate(_Material);
    }

}

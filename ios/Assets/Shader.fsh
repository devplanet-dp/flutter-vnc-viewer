precision mediump float;
varying vec2 v_texcoord;
uniform sampler2D inputTexture;

void main()
{
    vec4 rgbaColor = texture2D(inputTexture,v_texcoord);
    rgbaColor.a = 1.0;
    gl_FragColor = rgbaColor;
//    gl_FragColor = vec4(0.41, 0.35, 0.80, 1.0);
    
}

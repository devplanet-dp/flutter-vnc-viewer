attribute vec4 position;
attribute vec2 texcoord;
varying lowp vec2 v_texcoord;

void main()
{
    gl_Position = position;
    v_texcoord = texcoord;
}

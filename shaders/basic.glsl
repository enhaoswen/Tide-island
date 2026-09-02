@vs rect_vs
in vec2 position;
in vec4 color;
out vec4 frag_color;
out vec2 Position;

layout(binding = 0) uniform project_uniform { 
    mat4 proj;
};

void main() {
    gl_Position = proj * vec4(position, 0.0, 1.0);
    frag_color = color;
    Position = position;
}
@end

@fs rect_fs
in vec4 frag_color;
in vec2 Position;
out vec4 out_color;

layout(binding = 0) uniform radius_uniform {
    vec2 center;
    vec2 half_size;
    float radius;
};

void main() {
    vec2 local_pos = Position - center;
    vec2 q = abs(local_pos) - half_size + radius;
    float dist = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
    float px = fwidth(dist) * 0.5;
    float alpha = 1.0 - smoothstep(-px, px, dist);
    out_color = vec4(frag_color.rgb, frag_color.a * alpha);
}
@end

@program rectangle rect_vs rect_fs

@vs img_vs
in vec2 position;
in vec2 coord;

out vec2 uv;

layout(binding = 0) uniform vs_params {
    mat4 proj;
};

void main() {
    uv = coord;
    gl_Position = proj * vec4(position,0.0,1.0);
}
@end

@fs img_fs
precision mediump float;

in vec2 uv;

layout(binding = 0) uniform texture2D tex;
layout(binding = 0) uniform sampler smp;

out vec4 frag_color;

void main() {
    frag_color = texture(sampler2D(tex,smp), uv);
}
@end

@program image img_vs img_fs
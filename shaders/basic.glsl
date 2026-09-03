@vs rect_vs
in vec2 position;
in vec4 color;
out vec4 frag_color;
out vec2 Position;

layout(binding = 0) uniform rect_proj_uniform { 
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

layout(binding = 1) uniform rect_radius_uniform {
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

out vec2 Position;
out vec2 uv;

layout(binding = 2) uniform img_proj {
    mat4 proj;
};

void main() {
    uv = coord;
    gl_Position = proj * vec4(position,0.0,1.0);
    Position = position;
}
@end

@fs img_fs
precision mediump float;

in vec2 Position;
in vec2 uv;

layout(binding = 0) uniform texture2D tex;
layout(binding = 0) uniform sampler smp;

layout(binding = 3) uniform img_radius_uniform {
    vec2 center;
    vec2 half_size;
    float radius;
};

out vec4 frag_color;

void main() {
    vec2 local_pos = Position - center;
    vec2 q = abs(local_pos) - half_size + radius;
    float dist = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
    float px = fwidth(dist) * 0.5;
    float alpha = 1.0 - smoothstep(-px, px, dist);
    vec4 color = texture(sampler2D(tex, smp), uv);
    frag_color = vec4(color.rgb, color.a * alpha);
}
@end

@program image img_vs img_fs
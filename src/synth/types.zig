pub const PitchTransition = union(enum) {
    immediate,
    glide_from: f32,
};

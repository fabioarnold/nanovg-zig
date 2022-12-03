const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const nanovg_mod = b.addModule("nanovg", .{
        .root_source_file = .{ .path = "src/nanovg.zig" },
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    nanovg_mod.addIncludePath(.{ .path = "src" });
    nanovg_mod.addIncludePath(.{ .path = "lib/gl2/include" });
    nanovg_mod.addCSourceFile(.{ .file = .{ .path = "src/fontstash.c" }, .flags = &.{ "-DFONS_NO_STDIO", "-fno-stack-protector" } });
    nanovg_mod.addCSourceFile(.{ .file = .{ .path = "src/stb_image.c" }, .flags = &.{ "-DSTBI_NO_STDIO", "-fno-stack-protector" } });

    if (target.result.isWasm()) {
        _ = installDemo(b, target, optimize, "demo", "examples/example_wasm.zig", nanovg_mod);
    } else {
        const demo_glfw = installDemo(b, target, optimize, "demo_glfw", "examples/example_glfw.zig", nanovg_mod);
        demo_glfw.addCSourceFile(.{ .file = .{ .path = "examples/stb_image_write.c" }, .flags = &.{ "-DSTBI_NO_STDIO", "-fno-stack-protector" } });

        _ = installDemo(b, target, optimize, "demo_fbo", "examples/example_fbo.zig", nanovg_mod);
        _ = installDemo(b, target, optimize, "demo_clip", "examples/example_clip.zig", nanovg_mod);

        const demo_rive = installDemo(b, target, optimize, "demo_rive", "examples/example_rive.zig", nanovg_mod);
        demo_rive.linkLibrary(makeRiveLib(b, target, optimize));
    }
}

fn installDemo(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode, name: []const u8, root_source_file: []const u8, nanovg_mod: *std.Build.Module) *std.Build.Step.Compile {
    const demo = b.addExecutable(.{
        .name = name,
        .root_source_file = .{ .path = root_source_file },
        .target = target,
        .optimize = optimize,
    });
    demo.root_module.addImport("nanovg", nanovg_mod);
    demo.addIncludePath(.{ .path = "examples" });

    if (target.result.isWasm()) {
        demo.rdynamic = true;
        demo.entry = .disabled;
    } else {
        demo.addIncludePath(.{ .path = "lib/gl2/include" });
        demo.addCSourceFile(.{ .file = .{ .path = "lib/gl2/src/glad.c" }, .flags = &.{} });
        switch (target.result.os.tag) {
            .windows => {
                b.installBinFile("glfw3.dll", "glfw3.dll");
                demo.linkSystemLibrary("glfw3dll");
                demo.linkSystemLibrary("opengl32");
            },
            .macos => {
                demo.addIncludePath(.{ .path = "/opt/homebrew/include" });
                demo.addLibraryPath(.{ .path = "/opt/homebrew/lib" });
                demo.linkSystemLibrary("glfw");
                demo.linkFramework("OpenGL");
            },
            .linux => {
                demo.linkSystemLibrary("glfw3");
                demo.linkSystemLibrary("GL");
                demo.linkSystemLibrary("X11");
            },
            else => {
                std.log.warn("Unsupported target: {}", .{target});
                demo.linkSystemLibrary("glfw3");
                demo.linkSystemLibrary("GL");
            },
        }
    }
    b.installArtifact(demo);
    return demo;
}

fn makeRiveLib(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) *std.Build.Step.Compile {
    const rive = b.addStaticLibrary(.{
        .name = "rive",
        .target = target,
        .optimize = optimize,
    });
    rive.linkLibCpp();
    rive.addIncludePath(.{ .path = "examples/rive-cpp/include" });
    rive.addCSourceFiles(.{ .files = &.{
        "examples/rive-cpp/src/animation/animation_state_instance.cpp",
        "examples/rive-cpp/src/animation/animation_state.cpp",
        "examples/rive-cpp/src/animation/blend_animation_1d.cpp",
        "examples/rive-cpp/src/animation/blend_animation_direct.cpp",
        "examples/rive-cpp/src/animation/blend_animation.cpp",
        "examples/rive-cpp/src/animation/blend_state_1d_instance.cpp",
        "examples/rive-cpp/src/animation/blend_state_1d.cpp",
        "examples/rive-cpp/src/animation/blend_state_direct_instance.cpp",
        "examples/rive-cpp/src/animation/blend_state_direct.cpp",
        "examples/rive-cpp/src/animation/blend_state_transition.cpp",
        "examples/rive-cpp/src/animation/blend_state.cpp",
        "examples/rive-cpp/src/animation/cubic_interpolator.cpp",
        "examples/rive-cpp/src/animation/keyed_object.cpp",
        "examples/rive-cpp/src/animation/keyed_property.cpp",
        "examples/rive-cpp/src/animation/keyframe_bool.cpp",
        "examples/rive-cpp/src/animation/keyframe_color.cpp",
        "examples/rive-cpp/src/animation/keyframe_double.cpp",
        "examples/rive-cpp/src/animation/keyframe_id.cpp",
        "examples/rive-cpp/src/animation/keyframe.cpp",
        "examples/rive-cpp/src/animation/layer_state.cpp",
        "examples/rive-cpp/src/animation/linear_animation_instance.cpp",
        "examples/rive-cpp/src/animation/linear_animation.cpp",
        "examples/rive-cpp/src/animation/listener_action.cpp",
        "examples/rive-cpp/src/animation/listener_align_target.cpp",
        "examples/rive-cpp/src/animation/listener_bool_change.cpp",
        "examples/rive-cpp/src/animation/listener_input_change.cpp",
        "examples/rive-cpp/src/animation/listener_number_change.cpp",
        "examples/rive-cpp/src/animation/listener_trigger_change.cpp",
        "examples/rive-cpp/src/animation/nested_animation.cpp",
        "examples/rive-cpp/src/animation/nested_linear_animation.cpp",
        "examples/rive-cpp/src/animation/nested_remap_animation.cpp",
        "examples/rive-cpp/src/animation/nested_simple_animation.cpp",
        "examples/rive-cpp/src/animation/nested_state_machine.cpp",
        "examples/rive-cpp/src/animation/state_instance.cpp",
        "examples/rive-cpp/src/animation/state_machine_input_instance.cpp",
        "examples/rive-cpp/src/animation/state_machine_input.cpp",
        "examples/rive-cpp/src/animation/state_machine_instance.cpp",
        "examples/rive-cpp/src/animation/state_machine_layer.cpp",
        "examples/rive-cpp/src/animation/state_machine_listener.cpp",
        "examples/rive-cpp/src/animation/state_machine.cpp",
        "examples/rive-cpp/src/animation/state_transition.cpp",
        "examples/rive-cpp/src/animation/system_state_instance.cpp",
        "examples/rive-cpp/src/animation/transition_bool_condition.cpp",
        "examples/rive-cpp/src/animation/transition_condition.cpp",
        "examples/rive-cpp/src/animation/transition_number_condition.cpp",
        "examples/rive-cpp/src/animation/transition_trigger_condition.cpp",
        "examples/rive-cpp/src/artboard.cpp",
        "examples/rive-cpp/src/assets/file_asset_contents.cpp",
        "examples/rive-cpp/src/assets/file_asset.cpp",
        "examples/rive-cpp/src/assets/image_asset.cpp",
        "examples/rive-cpp/src/bones/bone.cpp",
        "examples/rive-cpp/src/bones/root_bone.cpp",
        "examples/rive-cpp/src/bones/skin.cpp",
        "examples/rive-cpp/src/bones/skinnable.cpp",
        "examples/rive-cpp/src/bones/tendon.cpp",
        "examples/rive-cpp/src/bones/weight.cpp",
        "examples/rive-cpp/src/component.cpp",
        "examples/rive-cpp/src/constraints/constraint.cpp",
        "examples/rive-cpp/src/constraints/distance_constraint.cpp",
        "examples/rive-cpp/src/constraints/ik_constraint.cpp",
        "examples/rive-cpp/src/constraints/rotation_constraint.cpp",
        "examples/rive-cpp/src/constraints/scale_constraint.cpp",
        "examples/rive-cpp/src/constraints/targeted_constraint.cpp",
        "examples/rive-cpp/src/constraints/transform_constraint.cpp",
        "examples/rive-cpp/src/constraints/translation_constraint.cpp",
        "examples/rive-cpp/src/core/binary_reader.cpp",
        "examples/rive-cpp/src/core/field_types/core_bool_type.cpp",
        "examples/rive-cpp/src/core/field_types/core_bytes_type.cpp",
        "examples/rive-cpp/src/core/field_types/core_color_type.cpp",
        "examples/rive-cpp/src/core/field_types/core_double_type.cpp",
        "examples/rive-cpp/src/core/field_types/core_string_type.cpp",
        "examples/rive-cpp/src/core/field_types/core_uint_type.cpp",
        "examples/rive-cpp/src/dependency_sorter.cpp",
        "examples/rive-cpp/src/draw_rules.cpp",
        "examples/rive-cpp/src/draw_target.cpp",
        "examples/rive-cpp/src/drawable.cpp",
        "examples/rive-cpp/src/factory.cpp",
        "examples/rive-cpp/src/file.cpp",
        "examples/rive-cpp/src/generated/animation/animation_base.cpp",
        "examples/rive-cpp/src/generated/animation/animation_state_base.cpp",
        "examples/rive-cpp/src/generated/animation/any_state_base.cpp",
        "examples/rive-cpp/src/generated/animation/blend_animation_1d_base.cpp",
        "examples/rive-cpp/src/generated/animation/blend_animation_direct_base.cpp",
        "examples/rive-cpp/src/generated/animation/blend_state_1d_base.cpp",
        "examples/rive-cpp/src/generated/animation/blend_state_direct_base.cpp",
        "examples/rive-cpp/src/generated/animation/blend_state_transition_base.cpp",
        "examples/rive-cpp/src/generated/animation/cubic_interpolator_base.cpp",
        "examples/rive-cpp/src/generated/animation/entry_state_base.cpp",
        "examples/rive-cpp/src/generated/animation/exit_state_base.cpp",
        "examples/rive-cpp/src/generated/animation/keyed_object_base.cpp",
        "examples/rive-cpp/src/generated/animation/keyed_property_base.cpp",
        "examples/rive-cpp/src/generated/animation/keyframe_bool_base.cpp",
        "examples/rive-cpp/src/generated/animation/keyframe_color_base.cpp",
        "examples/rive-cpp/src/generated/animation/keyframe_double_base.cpp",
        "examples/rive-cpp/src/generated/animation/keyframe_id_base.cpp",
        "examples/rive-cpp/src/generated/animation/linear_animation_base.cpp",
        "examples/rive-cpp/src/generated/animation/listener_align_target_base.cpp",
        "examples/rive-cpp/src/generated/animation/listener_bool_change_base.cpp",
        "examples/rive-cpp/src/generated/animation/listener_number_change_base.cpp",
        "examples/rive-cpp/src/generated/animation/listener_trigger_change_base.cpp",
        "examples/rive-cpp/src/generated/animation/nested_bool_base.cpp",
        "examples/rive-cpp/src/generated/animation/nested_number_base.cpp",
        "examples/rive-cpp/src/generated/animation/nested_remap_animation_base.cpp",
        "examples/rive-cpp/src/generated/animation/nested_simple_animation_base.cpp",
        "examples/rive-cpp/src/generated/animation/nested_state_machine_base.cpp",
        "examples/rive-cpp/src/generated/animation/nested_trigger_base.cpp",
        "examples/rive-cpp/src/generated/animation/state_machine_base.cpp",
        "examples/rive-cpp/src/generated/animation/state_machine_bool_base.cpp",
        "examples/rive-cpp/src/generated/animation/state_machine_layer_base.cpp",
        "examples/rive-cpp/src/generated/animation/state_machine_listener_base.cpp",
        "examples/rive-cpp/src/generated/animation/state_machine_number_base.cpp",
        "examples/rive-cpp/src/generated/animation/state_machine_trigger_base.cpp",
        "examples/rive-cpp/src/generated/animation/state_transition_base.cpp",
        "examples/rive-cpp/src/generated/animation/transition_bool_condition_base.cpp",
        "examples/rive-cpp/src/generated/animation/transition_number_condition_base.cpp",
        "examples/rive-cpp/src/generated/animation/transition_trigger_condition_base.cpp",
        "examples/rive-cpp/src/generated/artboard_base.cpp",
        "examples/rive-cpp/src/generated/assets/file_asset_contents_base.cpp",
        "examples/rive-cpp/src/generated/assets/folder_base.cpp",
        "examples/rive-cpp/src/generated/assets/image_asset_base.cpp",
        "examples/rive-cpp/src/generated/backboard_base.cpp",
        "examples/rive-cpp/src/generated/bones/bone_base.cpp",
        "examples/rive-cpp/src/generated/bones/cubic_weight_base.cpp",
        "examples/rive-cpp/src/generated/bones/root_bone_base.cpp",
        "examples/rive-cpp/src/generated/bones/skin_base.cpp",
        "examples/rive-cpp/src/generated/bones/tendon_base.cpp",
        "examples/rive-cpp/src/generated/bones/weight_base.cpp",
        "examples/rive-cpp/src/generated/constraints/distance_constraint_base.cpp",
        "examples/rive-cpp/src/generated/constraints/ik_constraint_base.cpp",
        "examples/rive-cpp/src/generated/constraints/rotation_constraint_base.cpp",
        "examples/rive-cpp/src/generated/constraints/scale_constraint_base.cpp",
        "examples/rive-cpp/src/generated/constraints/transform_constraint_base.cpp",
        "examples/rive-cpp/src/generated/constraints/translation_constraint_base.cpp",
        "examples/rive-cpp/src/generated/draw_rules_base.cpp",
        "examples/rive-cpp/src/generated/draw_target_base.cpp",
        "examples/rive-cpp/src/generated/nested_artboard_base.cpp",
        "examples/rive-cpp/src/generated/node_base.cpp",
        "examples/rive-cpp/src/generated/shapes/clipping_shape_base.cpp",
        "examples/rive-cpp/src/generated/shapes/contour_mesh_vertex_base.cpp",
        "examples/rive-cpp/src/generated/shapes/cubic_asymmetric_vertex_base.cpp",
        "examples/rive-cpp/src/generated/shapes/cubic_detached_vertex_base.cpp",
        "examples/rive-cpp/src/generated/shapes/cubic_mirrored_vertex_base.cpp",
        "examples/rive-cpp/src/generated/shapes/ellipse_base.cpp",
        "examples/rive-cpp/src/generated/shapes/image_base.cpp",
        "examples/rive-cpp/src/generated/shapes/mesh_base.cpp",
        "examples/rive-cpp/src/generated/shapes/mesh_vertex_base.cpp",
        "examples/rive-cpp/src/generated/shapes/paint/fill_base.cpp",
        "examples/rive-cpp/src/generated/shapes/paint/gradient_stop_base.cpp",
        "examples/rive-cpp/src/generated/shapes/paint/linear_gradient_base.cpp",
        "examples/rive-cpp/src/generated/shapes/paint/radial_gradient_base.cpp",
        "examples/rive-cpp/src/generated/shapes/paint/solid_color_base.cpp",
        "examples/rive-cpp/src/generated/shapes/paint/stroke_base.cpp",
        "examples/rive-cpp/src/generated/shapes/paint/trim_path_base.cpp",
        "examples/rive-cpp/src/generated/shapes/points_path_base.cpp",
        "examples/rive-cpp/src/generated/shapes/polygon_base.cpp",
        "examples/rive-cpp/src/generated/shapes/rectangle_base.cpp",
        "examples/rive-cpp/src/generated/shapes/shape_base.cpp",
        "examples/rive-cpp/src/generated/shapes/star_base.cpp",
        "examples/rive-cpp/src/generated/shapes/straight_vertex_base.cpp",
        "examples/rive-cpp/src/generated/shapes/triangle_base.cpp",
        "examples/rive-cpp/src/hittest_command_path.cpp",
        "examples/rive-cpp/src/importers/artboard_importer.cpp",
        "examples/rive-cpp/src/importers/backboard_importer.cpp",
        "examples/rive-cpp/src/importers/file_asset_importer.cpp",
        "examples/rive-cpp/src/importers/keyed_object_importer.cpp",
        "examples/rive-cpp/src/importers/keyed_property_importer.cpp",
        "examples/rive-cpp/src/importers/layer_state_importer.cpp",
        "examples/rive-cpp/src/importers/linear_animation_importer.cpp",
        "examples/rive-cpp/src/importers/state_machine_importer.cpp",
        "examples/rive-cpp/src/importers/state_machine_layer_importer.cpp",
        "examples/rive-cpp/src/importers/state_machine_listener_importer.cpp",
        "examples/rive-cpp/src/importers/state_transition_importer.cpp",
        "examples/rive-cpp/src/layout.cpp",
        "examples/rive-cpp/src/math/aabb.cpp",
        "examples/rive-cpp/src/math/contour_measure.cpp",
        "examples/rive-cpp/src/math/hit_test.cpp",
        "examples/rive-cpp/src/math/mat2d_find_max_scale.cpp",
        "examples/rive-cpp/src/math/mat2d.cpp",
        "examples/rive-cpp/src/math/raw_path_utils.cpp",
        "examples/rive-cpp/src/math/raw_path.cpp",
        "examples/rive-cpp/src/math/vec2d.cpp",
        "examples/rive-cpp/src/nested_artboard.cpp",
        "examples/rive-cpp/src/node.cpp",
        "examples/rive-cpp/src/renderer.cpp",
        "examples/rive-cpp/src/rive_counter.cpp",
        "examples/rive-cpp/src/scene.cpp",
        "examples/rive-cpp/src/shapes/clipping_shape.cpp",
        "examples/rive-cpp/src/shapes/cubic_asymmetric_vertex.cpp",
        "examples/rive-cpp/src/shapes/cubic_detached_vertex.cpp",
        "examples/rive-cpp/src/shapes/cubic_mirrored_vertex.cpp",
        "examples/rive-cpp/src/shapes/cubic_vertex.cpp",
        "examples/rive-cpp/src/shapes/ellipse.cpp",
        "examples/rive-cpp/src/shapes/image.cpp",
        "examples/rive-cpp/src/shapes/mesh_vertex.cpp",
        "examples/rive-cpp/src/shapes/mesh.cpp",
        "examples/rive-cpp/src/shapes/metrics_path.cpp",
        "examples/rive-cpp/src/shapes/paint/color.cpp",
        "examples/rive-cpp/src/shapes/paint/fill.cpp",
        "examples/rive-cpp/src/shapes/paint/gradient_stop.cpp",
        "examples/rive-cpp/src/shapes/paint/linear_gradient.cpp",
        "examples/rive-cpp/src/shapes/paint/radial_gradient.cpp",
        "examples/rive-cpp/src/shapes/paint/shape_paint_mutator.cpp",
        "examples/rive-cpp/src/shapes/paint/shape_paint.cpp",
        "examples/rive-cpp/src/shapes/paint/solid_color.cpp",
        "examples/rive-cpp/src/shapes/paint/stroke.cpp",
        "examples/rive-cpp/src/shapes/paint/trim_path.cpp",
        "examples/rive-cpp/src/shapes/parametric_path.cpp",
        "examples/rive-cpp/src/shapes/path_composer.cpp",
        "examples/rive-cpp/src/shapes/path_vertex.cpp",
        "examples/rive-cpp/src/shapes/path.cpp",
        "examples/rive-cpp/src/shapes/points_path.cpp",
        "examples/rive-cpp/src/shapes/polygon.cpp",
        "examples/rive-cpp/src/shapes/rectangle.cpp",
        "examples/rive-cpp/src/shapes/shape_paint_container.cpp",
        "examples/rive-cpp/src/shapes/shape.cpp",
        "examples/rive-cpp/src/shapes/star.cpp",
        "examples/rive-cpp/src/shapes/straight_vertex.cpp",
        "examples/rive-cpp/src/shapes/triangle.cpp",
        "examples/rive-cpp/src/shapes/vertex.cpp",
        "examples/rive-cpp/src/simple_array.cpp",
        "examples/rive-cpp/src/text/font_hb.cpp",
        "examples/rive-cpp/src/text/line_breaker.cpp",
        "examples/rive-cpp/src/transform_component.cpp",
        "examples/rive-cpp/src/world_transform_component.cpp",

        "examples/rive-cpp/utils/no_op_factory.cpp",

        "examples/rive_capi_impl.cpp",
    }, .flags = &.{
        "-std=c++17",
        "-Wall",
        "-fno-exceptions",
        "-fno-rtti",
    } });
    return rive;
}

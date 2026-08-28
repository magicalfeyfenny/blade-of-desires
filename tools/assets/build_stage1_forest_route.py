#!/usr/bin/env python3
"""Build the editable and runtime geometry for Stage 1's Lost Forest route."""

from __future__ import annotations

import math
import struct
from dataclasses import dataclass
from pathlib import Path

import bpy


WHITE_VERTEX_COLOUR = 0xFFFFFFFF
FLOOR_UV = (0.01, 0.01, 0.49, 0.49)
PATH_UV = (0.51, 0.01, 0.99, 0.49)
BARK_UV = (0.01, 0.51, 0.49, 0.99)
FOLIAGE_UV = (0.51, 0.51, 0.99, 0.99)


@dataclass(frozen=True)
class RenderVertex:
    """Store one expanded position, tint, and atlas coordinate."""

    position: tuple[float, float, float]
    colour: int
    uv: tuple[float, float]


class RouteMesh:
    """Accumulate expanded triangles shared by Blender, OBJ, and VBUFF exports."""

    def __init__(self) -> None:
        """Start an empty deterministic triangle list."""
        self.vertices: list[RenderVertex] = []

    def add_triangle(
        self,
        positions: tuple[
            tuple[float, float, float],
            tuple[float, float, float],
            tuple[float, float, float],
        ],
        uvs: tuple[
            tuple[float, float], tuple[float, float], tuple[float, float]
        ],
    ) -> None:
        """Append one triangle with its visible face toward the -Z-up exterior."""
        for index in (0, 2, 1):
            position = positions[index]
            uv = uvs[index]
            self.vertices.append(RenderVertex(position, WHITE_VERTEX_COLOUR, uv))

    def add_quad(
        self,
        corners: tuple[
            tuple[float, float, float],
            tuple[float, float, float],
            tuple[float, float, float],
            tuple[float, float, float],
        ],
        uv_rect: tuple[float, float, float, float],
    ) -> None:
        """Append a two-triangle quad mapped across one atlas quadrant."""
        u1, v1, u2, v2 = uv_rect
        quad_uvs = ((u1, v2), (u2, v2), (u2, v1), (u1, v1))
        self.add_triangle(
            (corners[0], corners[1], corners[2]),
            (quad_uvs[0], quad_uvs[1], quad_uvs[2]),
        )
        self.add_triangle(
            (corners[0], corners[2], corners[3]),
            (quad_uvs[0], quad_uvs[2], quad_uvs[3]),
        )


def route_center(y_position: float) -> float:
    """Return the gentle authored bend at one forward route coordinate."""
    return math.sin(y_position / 31.0) * 1.5 + math.sin(y_position / 13.0) * 0.4


def add_ground(mesh: RouteMesh) -> None:
    """Build moss banks and a distinct worn path for the full Stage 1 approach."""
    segment_length = 10.0
    y_start = -30.0
    y_end = 260.0
    path_half_width = 3.2
    forest_half_width = 21.0
    y_position = y_start
    while y_position < y_end:
        next_y = min(y_end, y_position + segment_length)
        center = route_center(y_position)
        next_center = route_center(next_y)
        mesh.add_quad(
            (
                (-forest_half_width, y_position, 0.0),
                (center - path_half_width, y_position, 0.0),
                (next_center - path_half_width, next_y, 0.0),
                (-forest_half_width, next_y, 0.0),
            ),
            FLOOR_UV,
        )
        mesh.add_quad(
            (
                (center - path_half_width, y_position, -0.03),
                (center + path_half_width, y_position, -0.03),
                (next_center + path_half_width, next_y, -0.03),
                (next_center - path_half_width, next_y, -0.03),
            ),
            PATH_UV,
        )
        mesh.add_quad(
            (
                (center + path_half_width, y_position, 0.0),
                (forest_half_width, y_position, 0.0),
                (forest_half_width, next_y, 0.0),
                (next_center + path_half_width, next_y, 0.0),
            ),
            FLOOR_UV,
        )
        y_position = next_y


def add_trunk(
    mesh: RouteMesh,
    x_position: float,
    y_position: float,
    radius: float,
    height: float,
    sides: int = 7,
) -> None:
    """Build one low-poly trunk that rises along the project's negative-Z up axis."""
    for side in range(sides):
        first_angle = math.tau * side / sides
        second_angle = math.tau * (side + 1) / sides
        first_x = x_position + math.cos(first_angle) * radius
        first_y = y_position + math.sin(first_angle) * radius
        second_x = x_position + math.cos(second_angle) * radius
        second_y = y_position + math.sin(second_angle) * radius
        mesh.add_quad(
            (
                (first_x, first_y, 0.0),
                (second_x, second_y, 0.0),
                (second_x, second_y, -height),
                (first_x, first_y, -height),
            ),
            BARK_UV,
        )


def add_canopy(
    mesh: RouteMesh,
    center: tuple[float, float, float],
    horizontal_radius: float,
    vertical_radius: float,
) -> None:
    """Build one faceted foliage crown around an authored trunk top."""
    x_position, y_position, z_position = center
    top = (x_position, y_position, z_position - vertical_radius)
    bottom = (x_position, y_position, z_position + vertical_radius)
    ring = (
        (x_position + horizontal_radius, y_position, z_position),
        (x_position, y_position + horizontal_radius, z_position),
        (x_position - horizontal_radius, y_position, z_position),
        (x_position, y_position - horizontal_radius, z_position),
    )
    u1, v1, u2, v2 = FOLIAGE_UV
    apex_uv = ((u1 + u2) * 0.5, v1)
    bottom_uv = ((u1 + u2) * 0.5, v2)
    ring_uv = ((u2, (v1 + v2) * 0.5), (u1, (v1 + v2) * 0.5))
    for index in range(4):
        next_index = (index + 1) % 4
        mesh.add_triangle(
            (top, ring[index], ring[next_index]),
            (apex_uv, ring_uv[0], ring_uv[1]),
        )
        mesh.add_triangle(
            (bottom, ring[next_index], ring[index]),
            (bottom_uv, ring_uv[1], ring_uv[0]),
        )


def add_forest(mesh: RouteMesh) -> None:
    """Place deterministic tree walls while preserving a readable route corridor."""
    for route_index, y_position in enumerate(range(-12, 239, 9)):
        center = route_center(float(y_position))
        for side in (-1, 1):
            distance = 7.0 + (route_index * 3 + (1 if side > 0 else 0)) % 5
            x_position = center + side * distance
            y_offset = 1.4 if (route_index + side) % 2 == 0 else -1.1
            radius = 0.72 + ((route_index + (2 if side > 0 else 0)) % 4) * 0.11
            height = 11.0 + ((route_index * 5 + side) % 6)
            add_trunk(mesh, x_position, y_position + y_offset, radius, height)
            add_canopy(
                mesh,
                (x_position, y_position + y_offset, -height),
                3.2 + (route_index % 3) * 0.45,
                3.5 + ((route_index + 1) % 3) * 0.4,
            )


def add_world_tree(mesh: RouteMesh) -> None:
    """Model the distant World Tree landmark used by Issue 14's handoff boundary."""
    y_position = 248.0
    center = route_center(y_position)
    add_trunk(mesh, center, y_position, 5.8, 34.0, sides=12)
    for x_offset, y_offset, z_offset, radius in (
        (0.0, 0.0, -34.0, 10.0),
        (-7.0, 1.5, -31.0, 7.0),
        (7.0, 1.0, -32.0, 7.5),
        (0.0, 6.0, -39.0, 8.0),
    ):
        add_canopy(
            mesh,
            (center + x_offset, y_position + y_offset, z_offset),
            radius,
            radius * 0.72,
        )


def build_route_mesh() -> RouteMesh:
    """Create the complete deterministic Stage 1 scenery triangle list."""
    mesh = RouteMesh()
    add_ground(mesh)
    add_forest(mesh)
    add_world_tree(mesh)
    return mesh


def write_obj(mesh: RouteMesh, obj_path: Path, mtl_path: Path) -> None:
    """Write a readable interchange export matching the runtime triangle order."""
    obj_lines = [
        "# Blade of Desires Stage 1 Lost Forest route",
        f"mtllib {mtl_path.name}",
        "o LostForestRoute",
    ]
    for vertex in mesh.vertices:
        x_position, y_position, z_position = vertex.position
        obj_lines.append(f"v {x_position:.6f} {y_position:.6f} {z_position:.6f}")
    for vertex in mesh.vertices:
        u_position, v_position = vertex.uv
        obj_lines.append(f"vt {u_position:.6f} {1.0 - v_position:.6f}")
    obj_lines.append("usemtl LostForestMaterials")
    for vertex_index in range(0, len(mesh.vertices), 3):
        first = vertex_index + 1
        obj_lines.append(
            f"f {first}/{first} {first + 1}/{first + 1} {first + 2}/{first + 2}"
        )
    obj_path.write_text("\n".join(obj_lines) + "\n", encoding="utf-8")
    mtl_path.write_text(
        "\n".join(
            (
                "# Blade of Desires Stage 1 Lost Forest material",
                "newmtl LostForestMaterials",
                "Ka 0.100000 0.100000 0.100000",
                "Kd 1.000000 1.000000 1.000000",
                "Ks 0.000000 0.000000 0.000000",
                "d 1.000000",
                "illum 1",
                "map_Kd ../../../runtime/textures/stage1/lost_forest_materials.png",
            )
        )
        + "\n",
        encoding="utf-8",
    )


def write_vbuff(mesh: RouteMesh, path: Path) -> None:
    """Write GameMaker's 24-byte position, colour, and texture vertex layout."""
    with path.open("wb") as output:
        for vertex in mesh.vertices:
            output.write(
                struct.pack(
                    "<fffIff",
                    *vertex.position,
                    vertex.colour,
                    *vertex.uv,
                )
            )


def write_blend(mesh: RouteMesh, path: Path, texture_path: Path) -> None:
    """Create a self-contained editable Blender scene with explicit -Z world-up metadata."""
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)

    positions = [vertex.position for vertex in mesh.vertices]
    faces = [
        (index, index + 1, index + 2)
        for index in range(0, len(mesh.vertices), 3)
    ]
    blender_mesh = bpy.data.meshes.new("LostForestRouteMesh")
    blender_mesh.from_pydata(positions, [], faces)
    blender_mesh.update()
    uv_layer = blender_mesh.uv_layers.new(name="LostForestAtlasUV")
    for loop in blender_mesh.loops:
        source_u, source_v = mesh.vertices[loop.vertex_index].uv
        uv_layer.data[loop.index].uv = (source_u, 1.0 - source_v)

    material = bpy.data.materials.new("LostForestMaterials")
    material.use_nodes = True
    nodes = material.node_tree.nodes
    image_node = nodes.new("ShaderNodeTexImage")
    image = bpy.data.images.load(str(texture_path))
    image.pack()
    image_node.image = image
    image_node.interpolation = "Linear"
    shader = nodes.get("Principled BSDF")
    material.node_tree.links.new(image_node.outputs["Color"], shader.inputs["Base Color"])
    shader.inputs["Roughness"].default_value = 0.9
    blender_mesh.materials.append(material)

    route_object = bpy.data.objects.new("LostForestRoute", blender_mesh)
    bpy.context.collection.objects.link(route_object)
    route_object["blade_world_up"] = "-Z"
    route_object["blade_gameplay_isolation"] = "presentation_only"

    scene = bpy.context.scene
    scene["blade_world_up"] = "-Z"
    scene["blade_route_start_y"] = -30.0
    scene["blade_world_tree_handoff_y"] = 248.0
    scene["blade_gameplay_plane"] = "270x360 centered in 640x360"
    bpy.context.view_layer.objects.active = route_object
    route_object.select_set(True)
    # This governed exporter keeps one editable Blend source, not Blender backups.
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=str(path), compress=True)


def main() -> None:
    """Build every governed source and runtime model artifact from one mesh authority."""
    repository = Path(__file__).resolve().parents[2]
    source_directory = repository / "assets/source/models/stage1"
    runtime_directory = repository / "assets/runtime/models/stage1"
    texture_path = repository / "assets/runtime/textures/stage1/lost_forest_materials.png"
    source_directory.mkdir(parents=True, exist_ok=True)
    runtime_directory.mkdir(parents=True, exist_ok=True)
    if not texture_path.exists():
        raise FileNotFoundError(f"Missing governed forest texture: {texture_path}")

    mesh = build_route_mesh()
    if not mesh.vertices or len(mesh.vertices) % 3 != 0:
        raise RuntimeError("Lost Forest mesh must contain complete triangles")
    obj_path = source_directory / "lost_forest_route.obj"
    mtl_path = source_directory / "lost_forest_route.mtl"
    write_obj(mesh, obj_path, mtl_path)
    write_vbuff(mesh, runtime_directory / "lost_forest_route.vbuff")
    write_blend(
        mesh,
        source_directory / "lost_forest_route.blend",
        texture_path,
    )
    print(
        f"Built Lost Forest route: {len(mesh.vertices)} vertices, "
        f"{len(mesh.vertices) // 3} triangles"
    )


if __name__ == "__main__":
    main()

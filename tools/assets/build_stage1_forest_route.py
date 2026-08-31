#!/usr/bin/env python3
"""Build editable and runtime geometry for Stage 1's modular Lost Forest."""

from __future__ import annotations

import math
import struct
from dataclasses import dataclass
from pathlib import Path

import bpy


Vec2 = tuple[float, float]
Vec3 = tuple[float, float, float]
WHITE_VERTEX_COLOUR = 0xFFFFFFFF
VBUFF_VERTEX_SIZE = 36
FLOOR_UV = (0.01, 0.01, 0.49, 0.49)
PATH_UV = (0.51, 0.01, 0.99, 0.49)
BARK_UV = (0.01, 0.51, 0.49, 0.99)
FOLIAGE_UV = (0.51, 0.51, 0.99, 0.99)
SKY_UV = (0.01, 0.01, 0.99, 0.99)
WORLD_UP = (0.0, 0.0, -1.0)
BILLBOARD_FACING = (0.0, 0.0, 1.0)
TERRAIN_Y_START = -30.0
TERRAIN_Y_END = 260.0
TERRAIN_SEGMENT_LENGTH = 2.5
TERRAIN_PATH_HALF_WIDTH = 3.2
TERRAIN_FOREST_HALF_WIDTH = 23.0
TERRAIN_BANK_STRIPS = 6
TERRAIN_PATH_STRIPS = 4


def add(left: Vec3, right: Vec3) -> Vec3:
    """Add two small geometry vectors."""
    return tuple(left[index] + right[index] for index in range(3))


def subtract(left: Vec3, right: Vec3) -> Vec3:
    """Subtract two small geometry vectors."""
    return tuple(left[index] - right[index] for index in range(3))


def multiply(vector: Vec3, scalar: float) -> Vec3:
    """Scale one small geometry vector."""
    return tuple(component * scalar for component in vector)


def dot(left: Vec3, right: Vec3) -> float:
    """Return the dot product used by winding checks."""
    return sum(left[index] * right[index] for index in range(3))


def cross(left: Vec3, right: Vec3) -> Vec3:
    """Return the right-handed cross product used by exported faces."""
    return (
        left[1] * right[2] - left[2] * right[1],
        left[2] * right[0] - left[0] * right[2],
        left[0] * right[1] - left[1] * right[0],
    )


def length(vector: Vec3) -> float:
    """Return one geometry vector's length."""
    return math.sqrt(dot(vector, vector))


def normalize(vector: Vec3) -> Vec3:
    """Normalize a non-zero geometry vector or fail at the authoring boundary."""
    magnitude = length(vector)
    if magnitude <= 1.0e-8:
        raise ValueError("Cannot normalize a zero-length geometry vector")
    return multiply(vector, 1.0 / magnitude)


def average(points: tuple[Vec3, ...]) -> Vec3:
    """Return the center of a small fixed group of points."""
    return tuple(sum(point[index] for point in points) / len(points) for index in range(3))


def game_maker_colour(red: int, green: int, blue: int, alpha: int = 255) -> int:
    """Pack RGBA bytes in the order GameMaker stores vertex colours."""
    return alpha << 24 | blue << 16 | green << 8 | red


def colour_components(colour: int) -> tuple[float, float, float, float]:
    """Convert a packed GameMaker colour for Blender's editable colour layer."""
    return (
        (colour & 0xFF) / 255.0,
        ((colour >> 8) & 0xFF) / 255.0,
        ((colour >> 16) & 0xFF) / 255.0,
        ((colour >> 24) & 0xFF) / 255.0,
    )


@dataclass(frozen=True)
class RenderVertex:
    """Store one expanded position, normal, tint, and atlas coordinate."""

    position: Vec3
    normal: Vec3
    colour: int
    uv: Vec2


class ModelMesh:
    """Accumulate expanded triangles shared by Blender, OBJ, and VBUFF exports."""

    def __init__(self) -> None:
        """Start an empty deterministic triangle list."""
        self.vertices: list[RenderVertex] = []

    def add_triangle(
        self,
        positions: tuple[Vec3, Vec3, Vec3],
        uvs: tuple[Vec2, Vec2, Vec2],
        facing: Vec3,
        colours: tuple[int, int, int] = (
            WHITE_VERTEX_COLOUR,
            WHITE_VERTEX_COLOUR,
            WHITE_VERTEX_COLOUR,
        ),
    ) -> None:
        """Append one triangle wound toward an explicit visible direction."""
        indices = [0, 1, 2]
        face = cross(
            subtract(positions[1], positions[0]),
            subtract(positions[2], positions[0]),
        )
        if dot(face, facing) < 0.0:
            indices[1], indices[2] = indices[2], indices[1]
        ordered_positions = tuple(positions[index] for index in indices)
        normal = normalize(
            cross(
                subtract(ordered_positions[1], ordered_positions[0]),
                subtract(ordered_positions[2], ordered_positions[0]),
            )
        )
        if dot(normal, facing) <= 1.0e-6:
            raise ValueError("Triangle cannot be wound toward its requested face")
        for index in indices:
            self.vertices.append(
                RenderVertex(positions[index], normal, colours[index], uvs[index])
            )

    def add_quad(
        self,
        corners: tuple[Vec3, Vec3, Vec3, Vec3],
        uv_rect: tuple[float, float, float, float],
        facing: Vec3,
        colours: tuple[int, int, int, int] = (
            WHITE_VERTEX_COLOUR,
            WHITE_VERTEX_COLOUR,
            WHITE_VERTEX_COLOUR,
            WHITE_VERTEX_COLOUR,
        ),
        flip_diagonal: bool = False,
    ) -> None:
        """Append a two-triangle quad mapped across one material region."""
        u1, v1, u2, v2 = uv_rect
        quad_uvs = ((u1, v2), (u2, v2), (u2, v1), (u1, v1))
        if flip_diagonal:
            self.add_triangle(
                (corners[0], corners[1], corners[3]),
                (quad_uvs[0], quad_uvs[1], quad_uvs[3]),
                facing,
                (colours[0], colours[1], colours[3]),
            )
            self.add_triangle(
                (corners[1], corners[2], corners[3]),
                (quad_uvs[1], quad_uvs[2], quad_uvs[3]),
                facing,
                (colours[1], colours[2], colours[3]),
            )
            return
        self.add_triangle(
            (corners[0], corners[1], corners[2]),
            (quad_uvs[0], quad_uvs[1], quad_uvs[2]),
            facing,
            (colours[0], colours[1], colours[2]),
        )
        self.add_triangle(
            (corners[0], corners[2], corners[3]),
            (quad_uvs[0], quad_uvs[2], quad_uvs[3]),
            facing,
            (colours[0], colours[2], colours[3]),
        )


@dataclass(frozen=True)
class ModelSpec:
    """Describe one independently reusable Stage 1 model export."""

    stem: str
    object_name: str
    material_name: str
    texture_name: str
    origin: str
    mesh: ModelMesh
    transparent: bool = False


def route_center(y_position: float) -> float:
    """Return the gentle authored bend at one forward route coordinate."""
    return math.sin(y_position / 31.0) * 1.5 + math.sin(y_position / 13.0) * 0.4


def smoothstep(value: float) -> float:
    """Ease a clamped terrain factor without introducing sharp bank creases."""
    clamped = max(0.0, min(1.0, value))
    return clamped * clamped * (3.0 - 2.0 * clamped)


def terrain_elevation(x_position: float, y_position: float) -> float:
    """Return authored elevation measured upward along the project's -Z axis."""
    relative_x = x_position - route_center(y_position)
    distance_from_path = abs(relative_x)
    route_roll = (
        math.sin(y_position / 19.0) * 0.18
        + math.sin(y_position / 7.3) * 0.08
    )
    if distance_from_path <= TERRAIN_PATH_HALF_WIDTH:
        path_factor = distance_from_path / TERRAIN_PATH_HALF_WIDTH
        worn_center = 0.10 * path_factor * path_factor
        path_texture_relief = math.sin(y_position / 4.8 + relative_x * 0.7) * 0.018
        return route_roll + worn_center + path_texture_relief

    bank_factor = (
        distance_from_path - TERRAIN_PATH_HALF_WIDTH
    ) / (TERRAIN_FOREST_HALF_WIDTH - TERRAIN_PATH_HALF_WIDTH)
    eased_bank = smoothstep(bank_factor)
    side = -1.0 if relative_x < 0.0 else 1.0
    edge_height = (
        3.25
        + math.sin(y_position / 27.0 + side * 1.2) * 0.65
        + math.sin(y_position / 8.5 - side * 0.6) * 0.35
    )
    forest_relief = eased_bank * (
        math.sin(y_position / 5.4 + relative_x * 0.31) * 0.18
        + math.sin(y_position / 13.7 - relative_x * 0.52) * 0.12
    )
    return route_roll + 0.10 + edge_height * eased_bank + forest_relief


def terrain_cross_section(y_position: float) -> tuple[Vec3, ...]:
    """Build one dense logical row spanning both banks and the worn path."""
    center = route_center(y_position)
    left_path_edge = center - TERRAIN_PATH_HALF_WIDTH
    right_path_edge = center + TERRAIN_PATH_HALF_WIDTH
    x_positions = [
        -TERRAIN_FOREST_HALF_WIDTH
        + (left_path_edge + TERRAIN_FOREST_HALF_WIDTH)
        * strip
        / TERRAIN_BANK_STRIPS
        for strip in range(TERRAIN_BANK_STRIPS + 1)
    ]
    x_positions.extend(
        left_path_edge
        + (right_path_edge - left_path_edge) * strip / TERRAIN_PATH_STRIPS
        for strip in range(1, TERRAIN_PATH_STRIPS + 1)
    )
    x_positions.extend(
        right_path_edge
        + (TERRAIN_FOREST_HALF_WIDTH - right_path_edge)
        * strip
        / TERRAIN_BANK_STRIPS
        for strip in range(1, TERRAIN_BANK_STRIPS + 1)
    )
    return tuple(
        (x_position, y_position, -terrain_elevation(x_position, y_position))
        for x_position in x_positions
    )


def build_terrain() -> ModelMesh:
    """Build a dense rolling path surface without baking reusable props into it."""
    mesh = ModelMesh()
    segment_count = round(
        (TERRAIN_Y_END - TERRAIN_Y_START) / TERRAIN_SEGMENT_LENGTH
    )
    for segment in range(segment_count):
        y_position = TERRAIN_Y_START + segment * TERRAIN_SEGMENT_LENGTH
        next_y = min(TERRAIN_Y_END, y_position + TERRAIN_SEGMENT_LENGTH)
        row = terrain_cross_section(y_position)
        next_row = terrain_cross_section(next_y)
        for strip in range(len(row) - 1):
            is_path = (
                TERRAIN_BANK_STRIPS
                <= strip
                < TERRAIN_BANK_STRIPS + TERRAIN_PATH_STRIPS
            )
            mesh.add_quad(
                (row[strip], row[strip + 1], next_row[strip + 1], next_row[strip]),
                PATH_UV if is_path else FLOOR_UV,
                WORLD_UP,
                flip_diagonal=(segment + strip) % 2 == 1,
            )
    return mesh


def build_billboard() -> ModelMesh:
    """Build one center-anchored unit XY quad for camera-facing shaders."""
    mesh = ModelMesh()
    bottom_left = (-0.5, -0.5, 0.0)
    bottom_right = (0.5, -0.5, 0.0)
    top_right = (0.5, 0.5, 0.0)
    top_left = (-0.5, 0.5, 0.0)
    mesh.add_triangle(
        (bottom_left, bottom_right, top_right),
        ((0.0, 1.0), (1.0, 1.0), (1.0, 0.0)),
        BILLBOARD_FACING,
    )
    mesh.add_triangle(
        (bottom_left, top_right, top_left),
        ((0.0, 1.0), (1.0, 0.0), (0.0, 0.0)),
        BILLBOARD_FACING,
    )
    return mesh


def cylinder_basis(axis: Vec3) -> tuple[Vec3, Vec3]:
    """Create a stable cross-section basis around any authored trunk direction."""
    reference = (1.0, 0.0, 0.0)
    if abs(dot(axis, reference)) > 0.9:
        reference = (0.0, 1.0, 0.0)
    first = normalize(cross(axis, reference))
    return first, normalize(cross(axis, first))


def add_tapered_cylinder(
    mesh: ModelMesh,
    start: Vec3,
    end: Vec3,
    start_radius: float,
    end_radius: float,
    sides: int,
    uv_rect: tuple[float, float, float, float] = BARK_UV,
) -> None:
    """Build one closed faceted trunk or branch around an arbitrary axis."""
    axis = normalize(subtract(end, start))
    first_basis, second_basis = cylinder_basis(axis)
    start_ring: list[Vec3] = []
    end_ring: list[Vec3] = []
    for side in range(sides):
        angle = math.tau * side / sides
        radial = add(multiply(first_basis, math.cos(angle)), multiply(second_basis, math.sin(angle)))
        start_ring.append(add(start, multiply(radial, start_radius)))
        end_ring.append(add(end, multiply(radial, end_radius)))
    u1, v1, u2, v2 = uv_rect
    for side in range(sides):
        next_side = (side + 1) % sides
        start_u = u1 + (u2 - u1) * side / sides
        end_u = u1 + (u2 - u1) * (side + 1) / sides
        face = (start_ring[side], start_ring[next_side], end_ring[next_side], end_ring[side])
        facing = normalize(subtract(average(face), average((start, end))))
        mesh.add_quad(face, (start_u, v1, end_u, v2), facing)
        center_uv = ((u1 + u2) * 0.5, (v1 + v2) * 0.5)
        mesh.add_triangle(
            (start, start_ring[next_side], start_ring[side]),
            (center_uv, (end_u, v2), (start_u, v2)),
            multiply(axis, -1.0),
        )
        mesh.add_triangle(
            (end, end_ring[side], end_ring[next_side]),
            (center_uv, (start_u, v1), (end_u, v1)),
            axis,
        )


def ellipsoid_normal(point: Vec3, center: Vec3, radii: Vec3) -> Vec3:
    """Return the outward analytic direction for an ellipsoid point."""
    return normalize(tuple((point[index] - center[index]) / (radii[index] * radii[index]) for index in range(3)))


def add_ellipsoid(
    mesh: ModelMesh,
    center: Vec3,
    radii: Vec3,
    segments: int = 10,
    rings: int = 4,
) -> None:
    """Build a compact faceted foliage crown with continuous atlas UVs."""
    u1, v1, u2, v2 = FOLIAGE_UV
    ring_points: list[list[Vec3]] = []
    for ring in range(1, rings + 1):
        theta = math.pi * ring / (rings + 1)
        points: list[Vec3] = []
        for segment in range(segments):
            longitude = math.tau * segment / segments
            points.append((center[0] + radii[0] * math.sin(theta) * math.cos(longitude), center[1] + radii[1] * math.sin(theta) * math.sin(longitude), center[2] - radii[2] * math.cos(theta)))
        ring_points.append(points)
    top = (center[0], center[1], center[2] - radii[2])
    bottom = (center[0], center[1], center[2] + radii[2])
    for segment in range(segments):
        next_segment = (segment + 1) % segments
        first_u = u1 + (u2 - u1) * segment / segments
        next_u = u1 + (u2 - u1) * (segment + 1) / segments
        top_face = (top, ring_points[0][segment], ring_points[0][next_segment])
        mesh.add_triangle(
            top_face,
            (((first_u + next_u) * 0.5, v1), (first_u, v1 + (v2 - v1) / (rings + 1)), (next_u, v1 + (v2 - v1) / (rings + 1))),
            ellipsoid_normal(average(top_face), center, radii),
        )
        for ring in range(rings - 1):
            theta_v = v1 + (v2 - v1) * (ring + 1) / (rings + 1)
            next_v = v1 + (v2 - v1) * (ring + 2) / (rings + 1)
            face = (ring_points[ring][segment], ring_points[ring + 1][segment], ring_points[ring + 1][next_segment], ring_points[ring][next_segment])
            mesh.add_quad(face, (first_u, theta_v, next_u, next_v), ellipsoid_normal(average(face), center, radii))
        bottom_face = (ring_points[-1][segment], bottom, ring_points[-1][next_segment])
        mesh.add_triangle(
            bottom_face,
            ((first_u, v2 - (v2 - v1) / (rings + 1)), ((first_u + next_u) * 0.5, v2), (next_u, v2 - (v2 - v1) / (rings + 1))),
            ellipsoid_normal(average(bottom_face), center, radii),
        )


def build_tree_a() -> ModelMesh:
    """Build the broad, balanced tree used along open sections of the route."""
    mesh = ModelMesh()
    add_tapered_cylinder(mesh, (0.0, 0.0, 0.0), (0.0, 0.0, -10.5), 0.82, 0.48, 8)
    add_tapered_cylinder(mesh, (0.0, 0.0, -7.1), (2.7, 0.5, -10.5), 0.38, 0.16, 6)
    add_tapered_cylinder(mesh, (-0.1, 0.0, -7.8), (-2.3, -0.9, -10.8), 0.34, 0.15, 6)
    add_ellipsoid(mesh, (0.0, 0.0, -11.6), (3.4, 3.0, 4.0), 10, 4)
    add_ellipsoid(mesh, (2.4, 0.5, -11.1), (2.6, 2.3, 3.2), 9, 4)
    add_ellipsoid(mesh, (-2.3, -0.7, -11.3), (2.5, 2.2, 3.1), 9, 4)
    return mesh


def build_tree_b() -> ModelMesh:
    """Build a crooked tree silhouette for denser route-wall variation."""
    mesh = ModelMesh()
    add_tapered_cylinder(mesh, (0.0, 0.0, 0.0), (0.5, -0.2, -5.2), 0.74, 0.57, 7)
    add_tapered_cylinder(mesh, (0.5, -0.2, -5.2), (-0.4, 0.4, -9.8), 0.58, 0.38, 7)
    add_tapered_cylinder(mesh, (0.2, 0.0, -6.2), (2.5, -1.0, -9.6), 0.31, 0.13, 6)
    add_tapered_cylinder(mesh, (-0.3, 0.3, -8.0), (-2.1, 1.5, -10.6), 0.28, 0.12, 6)
    add_ellipsoid(mesh, (-0.5, 0.4, -11.0), (3.0, 3.2, 3.8), 9, 4)
    add_ellipsoid(mesh, (2.2, -0.9, -10.4), (2.2, 2.4, 2.9), 8, 3)
    add_ellipsoid(mesh, (-2.0, 1.5, -10.7), (2.1, 2.2, 2.8), 8, 3)
    return mesh


def build_world_tree() -> ModelMesh:
    """Build the standalone World Tree landmark around its ground-level origin."""
    mesh = ModelMesh()
    add_tapered_cylinder(mesh, (0.0, 0.0, 0.0), (0.0, 0.0, -30.0), 5.8, 3.2, 14)
    for index in range(8):
        angle = math.tau * index / 8
        root_end = (math.cos(angle) * 11.0, math.sin(angle) * 8.5, 0.8)
        root_start = (math.cos(angle) * 3.2, math.sin(angle) * 3.2, -1.5)
        add_tapered_cylinder(mesh, root_start, root_end, 1.65, 0.35, 6)
    for start, end, start_radius, end_radius in (
        ((0.0, 0.0, -20.0), (-9.0, 1.5, -34.0), 1.6, 0.5),
        ((0.0, 0.0, -21.5), (9.5, 1.0, -34.5), 1.7, 0.5),
        ((0.0, 0.0, -24.0), (1.0, 8.5, -37.0), 1.4, 0.45),
        ((0.0, 0.0, -25.0), (-1.5, -7.5, -36.0), 1.3, 0.4),
    ):
        add_tapered_cylinder(mesh, start, end, start_radius, end_radius, 8)
    add_ellipsoid(mesh, (0.0, 0.0, -39.0), (10.5, 9.0, 9.0), 12, 5)
    add_ellipsoid(mesh, (-9.0, 1.5, -35.5), (7.5, 6.0, 7.0), 11, 5)
    add_ellipsoid(mesh, (9.5, 1.0, -36.0), (8.0, 6.5, 7.5), 11, 5)
    add_ellipsoid(mesh, (1.0, 8.0, -38.0), (7.5, 6.0, 7.0), 11, 5)
    add_ellipsoid(mesh, (-1.0, -7.0, -37.0), (7.0, 5.5, 6.5), 11, 5)
    return mesh


def build_skybox() -> ModelMesh:
    """Build a camera-centered box with inward faces and a dawn tint gradient."""
    mesh = ModelMesh()
    left, right = -70.0, 70.0
    back, front = -90.0, 90.0
    top, bottom = -55.0, 35.0
    high_colour = game_maker_colour(151, 191, 211)
    horizon_colour = game_maker_colour(244, 179, 142)
    low_colour = game_maker_colour(122, 105, 139)
    mesh.add_quad(((left, back, top), (right, back, top), (right, back, bottom), (left, back, bottom)), SKY_UV, (0.0, 1.0, 0.0), (high_colour, high_colour, horizon_colour, horizon_colour))
    mesh.add_quad(((right, front, top), (left, front, top), (left, front, bottom), (right, front, bottom)), SKY_UV, (0.0, -1.0, 0.0), (high_colour, high_colour, horizon_colour, horizon_colour))
    mesh.add_quad(((left, front, top), (left, back, top), (left, back, bottom), (left, front, bottom)), SKY_UV, (1.0, 0.0, 0.0), (high_colour, high_colour, horizon_colour, horizon_colour))
    mesh.add_quad(((right, back, top), (right, front, top), (right, front, bottom), (right, back, bottom)), SKY_UV, (-1.0, 0.0, 0.0), (high_colour, high_colour, horizon_colour, horizon_colour))
    mesh.add_quad(((left, back, top), (left, front, top), (right, front, top), (right, back, top)), SKY_UV, (0.0, 0.0, 1.0), (high_colour, high_colour, high_colour, high_colour))
    mesh.add_quad(((left, front, bottom), (left, back, bottom), (right, back, bottom), (right, front, bottom)), SKY_UV, (0.0, 0.0, -1.0), (low_colour, low_colour, low_colour, low_colour))
    return mesh


def build_models() -> tuple[ModelSpec, ...]:
    """Create every modular model in a fixed export order."""
    forest_texture = "lost_forest_materials.png"
    billboard_origin = (
        "local XY unit quad centered at (0,0,0); +X is visual right, +Y is "
        "visual up, Z=0, runtime UV v=0 is the visual top, and OBJ/Blender V "
        "is conventionally flipped"
    )
    return (
        ModelSpec(
            "lost_forest_terrain",
            "LostForestTerrain",
            "LostForestTerrainMaterial",
            forest_texture,
            "route coordinates; low worn path near Z=0, banks rise toward -Z",
            build_terrain(),
        ),
        ModelSpec(
            "lost_forest_tree_a",
            "LostForestTreeA",
            "LostForestTreeAMaterial",
            forest_texture,
            "trunk center at ground Z=0; tree grows toward -Z",
            build_tree_a(),
        ),
        ModelSpec(
            "lost_forest_tree_b",
            "LostForestTreeB",
            "LostForestTreeBMaterial",
            forest_texture,
            "trunk center at ground Z=0; tree grows toward -Z",
            build_tree_b(),
        ),
        ModelSpec(
            "lost_forest_world_tree",
            "LostForestWorldTree",
            "LostForestWorldTreeMaterial",
            forest_texture,
            "trunk center at ground Z=0; tree grows toward -Z",
            build_world_tree(),
        ),
        ModelSpec(
            "lost_forest_skybox",
            "LostForestSkybox",
            "LostForestSkyboxMaterial",
            "lost_forest_skybox.png",
            "camera-centered; renderer translates the box with the 3D camera",
            build_skybox(),
        ),
        ModelSpec(
            "lost_forest_grass_billboard",
            "LostForestGrassBillboard",
            "LostForestGrassBillboardMaterial",
            "lost_forest_grass.png",
            billboard_origin,
            build_billboard(),
            True,
        ),
        ModelSpec(
            "lost_forest_vines_billboard",
            "LostForestVinesBillboard",
            "LostForestVinesBillboardMaterial",
            "lost_forest_vines.png",
            billboard_origin,
            build_billboard(),
            True,
        ),
        ModelSpec(
            "lost_forest_bush_billboard",
            "LostForestBushBillboard",
            "LostForestBushBillboardMaterial",
            "lost_forest_bush.png",
            billboard_origin,
            build_billboard(),
            True,
        ),
        ModelSpec(
            "lost_forest_fae_billboard",
            "LostForestFaeBillboard",
            "LostForestFaeBillboardMaterial",
            "lost_forest_fae.png",
            billboard_origin,
            build_billboard(),
            True,
        ),
        ModelSpec(
            "lost_forest_ball_light_billboard",
            "LostForestBallLightBillboard",
            "LostForestBallLightBillboardMaterial",
            "lost_forest_ball_light.png",
            billboard_origin,
            build_billboard(),
            True,
        ),
    )


def mesh_bounds(mesh: ModelMesh) -> tuple[Vec3, Vec3]:
    """Return deterministic axis-aligned bounds for reporting and validation."""
    return (
        tuple(min(vertex.position[index] for vertex in mesh.vertices) for index in range(3)),
        tuple(max(vertex.position[index] for vertex in mesh.vertices) for index in range(3)),
    )


def validate_mesh(spec: ModelSpec) -> None:
    """Reject malformed triangles before any source or runtime asset is written."""
    vertices = spec.mesh.vertices
    if not vertices or len(vertices) % 3 != 0:
        raise RuntimeError(f"{spec.stem} must contain complete triangles")
    for vertex in vertices:
        if not all(math.isfinite(component) for component in (*vertex.position, *vertex.normal, *vertex.uv)):
            raise RuntimeError(f"{spec.stem} contains a non-finite vertex component")
        if abs(length(vertex.normal) - 1.0) > 1.0e-5:
            raise RuntimeError(f"{spec.stem} contains a non-unit normal")
        if not all(0.0 <= component <= 1.0 for component in vertex.uv):
            raise RuntimeError(f"{spec.stem} contains a UV outside its material")
    for index in range(0, len(vertices), 3):
        first, second, third = vertices[index : index + 3]
        geometric_normal = normalize(cross(subtract(second.position, first.position), subtract(third.position, first.position)))
        for vertex in (first, second, third):
            if dot(geometric_normal, vertex.normal) < 0.99999:
                raise RuntimeError(f"{spec.stem} contains a normal opposed to its winding")
    if spec.stem.endswith("_billboard"):
        lower, upper = mesh_bounds(spec.mesh)
        if (
            len(vertices) != 6
            or lower != (-0.5, -0.5, 0.0)
            or upper != (0.5, 0.5, 0.0)
        ):
            raise RuntimeError(
                f"{spec.stem} does not match the centered unit billboard contract"
            )
        if any(vertex.normal != BILLBOARD_FACING for vertex in vertices):
            raise RuntimeError(f"{spec.stem} does not use the harmless +Z billboard normal")
        if {vertex.uv for vertex in vertices} != {
            (0.0, 0.0),
            (1.0, 0.0),
            (0.0, 1.0),
            (1.0, 1.0),
        }:
            raise RuntimeError(f"{spec.stem} does not span its full texture")
    if spec.stem == "lost_forest_terrain":
        lower, upper = mesh_bounds(spec.mesh)
        if len(vertices) // 3 < 3000 or lower[2] > -2.0 or upper[2] < 0.05:
            raise RuntimeError("Lost Forest terrain is not a dense rolling surface")


def write_obj(spec: ModelSpec, obj_path: Path, mtl_path: Path) -> None:
    """Write readable interchange geometry matching the runtime triangle order."""
    lines = [
        f"# Blade of Desires Stage 1 {spec.object_name}",
        f"# Origin: {spec.origin}",
        f"mtllib {mtl_path.name}",
        f"o {spec.object_name}",
    ]
    for vertex in spec.mesh.vertices:
        lines.append("v " + " ".join(f"{component:.6f}" for component in vertex.position))
    for vertex in spec.mesh.vertices:
        lines.append(f"vt {vertex.uv[0]:.6f} {1.0 - vertex.uv[1]:.6f}")
    for vertex in spec.mesh.vertices:
        lines.append("vn " + " ".join(f"{component:.6f}" for component in vertex.normal))
    lines.append(f"usemtl {spec.material_name}")
    for vertex_index in range(0, len(spec.mesh.vertices), 3):
        first = vertex_index + 1
        lines.append(f"f {first}/{first}/{first} {first + 1}/{first + 1}/{first + 1} {first + 2}/{first + 2}/{first + 2}")
    obj_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    texture_reference = f"../../../runtime/textures/stage1/{spec.texture_name}"
    material_lines = [
        f"# Blade of Desires Stage 1 {spec.object_name} material",
        f"newmtl {spec.material_name}",
        "Ka 0.180000 0.180000 0.180000",
        "Kd 1.000000 1.000000 1.000000",
        "Ks 0.000000 0.000000 0.000000",
        "d 1.000000",
        "illum 2",
        f"map_Kd {texture_reference}",
    ]
    if spec.transparent:
        material_lines.append(f"map_d {texture_reference}")
    mtl_path.write_text("\n".join(material_lines) + "\n", encoding="utf-8")


def write_vbuff(mesh: ModelMesh, path: Path) -> None:
    """Write GameMaker's 36-byte position, normal, colour, and texture layout."""
    with path.open("wb") as output:
        for vertex in mesh.vertices:
            output.write(struct.pack("<ffffffIff", *vertex.position, *vertex.normal, vertex.colour, *vertex.uv))
    if path.stat().st_size != len(mesh.vertices) * VBUFF_VERTEX_SIZE:
        raise RuntimeError(f"{path.name} does not match the 36-byte vertex contract")


def reset_blender() -> None:
    """Clear prior export data so each Blend contains only its own editable model."""
    bpy.ops.wm.read_factory_settings(use_empty=True)


def write_blend(spec: ModelSpec, path: Path, texture_path: Path) -> None:
    """Create one editable scene with explicit -Z-up and runtime metadata."""
    reset_blender()
    positions = [vertex.position for vertex in spec.mesh.vertices]
    faces = [(index, index + 1, index + 2) for index in range(0, len(positions), 3)]
    blender_mesh = bpy.data.meshes.new(f"{spec.object_name}Mesh")
    blender_mesh.from_pydata(positions, [], faces)
    blender_mesh.update()
    uv_layer = blender_mesh.uv_layers.new(name="LostForestMaterialUV")
    colour_layer = blender_mesh.color_attributes.new(name="LostForestTint", type="BYTE_COLOR", domain="CORNER")
    for loop in blender_mesh.loops:
        vertex = spec.mesh.vertices[loop.vertex_index]
        uv_layer.data[loop.index].uv = (vertex.uv[0], 1.0 - vertex.uv[1])
        colour_layer.data[loop.index].color = colour_components(vertex.colour)
    material = bpy.data.materials.new(spec.material_name)
    material.use_nodes = True
    material.use_backface_culling = not spec.transparent
    nodes = material.node_tree.nodes
    image_node = nodes.new("ShaderNodeTexImage")
    image = bpy.data.images.load(str(texture_path))
    image.pack()
    image_node.image = image
    image_node.interpolation = "Closest"
    shader = nodes.get("Principled BSDF")
    material.node_tree.links.new(image_node.outputs["Color"], shader.inputs["Base Color"])
    if spec.transparent:
        material.node_tree.links.new(image_node.outputs["Alpha"], shader.inputs["Alpha"])
        if hasattr(material, "surface_render_method"):
            material.surface_render_method = "DITHERED"
        elif hasattr(material, "blend_method"):
            material.blend_method = "CLIP"
        material["blade_runtime_alpha"] = "shader-controlled cutout or blend"
    shader.inputs["Roughness"].default_value = 0.92
    blender_mesh.materials.append(material)
    model_object = bpy.data.objects.new(spec.object_name, blender_mesh)
    bpy.context.collection.objects.link(model_object)
    model_object["blade_world_up"] = "-Z"
    model_object["blade_model_origin"] = spec.origin
    model_object["blade_runtime_vertex_layout"] = "position3 normal3 colour4ub uv2"
    if spec.stem.endswith("_billboard"):
        model_object["blade_billboard_plane"] = "local XY; X right and Y visual up"
        model_object["blade_billboard_uv"] = (
            "full texture; runtime v=0 visual top; Blender V is flipped"
        )
        model_object["blade_billboard_normal"] = "+Z; ignored by billboard shaders"
    scene = bpy.context.scene
    scene["blade_world_up"] = "-Z"
    scene["blade_model_origin"] = spec.origin
    scene["blade_runtime_texture"] = f"textures/stage1/{spec.texture_name}"
    scene["blade_gameplay_isolation"] = "presentation_only"
    bpy.context.view_layer.objects.active = model_object
    model_object.select_set(True)
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=str(path), compress=True)


def main() -> None:
    """Build all governed source and runtime models from deterministic geometry."""
    repository = Path(__file__).resolve().parents[2]
    source_directory = repository / "assets/source/models/stage1"
    runtime_directory = repository / "assets/runtime/models/stage1"
    texture_directory = repository / "assets/runtime/textures/stage1"
    source_directory.mkdir(parents=True, exist_ok=True)
    runtime_directory.mkdir(parents=True, exist_ok=True)
    for spec in build_models():
        texture_path = texture_directory / spec.texture_name
        if not texture_path.exists():
            raise FileNotFoundError(f"Missing governed forest texture: {texture_path}")
        validate_mesh(spec)
        obj_path = source_directory / f"{spec.stem}.obj"
        mtl_path = source_directory / f"{spec.stem}.mtl"
        write_obj(spec, obj_path, mtl_path)
        write_vbuff(spec.mesh, runtime_directory / f"{spec.stem}.vbuff")
        write_blend(spec, source_directory / f"{spec.stem}.blend", texture_path)
        lower, upper = mesh_bounds(spec.mesh)
        print(f"Built {spec.stem}: {len(spec.mesh.vertices)} vertices, {len(spec.mesh.vertices) // 3} triangles, bounds {lower} to {upper}")


if __name__ == "__main__":
    main()

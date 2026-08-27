x += velocity_x;
y += velocity_y;
if (!BladeFirstBeatPointInsidePlane(x, y)) {
    instance_destroy();
}

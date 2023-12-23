const rl = @import("rl.zig");
const std = @import("std");

// BEGIN ENUMS
const Color = enum(u32) {
    white = 0xFFFFFFFF,
    purple = 0x7BF967AA,
    red = 0xFC1A17CC,
    dark_gray = 0x18181822,
    blue = 0x0000CCFF,
    green = 0x00AA0022,
    void = 0xFF00FFFF,

    pub fn make_rl_color(col: Color) rl.Color {
        var color = @intFromEnum(col);
        const r: u8 = @truncate((color >> (3 * 8)) & 0xFF);
        const g: u8 = @truncate((color >> (2 * 8)) & 0xFF);
        const b: u8 = @truncate((color >> (1 * 8)) & 0xFF);
        const a: u8 = @truncate((color >> (0 * 8)) & 0xFF);

        return rl.Color{
            .r = r,
            .g = g,
            .b = b,
            .a = a,
        };
    }
};

const ElemID = enum {
    Platform,
    Wall,
};

const Mode = enum {
    Play,
    Edit,
};
// END ENUMS

// BEGIN STRUCTS
const EnvItem = struct {
    id: ElemID = .Platform,
    pos: rl.Vector2 = .{ .x = 0, .y = 0 },
    rect: rl.Rectangle = .{ .x = 0, .y = 0, .width = 0, .height = 0 },
    blocking: bool = true,
    col: rl.Color = rl.GRAY,
};

const Player = struct {
    pos: rl.Vector2 = .{ .x = 0, .y = 0 },
    speed: f32 = 0,
    can_jump: bool = false,
};

const UI = struct {
    id: u8,
    hot_id: ?u8 = null,
    active_id: ?u8 = null,

    pub fn button(ui: *UI, id: u8, rect: rl.Rectangle) bool {
        const mouse = rl.GetMousePosition();
        if (ui.hot_id) |h_id| {
            if (h_id == id) {
                // handle hot
            }
        }
        if (ui.active_id) |a_id| {
            if (a_id == id) {
                // do action
            }
        }

        if (rl.CheckCollisionPointRec(mouse, rect)) {
            if (rl.IsMouseButtonPressed(1)) {
                ui.active_id = id;
                std.debug.print("mouse press!!\n", .{});
            } else {}
        }
        return false;
    }
};
// END STRUCTS

// BEGIN CONSTANTS
const GRAVITY = 900;
const PLAYER_JUMP_SPEED = 450.0;
const PLAYER_MOVE_SPEED = 400.0;
// END CONSTANTS

pub fn main() anyerror!void {
    // Initialization
    //--------------------------------------------------------------------------------------
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var alloc = gpa.allocator();

    const args = try std.process.argsAlloc(alloc);
    defer std.process.argsFree(alloc, args);

    const window_scale = 80;
    const screenWidth = 16 * window_scale;
    const screenHeight = 10 * window_scale;

    rl.InitWindow(screenWidth, screenHeight, "platformer");
    defer rl.CloseWindow(); // Close window and OpenGL context

    var mode: Mode = .Play;

    var player: Player = Player{};
    player.pos = rl.Vector2{ .x = 300, .y = 200 };

    var tex: rl.Texture2D = rl.LoadTexture("assets/texmap.png");

    var env = [_]EnvItem{
        EnvItem{
            .rect = rl.Rectangle{
                .x = 0,
                .y = 0,
                .width = 1000,
                .height = 500,
            },
            .col = rl.LIGHTGRAY,
            .blocking = false,
        },
        EnvItem{
            .rect = rl.Rectangle{
                .x = 0,
                .y = 400,
                .width = 1000,
                .height = 200,
            },
            .col = rl.GRAY,
            .blocking = true,
        },
        EnvItem{
            .rect = rl.Rectangle{
                .x = 300,
                .y = 200,
                .width = 400,
                .height = 10,
            },
            .col = rl.GRAY,
            .blocking = true,
        },
        EnvItem{
            .rect = rl.Rectangle{
                .x = 250,
                .y = 300,
                .width = 100,
                .height = 10,
            },
            .col = rl.GRAY,
            .blocking = true,
        },
    };

    var camera = rl.Camera2D{
        .zoom = 1,
        .offset = rl.Vector2{ .x = screenWidth / 2, .y = screenHeight / 2 },
        .rotation = 0,
        .target = player.pos,
    };
    var toolbar = UI{ .id = 0 };
    var debug_menu = UI{ .id = 1 };
    _ = debug_menu;

    var selected: ?u8 = null;

    rl.SetTargetFPS(60); // Set game to run at 60 frames-per-second
    rl.SetExitKey(rl.KEY_Q);
    //--------------------------------------------------------------------------------------

    // Main game loop
    while (!rl.WindowShouldClose()) { // Detect window close button or ESC key
        // Update
        //----------------------------------------------------------------------------------
        const delta_time: f32 = rl.GetFrameTime();

        switch (mode) {
            .Play => {
                if (rl.IsKeyPressed(rl.KEY_F5)) mode = .Edit;
            },
            .Edit => {
                if (rl.IsKeyPressed(rl.KEY_F5)) mode = .Play;
                if (selected) |sel| {
                    _ = sel;
                    if (rl.IsMouseButtonPressed(1)) {
                        // place elem of sel
                    }
                }
            },
        }
        update_player(&player, &env, delta_time);

        camera.zoom += rl.GetMouseWheelMove() * 0.05;

        if (camera.zoom > 3.0) {
            camera.zoom = 3.0;
        } else if (camera.zoom < 0.25) {
            camera.zoom = 0.25;
        }

        if (rl.IsKeyPressed(rl.KEY_R)) {
            camera.zoom = 1.0;
            player.pos = rl.Vector2{ .x = 300, .y = 200 };
        }

        update_cam(&camera, &player, screenWidth, screenHeight);

        // Draw
        //----------------------------------------------------------------------------------
        rl.BeginDrawing();
        defer rl.EndDrawing();

        rl.ClearBackground(rl.LIGHTGRAY);

        rl.BeginMode2D(camera);
        for (env) |item| {
            rl.DrawRectangleRec(item.rect, item.col);
            rl.DrawTextureRec(tex, .{ .x = 0, .y = 0, .width = 32, .height = 32 }, .{ .x = item.rect.x, .y = item.rect.y }, rl.WHITE);
        }
        const player_rect = rl.Rectangle{
            .x = player.pos.x - 20,
            .y = player.pos.y - 40,
            .width = 40,
            .height = 40,
        };

        rl.DrawRectangleRec(player_rect, rl.RED);

        rl.EndMode2D();
        if (mode == .Edit) {
            draw_player_debug_info(alloc, &player, screenWidth, screenHeight);
            draw_env_entities_debug_info(alloc, &env, screenWidth, screenHeight);
            // Immediate Mode UI
            //------------------------------------------------------------------------------
            draw_toolbar(
                .{
                    .x = 30,
                    .y = 50,
                },
                100,
                300,
                Color.make_rl_color(Color.dark_gray),
                &toolbar,
                &selected,
            );
            //------------------------------------------------------------------------------
            rl.DrawFPS(20, 20);
        }
        //----------------------------------------------------------------------------------
    }
}

fn draw_toolbar(pos: rl.Vector2, w: f32, h: f32, col: rl.Color, tb: *UI, sel: *?u8) void {
    rl.DrawRectangleRec(
        .{
            .x = pos.x,
            .y = pos.y,
            .width = w,
            .height = h,
        },
        col,
    );
    if (tb.button(0, .{ .x = pos.x + 8, .y = pos.y, .width = 32, .height = 32 })) {
        sel.* = 0;
    }
}

fn draw_env_entities_debug_info(alloc: std.mem.Allocator, env: []EnvItem, screenWidth: i32, screenHeight: i32) void {
    _ = screenHeight;
    _ = screenWidth;
    _ = env;
    _ = alloc;
}

fn draw_player_debug_info(alloc: std.mem.Allocator, player: *Player, screenWidth: i32, screenHeight: i32) void {
    _ = screenHeight;
    rl.DrawRectangleRec(
        rl.Rectangle{
            .x = @floatFromInt(screenWidth - 350),
            .y = 20,
            .width = 300,
            .height = 130,
        },
        Color.make_rl_color(Color.green),
    );

    var str = std.fmt.allocPrint(
        alloc,
        "PLAYER\n\npos: ({d:.2}, {d:.2})\n\nv-speed: {d:.2}\n\ncan_jump: {any}\n\n",
        .{
            player.pos.x,
            player.pos.y,
            player.speed,
            player.can_jump,
        },
    ) catch "Err";
    defer alloc.free(str);
    @constCast(str)[str.len - 1] = 0;
    const player_info_str = str[0 .. str.len - 1 :0];

    rl.DrawText(player_info_str, screenWidth - 330, 30, 24, rl.WHITE);
}

fn update_player(player: *Player, env: []EnvItem, delta_time: f32) void {
    if (rl.IsKeyDown(rl.KEY_A)) player.pos.x -= PLAYER_MOVE_SPEED * delta_time;
    if (rl.IsKeyDown(rl.KEY_D)) player.pos.x += PLAYER_MOVE_SPEED * delta_time;
    if (rl.IsKeyDown(rl.KEY_SPACE) and player.can_jump) {
        player.speed = -PLAYER_JUMP_SPEED;
        player.can_jump = false;
    }

    var hit_obstacle = false;
    for (env) |item| {
        if (item.blocking and
            item.rect.x <= player.pos.x and
            item.rect.x + item.rect.width >= player.pos.x and
            item.rect.y >= player.pos.y and
            item.rect.y <= player.pos.y + player.speed * delta_time)
        {
            hit_obstacle = true;
            player.speed = 0;
            player.pos.y = item.rect.y;
        }
    }

    if (!hit_obstacle) {
        player.pos.y += player.speed * delta_time;
        player.speed += GRAVITY * delta_time;
        player.can_jump = false;
    } else {
        player.can_jump = true;
    }
}

fn update_cam(cam: *rl.Camera2D, player: *Player, w: i32, h: i32) void {
    const bbox = rl.Vector2{ .x = 0.2, .y = 0.2 };

    const bboxWorldMin: rl.Vector2 = rl.GetScreenToWorld2D(
        rl.Vector2{
            .x = (1 - bbox.x) * 0.5 * @as(f32, @floatFromInt(w)),
            .y = (1 - bbox.y) * 0.5 * @as(f32, @floatFromInt(h)),
        },
        cam.*,
    );
    const bboxWorldMax: rl.Vector2 = rl.GetScreenToWorld2D(
        rl.Vector2{
            .x = (1 + bbox.x) * 0.5 * @as(f32, @floatFromInt(w)),
            .y = (1 + bbox.y) * 0.5 * @as(f32, @floatFromInt(h)),
        },
        cam.*,
    );
    cam.offset = rl.Vector2{
        .x = (1 - bbox.x) * 0.5 * @as(f32, @floatFromInt(w)),
        .y = (1 - bbox.y) * 0.5 * @as(f32, @floatFromInt(h)),
    };

    if (player.pos.x < bboxWorldMin.x) cam.target.x = player.pos.x;
    if (player.pos.y < bboxWorldMin.y) cam.target.y = player.pos.y;
    if (player.pos.x > bboxWorldMax.x) cam.target.x = bboxWorldMin.x + (player.pos.x - bboxWorldMax.x);
    if (player.pos.y > bboxWorldMax.y) cam.target.y = bboxWorldMin.y + (player.pos.y - bboxWorldMax.y);
}

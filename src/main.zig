const rl = @import("rl.zig");
const std = @import("std");
const builtin = @import("builtin");

pub const EXIT_KEY = switch (builtin.mode) {
    .Debug => rl.KEY_Q,
    else => rl.KEY_NULL,
};

// BEGIN ENUMS
//----------------------------------------------------------------------------------
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
    Portal,
};

const Mode = enum {
    Debug,
    Edit,
    Play,
};
//----------------------------------------------------------------------------------

// BEGIN STRUCTS
//----------------------------------------------------------------------------------
const EnvItem = struct {
    id: ElemID = .Platform,
    pos: rl.Vector2 = .{ .x = 0, .y = 0 },
    rect: rl.Rectangle = .{ .x = 0, .y = 0, .width = 0, .height = 0 },
    blocking: bool = true,
    col: rl.Color = rl.GRAY,
};

//***********************************************************************//
//                                                                       //
//                             *** TODO ***                              //
//                                                                       //
// --------------------------------------------------------------------- //
//                                                                       //
//  Previous approach was to make Portals a separate element entirely.   //
//  I want to be able to have a regular EnvItem that happens to act as   //
//  as a portal. My current Idea is to give a UID to each item and refer //
//  that way. I need something better to enable linking of portals       //
//  without having every single EnvItem contain a pointer.               //
//                                                                       //
//  IDEAS (in order of how much I like them):                            //
//    - Create Separate Portal Array -- add pairs, with UUID identifier  //
//    - Just Portal Array, give pointers, hope it's correct              //
//    - Add 'portal-link' prop to EnvItem and only use for portal        //
//                                                                       //
//  OTHER IDEA:                                                          //
//    - Just fully separate portals from EnvItem -- they share ID enum,  //
//      but will be in separate array, of separate struct type           //
//      -> this will require restructuring the editor a bit              //
//***********************************************************************//

const Portal = struct {
    pos: rl.Vector2,
    link: ?*Portal,
};

const Player = struct {
    pos: rl.Vector2 = .{ .x = 0, .y = 0 },
    dy: f32 = 0,
    dx: f32 = 0,
    size: rl.Vector2 = .{ .x = 48, .y = 62 },
    can_jump: bool = false,
};

//***********************************************************************//
//                                                                       //
//                             *** TODO ***                              //
//                                                                       //
// --------------------------------------------------------------------- //
//  Improve and flesh out UI struct more, move out to separate file when //
//  struct begins to get larger and more comprehensive                   //
//                                                                       //
//  FEATURES MISSING:                                                    //
//      - Dropdown UI Element                                            //
//      - Debug Info Box (implemented in terms of the above)             //
//      - Basic Menu -- for a settngs menu                               //
//      - Need to write a proper title screen -- with access to settings //
//                                                                       //
//***********************************************************************//
const UI = struct {
    id: u8,
    hot_id: ?u8 = null,
    active_id: ?u8 = null,

    pub fn button(ui: *UI, id: u8, rect: rl.Rectangle) bool {
        const mouse = rl.GetMousePosition();
        if (ui.hot_id) |h_id| {
            if (h_id == id) {
                rl.DrawRectangleLinesEx(rect, 0.8, rl.PURPLE);
                // handle hot
            }
        }
        if (ui.active_id) |a_id| {
            if (a_id == id) {
                ui.active_id = null;
                std.debug.print("I'm doing my part!!\n", .{});
                return true;
            }
        }

        if (rl.CheckCollisionPointRec(mouse, rect)) {
            if (rl.IsMouseButtonPressed(0)) {
                ui.active_id = id;
            } else {}
        }
        return false;
    }
};
//----------------------------------------------------------------------------------

// BEGIN CONSTANTS
//----------------------------------------------------------------------------------
const GRAVITY = 1200;
const PLAYER_JUMP_SPEED = 450.0;
const PLAYER_MOVE_SPEED = 400.0;
const TARGET_FPS = 60;
//----------------------------------------------------------------------------------

pub fn main() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var alloc = gpa.allocator();

    const args = try std.process.argsAlloc(alloc);
    defer std.process.argsFree(alloc, args);

    const stderr = std.io.getStdErr().writer();

    const window_scale = 80;
    const screenWidth = 16 * window_scale;
    const screenHeight = 10 * window_scale;

    rl.InitWindow(screenWidth, screenHeight, "platformer");
    defer rl.CloseWindow();
    rl.InitAudioDevice();
    defer rl.CloseAudioDevice();

    const music = rl.LoadMusicStream("assets/sounds/8_Bit_Nostalgia.mp3");
    rl.PlayMusicStream(music);
    defer rl.UnloadMusicStream(music);
    var music_paused = false;
    var music_muted = true;
    var music_volume: f32 = 0.6;
    rl.SetMusicVolume(music, 0);

    var mode: Mode = .Play;

    var player: Player = Player{};
    player.pos = rl.Vector2{ .x = 300, .y = 200 };
    var player_tex_offset: rl.Vector2 = .{ .x = 0, .y = 64 };

    var tex: rl.Texture2D = rl.LoadTexture("assets/texmap.png");

    var start_env = [_]?EnvItem{
        EnvItem{
            .rect = .{
                .x = 0,
                .y = 400,
                .width = 1000,
                .height = 200,
            },
            .col = rl.GRAY,
            .blocking = true,
        },
        EnvItem{
            .rect = .{
                .x = 300,
                .y = 250,
                .width = 400,
                .height = 10,
            },
            .col = rl.GRAY,
            .blocking = true,
        },
        EnvItem{
            .rect = .{
                .x = 250,
                .y = 325,
                .width = 100,
                .height = 10,
            },
            .col = rl.GRAY,
            .blocking = true,
        },
        EnvItem{
            .rect = .{
                .x = 800,
                .y = 100,
                .width = 10,
                .height = 200,
            },
            .id = .Wall,
            .col = rl.GRAY,
            .blocking = true,
        },
        null,
    };

    var env: std.ArrayList(?EnvItem) = std.ArrayList(?EnvItem).init(alloc);
    for (start_env, 0..) |_, i| {
        if (start_env[i] != null) try env.append(start_env[i]);
    }

    var camera = rl.Camera2D{
        .zoom = 1,
        .offset = rl.Vector2{ .x = screenWidth / 2, .y = screenHeight / 2 },
        .rotation = 0,
        .target = player.pos,
    };
    var toolbar = UI{ .id = 0 };
    var debug_menu = UI{ .id = 1 };
    _ = debug_menu;

    var draw_tick: i64 = std.time.milliTimestamp();
    var player_tick_counter: u8 = 0;

    var selected: ?ElemID = null;

    rl.SetTargetFPS(TARGET_FPS);
    rl.SetExitKey(EXIT_KEY);

    while (!rl.WindowShouldClose()) {
        // Update
        //----------------------------------------------------------------------------------
        rl.UpdateMusicStream(music);
        if (rl.IsKeyPressed(rl.KEY_P)) {
            music_paused = !music_paused;
            if (music_paused) rl.PauseMusicStream(music) else rl.ResumeMusicStream(music);
        }

        if (rl.IsKeyPressed(rl.KEY_M)) {
            music_muted = !music_muted;

            if (music_muted) rl.SetMusicVolume(music, 0) else rl.SetMusicVolume(music, music_volume);
        }

        const delta_time: f32 = rl.GetFrameTime();

        var ticked_draw = false;
        const new_tick: i64 = std.time.milliTimestamp();
        if (new_tick - draw_tick > 200) {
            draw_tick = new_tick;
            ticked_draw = true;
        }

        switch (mode) {
            .Debug => {
                if (rl.IsKeyPressed(rl.KEY_F5)) mode = .Edit;
                if (rl.IsKeyPressed(rl.KEY_F3)) mode = .Play;
            },
            .Edit => {
                if (rl.IsKeyPressed(rl.KEY_F5)) mode = .Play;
                if (rl.IsKeyPressed(rl.KEY_F3)) mode = .Debug;
                if (selected) |sel| {
                    if (rl.IsMouseButtonPressed(1)) selected = null;
                    if (rl.IsMouseButtonPressed(0)) {
                        const pos = rl.GetMousePosition();
                        env.append(.{
                            .id = sel,
                            .pos = pos,
                            .rect = switch (sel) {
                                .Wall => .{
                                    .x = pos.x - (camera.offset.x - camera.target.x),
                                    .y = pos.y - (camera.offset.y - camera.target.y),
                                    .width = 16,
                                    .height = 128,
                                },
                                .Platform => .{
                                    .x = pos.x - (camera.offset.x - camera.target.x),
                                    .y = pos.y - (camera.offset.y - camera.target.y),
                                    .width = 128,
                                    .height = 16,
                                },
                                .Portal => .{
                                    .x = pos.x - (camera.offset.x - camera.target.x),
                                    .y = pos.y - (camera.offset.y - camera.target.y),
                                    .width = 10,
                                    .height = 16,
                                },
                            },
                        }) catch try stderr.print("Failed to add item of id {any} to env arraylist\n", .{sel});
                    }
                }
            },
            .Play => {
                if (rl.IsKeyPressed(rl.KEY_F5)) mode = .Edit;
                if (rl.IsKeyPressed(rl.KEY_F3)) mode = .Debug;
            },
        }
        update_player(&player, env.items, delta_time);

        if (ticked_draw) {
            if (player.dx != 0 and player.dy == 0) {
                player_tex_offset.x = if (player_tex_offset.x == 0) 96 else 0;
            } else if (player.dx == 0 and player.dy != 0) {
                // fall animation
            } else {
                if (player_tex_offset.x != 32 and player_tex_offset.x != 64) player_tex_offset.x = 32;
                if (player_tick_counter == 3) {
                    player_tex_offset.x = if (player_tex_offset.x == 64) 32 else 64;
                    player_tick_counter = 0;
                } else {
                    player_tick_counter += 1;
                }
            }
        }

        if (rl.IsKeyDown(rl.KEY_LEFT_CONTROL) or rl.IsKeyDown(rl.KEY_RIGHT_CONTROL)) camera.zoom += rl.GetMouseWheelMove() * 0.05;

        if (camera.zoom > 3.0) {
            camera.zoom = 3.0;
        } else if (camera.zoom < 0.25) {
            camera.zoom = 0.25;
        }

        if (rl.IsKeyPressed(rl.KEY_R)) {
            camera.zoom = 1.0;
            player.pos = rl.Vector2{ .x = 300, .y = 200 };
        }

        if (mode != .Edit) {
            update_cam(&camera, &player, screenWidth, screenHeight);
        } else {
            const scroll = rl.GetMouseWheelMoveV();
            camera.offset.x += scroll.x * 15;
            camera.offset.y += scroll.y * 15;
        }

        // Draw
        //----------------------------------------------------------------------------------

        // Draw Game Items
        //----------------------------------------------------------------------------------
        rl.BeginDrawing();
        defer rl.EndDrawing();

        rl.ClearBackground(rl.LIGHTGRAY);

        rl.BeginMode2D(camera);
        for (env.items) |env_item| {
            if (env_item) |item| rl.DrawRectangleRec(item.rect, item.col);
        }
        const player_rect = rl.Rectangle{
            .x = player.pos.x,
            .y = player.pos.y,
            .width = player.size.x,
            .height = player.size.y,
        };

        rl.DrawTexturePro(
            tex,
            .{
                .x = player_tex_offset.x,
                .y = player_tex_offset.y,
                .width = if (player.dx < 0) -24 else 24,
                .height = 31,
            },
            player_rect,
            .{ .x = 0, .y = 64 },
            0,
            rl.WHITE,
        );

        if (mode == .Debug) rl.DrawRectangleLinesEx(
            .{
                .x = player_rect.x,
                .y = player_rect.y - player_rect.height,
                .width = player.size.x,
                .height = player.size.y,
            },
            2.5,
            rl.GREEN,
        );

        rl.EndMode2D();
        //----------------------------------------------------------------------------------

        // Immediate Mode UI
        //----------------------------------------------------------------------------------

        rl.DrawText(
            switch (mode) {
                .Edit => "Mode: Edit",
                .Debug => "Mode: Debug",
                .Play => "Mode: Play",
            },
            300,
            10,
            30,
            rl.WHITE,
        );

        const tmp_vol_str = std.fmt.allocPrint(alloc, "Music: {d:.0}%0", .{music_volume * 100}) catch ".... We Fucked Up.";
        defer alloc.free(tmp_vol_str);
        @constCast(tmp_vol_str)[tmp_vol_str.len - 1] = 0;
        const vol_str = tmp_vol_str[0 .. tmp_vol_str.len - 1 :0];
        rl.DrawText(
            // later replace muted with an actual muted icon
            if (music_muted) "Music: MUTE" else vol_str,
            100,
            10,
            30,
            rl.RAYWHITE,
        );

        if (mode == .Debug) {
            draw_player_debug_info(alloc, &player, screenWidth, screenHeight);
            draw_env_entities_debug_info(alloc, env.items, screenWidth, screenHeight);
            rl.DrawFPS(20, 20);
        } else if (mode == .Edit) {
            const pos = rl.GetMousePosition();
            if (selected) |sel| {
                const dim: rl.Vector2 = switch (sel) {
                    .Platform => .{ .x = 128, .y = 16 },
                    .Wall => .{ .x = 16, .y = 128 },
                    .Portal => .{ .x = 0, .y = 0 },
                };
                rl.DrawRectangleRec(.{
                    .x = pos.x,
                    .y = pos.y,
                    .width = dim.x,
                    .height = dim.y,
                }, rl.DARKGRAY);
            }
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
        }
        //----------------------------------------------------------------------------------
        //----------------------------------------------------------------------------------
    }
}

fn draw_toolbar(pos: rl.Vector2, w: f32, h: f32, col: rl.Color, tb: *UI, sel: *?ElemID) void {
    rl.DrawRectangleRec(
        .{
            .x = pos.x,
            .y = pos.y,
            .width = w,
            .height = h,
        },
        col,
    );
    var rect: rl.Rectangle = .{ .x = pos.x + 8, .y = pos.y + 8, .width = 32, .height = 32 };
    rl.DrawRectangleRec(rect, rl.DARKGRAY);
    if (tb.button(0, rect)) {
        sel.* = @enumFromInt(0);
    }
    rect.x += 8 + rect.width;
    rl.DrawRectangleRec(rect, rl.PURPLE);
    if (tb.button(1, rect)) {
        sel.* = @enumFromInt(1);
    }
}

//***********************************************************************//
//                                                                       //
//                             *** TODO ***                              //
//                                                                       //
// --------------------------------------------------------------------- //
//  I need to actually implement the drawing of debug info for all the   //
//  items in the level so I can view details properly upon clicking.     //
//                                                                       //
//  This is supposed to be a 'menu' of sorts with a dropdowns for each   //
//  property of the selected item. I should also try to highlight the    //
//  selected item in some way, for sake of visual clarity.               //
//                                                                       //
//  later should duplicate this for other items such as portals or       //
//  living entities.                                                     //
//                                                                       //
//***********************************************************************//
fn draw_env_entities_debug_info(alloc: std.mem.Allocator, env: []?EnvItem, screenWidth: i32, screenHeight: i32) void {
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
        "PLAYER  INFO\n\npos: ({d:.2}, {d:.2})\n\nv-dy: {d:.2}\n\ncan_jump: {any}\n\n",
        .{
            player.pos.x,
            player.pos.y,
            player.dy,
            player.can_jump,
        },
    ) catch "Err";
    defer alloc.free(str);
    @constCast(str)[str.len - 1] = 0;
    const player_info_str = str[0 .. str.len - 1 :0];

    rl.DrawText(player_info_str, screenWidth - 330, 30, 24, rl.WHITE);
}

fn update_player(player: *Player, env: []?EnvItem, delta_time: f32) void {
    if (rl.IsKeyDown(rl.KEY_A)) player.dx = PLAYER_MOVE_SPEED * -1;
    if (rl.IsKeyDown(rl.KEY_D)) player.dx = PLAYER_MOVE_SPEED;
    if (rl.IsKeyDown(rl.KEY_SPACE) and player.can_jump) {
        player.dy = -PLAYER_JUMP_SPEED;
        player.can_jump = false;
    }
    if (rl.IsKeyReleased(rl.KEY_A) and player.dx < 0) {
        player.dx = 0;
    }
    if (rl.IsKeyReleased(rl.KEY_D) and player.dx > 0) {
        player.dx = 0;
    }

    var hit_vertical_obstacle = false;
    var hit_horizontal_obstacle = false;
    for (env) |env_item| {
        if (env_item) |item| switch (item.id) {
            .Platform => {
                if (item.blocking and
                    item.rect.x <= player.pos.x + player.size.x and
                    item.rect.x + item.rect.width >= player.pos.x and
                    item.rect.y >= player.pos.y and
                    item.rect.y <= player.pos.y + player.dy * delta_time)
                {
                    hit_vertical_obstacle = true;
                    player.dy = 0;
                    player.pos.y = item.rect.y;
                }
            },
            .Wall => {
                if (item.blocking and
                    item.rect.x <= player.pos.x + player.size.x and
                    item.rect.x + item.rect.width >= player.pos.x and
                    item.rect.y >= player.pos.y and
                    item.rect.y <= player.pos.y + player.dy * delta_time)
                {
                    hit_vertical_obstacle = true;
                    player.dy = 0;
                    player.pos.y = item.rect.y;
                } else if (item.blocking and
                    item.rect.x <= player.pos.x + player.size.x + player.dx * delta_time and
                    item.rect.x + item.rect.width >= player.pos.x + player.dx * delta_time and
                    item.rect.y + item.rect.height >= player.pos.y - player.size.y and
                    item.rect.y <= player.pos.y + player.dy * delta_time)
                {
                    hit_horizontal_obstacle = true;
                    player.dy -= if (player.dy > 0) (GRAVITY / 2) * delta_time else player.dy * delta_time;
                    player.dx = 0;
                }
            },
            .Portal => {},
        } else std.debug.print("hit a null...\n", .{});
    }

    if (!hit_vertical_obstacle) {
        player.pos.y += player.dy * delta_time;
        player.dy += GRAVITY * delta_time;
        player.can_jump = false;
    } else {
        player.can_jump = true;
    }
    if (!hit_horizontal_obstacle) {
        player.pos.x += player.dx * delta_time;
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

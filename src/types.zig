const rl = @import("rl.zig");
const std = @import("std");

// BEGIN ENUMS
//----------------------------------------------------------------------------------
pub const Color = enum(u32) {
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

pub const ElemID = enum {
    None,
    Platform,
    Wall,
    Portal,
};

pub const Mode = enum {
    Debug,
    Edit,
    Play,
};
//----------------------------------------------------------------------------------

// BEGIN STRUCTS
//----------------------------------------------------------------------------------
pub const EnvItem = struct {
    id: ElemID = .None,
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
pub const Portal = struct {
    pos: rl.Vector2,
    link: ?*Portal,
};

pub const Player = struct {
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
pub const UI = struct {
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

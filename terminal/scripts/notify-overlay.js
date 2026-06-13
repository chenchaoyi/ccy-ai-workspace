// ============================================================================
// notify-overlay.js — zero-dependency clickable macOS notification banner (JXA)
// notify-overlay.js —— 零依赖、可点击的 macOS 通知浮层(JXA)
//
// Used by claude-notify when terminal-notifier is not installed. Shows a small
// dark banner near the top of the main screen; CLICK runs `<gtmux> focus
// <session>` via NSTask (no shell quoting); auto-dismisses after a few seconds.
// claude-notify 在没装 terminal-notifier 时使用。在主屏顶部弹一个深色小横幅;
// 点击经 NSTask 跑 `<gtmux> focus <session>`(无需 shell 引号);几秒后自动消失。
//
// Usage / 用法:
//   osascript -l JavaScript notify-overlay.js <title> <message> <session> <gtmux>
//
// Restore: installed to ~/.local/share/gtmux/notify-overlay.js by install.sh
// 复原:   由 terminal/install.sh 安装到 ~/.local/share/gtmux/notify-overlay.js
// ============================================================================
'use strict';
ObjC.import('Cocoa');

function run(argv) {
  var title   = (argv[0] != null) ? String(argv[0]) : 'Claude Code';
  var message = (argv[1] != null) ? String(argv[1]) : '';
  var session = (argv[2] != null) ? String(argv[2]) : '';
  var gtmux   = (argv[3] != null) ? String(argv[3]) : '';

  var app = $.NSApplication.sharedApplication;
  // Accessory: no Dock icon, no menu bar; still shows windows & gets clicks.
  app.setActivationPolicy($.NSApplicationActivationPolicyAccessory);

  // ── Geometry: top-center banner on the main screen ──
  var W = 380, H = 88, topMargin = 28;
  var sf = $.NSScreen.mainScreen.frame;
  var x = sf.origin.x + (sf.size.width - W) / 2;
  var y = sf.origin.y + sf.size.height - H - topMargin;
  var rect = $.NSMakeRect(x, y, W, H);

  var win = $.NSWindow.alloc.initWithContentRectStyleMaskBackingDefer(
    rect, 0 /* Borderless */, 2 /* Buffered */, false);
  win.setLevel(25);                 // NSStatusWindowLevel — above normal windows
  win.setOpaque(false);
  win.setBackgroundColor($.NSColor.clearColor);
  win.setHasShadow(true);
  // Float across all Spaces, don't disturb the active app's window order.
  win.setCollectionBehavior((1 << 0) | (1 << 4)); // CanJoinAllSpaces | Stationary

  // ── Rounded dark background ──
  var bg = $.NSView.alloc.initWithFrame($.NSMakeRect(0, 0, W, H));
  bg.setWantsLayer(true);
  bg.layer.setBackgroundColor(
    $.NSColor.colorWithCalibratedRedGreenBlueAlpha(0.12, 0.12, 0.17, 0.97).CGColor);
  bg.layer.setCornerRadius(14);
  win.setContentView(bg);

  // ── Title (bold) + message ──
  function mklabel(frame, str, color, size, bold) {
    var l = $.NSTextField.alloc.initWithFrame(frame);
    l.setStringValue(str);
    l.setBezeled(false); l.setEditable(false); l.setSelectable(false);
    l.setDrawsBackground(false);
    l.setTextColor(color);
    l.setFont(bold ? $.NSFont.boldSystemFontOfSize(size) : $.NSFont.systemFontOfSize(size));
    l.cell.setLineBreakMode($.NSLineBreakByTruncatingTail);
    return l;
  }
  bg.addSubview(mklabel($.NSMakeRect(18, H - 36, W - 36, 22), title,
    $.NSColor.whiteColor, 14, true));
  bg.addSubview(mklabel($.NSMakeRect(18, 12, W - 36, 34), message,
    $.NSColor.colorWithCalibratedRedGreenBlueAlpha(0.82, 0.84, 0.92, 1.0), 12, false));

  // ── Click handler: run `gtmux focus <session>` then quit ──
  if (!$.ClickCatcher) {
    ObjC.registerSubclass({
      name: 'ClickCatcher',
      superclass: 'NSView',
      properties: { gtmux: 'id', session: 'id' },
      methods: {
        'mouseDown:': {
          types: ['void', ['id']],
          implementation: function(_ev) {
            var s = ObjC.unwrap(this.session);
            var g = ObjC.unwrap(this.gtmux);
            if (s && g) {
              var t = $.NSTask.alloc.init;
              t.setLaunchPath(g);
              t.setArguments(['focus', s]);
              try { t.launch; } catch (e) {}
            }
            $.NSApp.terminate(this);
          }
        }
      }
    });
  }
  var catcher = $.ClickCatcher.alloc.initWithFrame($.NSMakeRect(0, 0, W, H));
  if (session && gtmux) { catcher.session = $(session); catcher.gtmux = $(gtmux); }
  bg.addSubview(catcher);

  win.makeKeyAndOrderFront(null);

  // ── Auto-dismiss: pump the run loop so clicks register, then quit ──
  var deadline = $.NSDate.dateWithTimeIntervalSinceNow(6);
  $.NSRunLoop.currentRunLoop.runUntilDate(deadline);
  $.NSApp.terminate(null);
}

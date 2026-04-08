///|
fn main {
  @lepus.Window::new(
    title="Lepus Custom Window",
    width=980,
    height=620,
    frameless=false,
    transparent=true,
    html=(
      #|<!doctype html>
      #|<html>
      #|  <head>
      #|    <meta charset="utf-8" />
      #|    <meta name="viewport" content="width=device-width, initial-scale=1" />
      #|    <style>
      #|      :root {
      #|        color-scheme: light;
      #|        --bg: #f2f4f8;
      #|        --panel: #ffffff;
      #|        --ink: #151a22;
      #|        --muted: #6a7381;
      #|        --line: #d7dde8;
      #|        --accent: #1769ff;
      #|      }
      #|      * { box-sizing: border-box; }
      #|      body {
      #|        margin: 0;
      #|        font-family: "SF Pro Text", "PingFang SC", "Noto Sans SC", sans-serif;
      #|        background: radial-gradient(1200px 520px at 20% -10%, #dbe7ff 0%, var(--bg) 48%);
      #|        color: var(--ink);
      #|      }
      #|      .window {
      #|        border: 1px solid var(--line);
      #|        border-radius: 14px;
      #|        overflow: hidden;
      #|        background: var(--panel);
      #|      }
      #|      .titlebar {
      #|        height: 44px;
      #|        display: flex;
      #|        align-items: center;
      #|        justify-content: space-between;
      #|        padding: 0 10px 0 14px;
      #|        border-bottom: 1px solid var(--line);
      #|        background: linear-gradient(180deg, #fdfefe, #f6f8fb);
      #|      }
      #|      .title {
      #|        font-size: 13px;
      #|        font-weight: 600;
      #|      }
      #|      .actions {
      #|        display: flex;
      #|        gap: 8px;
      #|      }
      #|      .button {
      #|        border: 1px solid var(--line);
      #|        border-radius: 8px;
      #|        height: 28px;
      #|        padding: 0 11px;
      #|        background: #fff;
      #|        color: var(--muted);
      #|      }
      #|      .button:hover {
      #|        border-color: #bcc7da;
      #|      }
      #|      .button.primary {
      #|        color: white;
      #|        background: var(--accent);
      #|        border-color: var(--accent);
      #|      }
      #|      .content {
      #|        padding: 26px;
      #|      }
      #|      h1 {
      #|        margin: 0 0 8px 0;
      #|        font-size: 24px;
      #|      }
      #|      p {
      #|        margin: 0;
      #|        color: var(--muted);
      #|        line-height: 1.6;
      #|      }
      #|      code {
      #|        padding: 2px 7px;
      #|        border-radius: 6px;
      #|        border: 1px solid var(--line);
      #|        background: #f8fafc;
      #|      }
      #|    </style>
      #|  </head>
      #|  <body>
      #|    <div class="window">
      #|      <div class="titlebar lepus-drag">
      #|        <div class="title">Lepus Custom Window</div>
      #|        <div class="actions lepus-no-drag">
      #|          <button class="button primary" onclick="window.close()">Close</button>
      #|        </div>
      #|      </div>
      #|      <div class="content">
      #|        <h1>Electron-style custom title bar</h1>
      #|        <p>
      #|          This window is started with <code>frameless=true</code>. Drag the top bar area
      #|          marked by <code>.lepus-drag</code>; interactive controls stay clickable with
      #|          <code>.lepus-no-drag</code>.
      #|        </p>
      #|      </div>
      #|    </div>
      #|  </body>
      #|</html>,
    ),
  ).run()
}

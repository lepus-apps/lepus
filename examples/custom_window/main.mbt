///|
fn main {
  @lepus.Window::new(
    title="Lepus Custom Window",
    width=980,
    height=620,
    frameless=true,
    transparent=true,
    // devtools=true,
    source=@lepus.Source::html(
      (
        #|<!doctype html>
        #|<html lang="en">
        #|  <head>
        #|    <meta charset="utf-8" />
        #|    <meta name="viewport" content="width=device-width, initial-scale=1" />
        #|    <style>
        #|      :root {
        #|        --bg: #f5f7fa;
        #|        --panel: #ffffff;
        #|        --text: #2c3e50;
        #|        --muted: #7f8c8d;
        #|        --accent: #1769ff;
        #|        --accent-hover: #0d52d4;
        #|        --border: #e1e4e8;
        #|        --shadow: 0 10px 30px rgba(0, 0, 0, 0.08);
        #|      }
        #|
        #|      * { box-sizing: border-box; margin: 0; padding: 0; }
        #|
        #|      body {
        #|        height: 100vh;
        #|        width: 100vw;
        #|        font-family: "SF Pro Text", "PingFang SC", "Noto Sans SC", -apple-system, BlinkMacSystemFont, sans-serif;
        #|        background: var(--bg);
        #|        color: var(--text);
        #|        display: flex;
        #|        align-items: center;
        #|        justify-content: center;
        #|        overflow: hidden;
        #|      }
        #|
        #|      .window {
        #|        width: 100vw;
        #|        height: 100vh; /* Fills most of the height */
        #|        background: var(--panel);
        #|        border-radius: 16px;
        #|        box-shadow: var(--shadow);
        #|        display: flex;
        #|        flex-direction: column;
        #|        overflow: hidden;
        #|        border: 1px solid var(--border);
        #|      }
        #|
        #|      .titlebar {
        #|        height: 50px;
        #|        display: flex;
        #|        align-items: center;
        #|        justify-content: space-between;
        #|        padding: 0 20px;
        #|        background: #ffffff;
        #|        border-bottom: 1px solid var(--border);
        #|        user-select: none;
        #|        -webkit-user-select: none;
        #|        cursor: default;
        #|      }
        #|
        #|      .title {
        #|        font-size: 14px;
        #|        font-weight: 600;
        #|        color: var(--text);
        #|        letter-spacing: 0.5px;
        #|      }
        #|
        #|      .actions {
        #|        display: flex;
        #|        gap: 10px;
        #|      }
        #|
        #|      .button {
        #|        border: none;
        #|        border-radius: 6px;
        #|        height: 32px;
        #|        padding: 0 16px;
        #|        font-size: 13px;
        #|        font-weight: 500;
        #|        cursor: pointer;
        #|        transition: all 0.2s ease;
        #|        background: transparent;
        #|        color: var(--muted);
        #|      }
        #|
        #|      .button:hover {
        #|        background: #f0f2f5;
        #|        color: var(--text);
        #|      }
        #|
        #|      .button.primary {
        #|        background: var(--accent);
        #|        color: white;
        #|      }
        #|
        #|      .button.primary:hover {
        #|        background: var(--accent-hover);
        #|        transform: translateY(-1px);
        #|        box-shadow: 0 4px 12px rgba(23, 105, 255, 0.3);
        #|      }
        #|
        #|      .content {
        #|        flex: 1;
        #|        padding: 40px;
        #|        display: flex;
        #|        flex-direction: column;
        #|        justify-content: center;
        #|        align-items: center;
        #|        text-align: center;
        #|        overflow-y: auto;
        #|      }
        #|
        #|      h1 {
        #|        font-size: 32px;
        #|        font-weight: 700;
        #|        margin-bottom: 16px;
        #|        color: var(--text);
        #|      }
        #|
        #|      p {
        #|        font-size: 16px;
        #|        line-height: 1.6;
        #|        color: var(--muted);
        #|        max-width: 600px;
        #|      }
        #|
        #|      code {
        #|        padding: 4px 10px;
        #|        border-radius: 6px;
        #|        background: #f0f2f5;
        #|        color: #d63384;
        #|        font-family: "SF Mono", "Consolas", monospace;
        #|        font-size: 0.9em;
        #|        border: 1px solid #e1e4e8;
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
        #|        <h1>Custom Title Bar</h1>
        #|        <p> 
        #|          This window is started with <code>frameless=true</code>. 
        #|          Drag the top bar area marked by <code>.lepus-drag</code>; 
        #|          interactive controls stay clickable with <code>.lepus-no-drag</code>.
        #|        </p>
        #|      </div>
        #|    </div>
        #|  </body>
        #|</html>
      ),
    ),
  ).run()
}

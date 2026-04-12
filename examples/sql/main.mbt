///|
async fn main {
  @lepus.Window::new(
    title="Lepus Sql Plugin",
    source=@lepus_plugin_support.example_html(
      "sql",
      "Sql Plugin Example",
      content=(
        #|<input id="db" value="/tmp/lepus.db" style="width:100%;padding:10px;border-radius:10px;border:1px solid #ccd7e2;" />
        #|<textarea id="sql" rows="6" style="width:100%;margin-top:10px;padding:10px;border-radius:10px;border:1px solid #ccd7e2;">select 1 as n;</textarea>
        #|<div style="display:flex;gap:10px;margin-top:10px;flex-wrap:wrap;">
        #|  <button onclick="load()">load</button>
        #|  <button onclick="execute()">execute</button>
        #|  <button onclick="selectRows()">select</button>
        #|  <button onclick="closeConn()">close</button>
        #|</div>
        #|<pre id="out">ready</pre>
        #|<script>
        #|const out = document.getElementById("out");
        #|const db = () => document.getElementById("db").value;
        #|const sql = () => document.getElementById("sql").value;
        #|let connId = null;
        #|async function load(){ const r = await window.lepusApi.sql.load({ db: db() }); connId = r.id; out.textContent = JSON.stringify(r, null, 2); }
        #|async function execute(){ out.textContent = JSON.stringify(await window.lepusApi.sql.execute({ conn_id: connId ?? -1, sql: sql() }), null, 2); }
        #|async function selectRows(){ out.textContent = JSON.stringify(await window.lepusApi.sql.select({ conn_id: connId ?? -1, sql: sql() }), null, 2); }
        #|async function closeConn(){ out.textContent = JSON.stringify(await window.lepusApi.sql.close(connId ?? -1), null, 2); connId = null; }
        #|</script>
      ),
    ),
    plugins=[@lepus_plugin_sql.plugin()],
  ).run()
}

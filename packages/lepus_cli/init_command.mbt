///|
pub fn run_init(config : InitConfig) -> Int {
  println("init is not implemented yet")
  println("project_name=" + config.project_name.unwrap_or(""))
  println("template=" + config.template + ", frontend=" + config.frontend)
  println("cwd=" + config.cwd + ", force=" + config.force.to_string())
  0
}

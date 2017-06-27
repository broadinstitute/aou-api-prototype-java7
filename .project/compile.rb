require_relative "common/common"

def compile()
  c = Common.new
  c.sf.maybe_start_file_syncing
  env = c.load_env
  cname = "#{env.namespace}-compiler"
  at_exit { c.run_inline %W{docker rm -f #{cname}} }
  c.run_inline %W{
    docker run --name #{cname} -it
      --user root
      -v gradle-cache:/root/.gradle
      -w /w
  } + c.sf.get_volume_mounts + %W{
    gradle:jdk7-alpine
    gradle --no-daemon --continuous compileJava
  }
end

def devserver()
  c = Common.new
  env = c.load_env
  cname = "#{env.namespace}-devserver"
  c.status "Ensuring compilation has started..."
  c.pipe(%W{docker ps --filter name=aourpapi-compiler --quiet}, %W{grep .}) # fails if none found
  c.status "Creating devserver container..."
  c.run_inline %W{docker run --rm -w /w} + c.sf.get_volume_mounts + %W{
      google/cloud-sdk
      mkdir -p build
  }
  c.run_inline %W{
    docker create --name #{cname} -it
      -p 8080:8080
      -w /w
    } + c.sf.get_volume_mounts + %W{
      google/cloud-sdk
      dev_appserver.py --host 0.0.0.0 build
  }
  at_exit { c.run_inline %W{docker rm -f #{cname}} }
  c.run_inline %W{docker cp src/main/deploy/app.yaml #{cname}:/w/build}
  c.run_inline %W{docker cp src/main/webapp/WEB-INF #{cname}:/w/build}
  c.run_inline %W{docker start -a #{cname}}
end

Common.register_command({
  :invocation => "start-compiler",
  :description => "Starts continuous compilation.",
  :fn => Proc.new { |*args| compile(*args) }
})

Common.register_command({
  :invocation => "start-devserver",
  :description => "Starts development server.",
  :fn => Proc.new { |*args| devserver(*args) }
})

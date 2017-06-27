require_relative "common/common"

$working_dir = "/home/gradle"

def assemble()
  c = Common.new
  if Dir.exist?("target")
    c.error "Removing existing target..."
    c.run_inline %W{rm -rf target}
  end
  c.status "Creating compiler container..."
  env = c.load_env
  cname = "#{env.namespace}-compiler"
  c.run_inline %W{
    docker create --name #{cname}
      -v gradle-cache:/home/gradle/.gradle
      gradle:jdk7-alpine
      gradle --no-daemon assemble
  }
  at_exit { c.run_inline %W{docker rm -f #{cname}} }
  env.source_file_paths.each do |src_path|
    c.pipe(
      %W{tar -c #{src_path}},
      %W{docker cp - #{cname}:#{$working_dir}}
    )
  end
  c.status "Compiling..."
  c.run_inline %W{docker start -a #{cname}}
  c.status "Copying artifacts..."
  gradle_target = "build/exploded-allofus-researcher-portal-api"
  c.run_inline %W{docker cp #{cname}:#{$working_dir}/#{gradle_target} target}
end

def deploy()
  assemble
  c = Common.new
  c.status "Deploying to App Engine..."
  c.run_inline %W{cp src/main/deploy/app.yaml target}
  Dir.chdir("target") do
    c.run_inline %W{gcloud app deploy --project allofus-164617 --quiet}
  end
end

# Common.register_command({
#   :invocation => "assemble",
#   :description => "Compiles and assembles the WAR using Gradle.",
#   :fn => Proc.new { |*args| assemble(*args) }
# })

Common.register_command({
  :invocation => "deploy",
  :description => "Deploys to Google App Engine.",
  :fn => Proc.new { |*args| deploy(*args) }
})

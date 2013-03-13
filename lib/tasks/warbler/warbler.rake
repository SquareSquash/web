if RUBY_PLATFORM == "java"
  desc "Build a WAR file of project using Warbler"
  task :war => "assets:precompile:all" do
    require 'warbler'
    Warbler::Task.new(:warble)
    Rake::Task["warble"].invoke
  end
end

if Squash::Configuration.concurrency.background_runner == 'Resque'
  Bundler.require(:resque)
  rails_root = ENV['RAILS_ROOT'] || File.dirname(__FILE__) + '/../..'
  rails_env = ENV['RAILS_ENV'] || 'development'

  config = YAML.load_file(rails_root.to_s + '/config/environments/common/concurrency.yml')
  Resque.redis = config['resque'][rails_env]
end

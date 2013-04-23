require 'configoro'
Configoro.initialize

filename = Squash::Configuration.concurrency.background_runner.underscore + '.rake'
file     = Rails.root.join('lib', 'background_runner', 'tasks', filename)

load(file) if File.exist?(file)

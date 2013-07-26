# Copyright 2013 Square Inc.
#
#    Licensed under the Apache License, Version 2.0 (the "License");
#    you may not use this file except in compliance with the License.
#    You may obtain a copy of the License at
#
#        http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS,
#    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#    See the License for the specific language governing permissions and
#    limitations under the License.

paths = Gem.find_files('configoro/simple')
if paths.empty?
  puts "NOTE: Because Configoro is not installed, only required gems will be",
       "installed. Re-run 'bundle' again to install additional gems."
  # not necessary; make conditionally a noop
  def conditionally(*) end
  def conditionally_not(*_, &block) $_squash_environments.each { |g| group g.to_sym, &block } end
else
  paths.each { |p| require p }

  rails_root = ENV['RAILS_ROOT'] || File.join(File.dirname(__FILE__), '..')
  Configoro.paths << File.join(rails_root, 'config', 'environments')

  $_squash_environments = Dir.glob(File.join(rails_root, 'config', 'environments', '*.rb')).map { |f| File.basename f, '.rb' }

  def load_groups(configuration_path, values)
    configuration_path = configuration_path.split('.')

    $_squash_environments.select do |env|
      settings = Configoro.load_environment(env)
      values.include?(traverse_hash(settings, *configuration_path))
    end
  end

  def traverse_hash(hsh, *keys)
    if keys.size == 1
      hsh[keys.first]
    else
      traverse_hash hsh[keys.shift], *keys
    end
  end

  def conditionally(configuration_path, *values, &block)
    groups = load_groups(configuration_path, values)
    groups.each { |g| group g.to_sym, &block }
  end
end

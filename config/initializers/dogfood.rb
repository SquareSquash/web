# Copyright 2014 Square Inc.
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

# Configoro-Squash bridge. This file loads the Squash client configuration
# stored in the dogfood.yml files and uses it to configure Squash.

Squash::Ruby.configure Squash::Configuration.dogfood

# Auto-configure development dogfood

if defined?(Rails::Server)
  run_server = begin
    Rails.env.development? && (project = Project.find_from_slug('squash'))
  rescue ActiveRecord::StatementInvalid
    false
  end

  if run_server
    # Create a thread that listens on port 3001 and just proxies requests back
    # to port 3000. This allows Squash to send notifications to itself during
    # the course of processing a request without having to be concurrent.

    #TODO this is a pretty hacky way of discovering the port
    $own_port = ARGV.join(' ').scan(/(?:-p|--port)(?:=|\s+)(\d+)/).first.try!(:first).try!(:to_i) || 3000
    $self_notify_port = $own_port + 1

    Thread.new do
      server = TCPServer.new($self_notify_port)
      loop do
        Thread.start(server.accept) do |from|
          request = Array.new
          while (line = from.gets).present?
            request << line.chomp
          end
          length = request.detect { |l| l.start_with?('Content-Length: ') }.try!(:gsub, /[^0-9]/, '').try!(:to_i)
          if length && length > 0
            request << ''
            request << from.read(length)
          end

          if request.first.starts_with?('OPTIONS')
            from.puts "HTTP/1.1 200 OK"
            from.puts "Date: #{Time.now.to_s}"
            from.puts "Allow: OPTIONS, GET, POST"
            from.puts "Access-Control-Allow-Origin: http://localhost:#{$own_port}"
            from.puts "Access-Control-Allow-Methods: POST, GET, OPTIONS"
            from.puts "Access-Control-Allow-Headers: origin, content-type, x-category"
          else
            from.puts "HTTP/1.1 200 OK"
            from.puts "Date: #{Time.now.to_s}"
            from.puts "Access-Control-Allow-Origin: http://localhost:#{$own_port}"
            from.puts "Access-Control-Allow-Methods: POST, GET, OPTIONS"
            from.puts "Access-Control-Allow-Headers: origin, content-type, x-category"
          end
          from.puts
          from.close

          unless request.first.starts_with?('OPTIONS')
            to = TCPSocket.new('localhost', $own_port)
            request.each { |line| to.puts line }
            to.close
          end
        end
      end
    end

    puts "Running self-notify proxy on port #{$self_notify_port}"

    # Set configuration options
    Squash::Ruby.configure api_key:  project.api_key,
                           api_host: "http://localhost:#{$self_notify_port}",
                           disabled: false
  elsif Rails.env.development?
    puts "Note: Add a 'Squash' project in development to enable self-notification"
  end
end

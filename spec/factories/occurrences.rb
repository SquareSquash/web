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

FactoryGirl.define do
  factory :occurrence do
    association :bug
    occurred_at { Time.now }
  end

  factory :rails_occurrence, parent: :occurrence do
    association :bug, class_name: 'ActionController::RedirectBackError'

    client 'rails'

    message 'No HTTP_REFERRER was set in the request to this action, so redirect_to :back could not be called successfully. If this is a test, make sure to specify request.env["HTTP_REFERRER"].'
    backtraces [{"name"      => "Thread 0",
                 "faulted"   => true,
                 "backtrace" => [{"file"   => "/usr/bin/gist",
                                  "line"   => 313,
                                  "symbol" => "<main>"},
                                 {"file"   => "/usr/bin/gist",
                                  "line"   => 171,
                                  "symbol" => "execute"},
                                 {"file"   => "/usr/bin/gist",
                                  "line"   => 197,
                                  "symbol" => "write"},
                                 {"file"   => "/usr/lib/ruby/1.9.1/net/http.rb",
                                  "line"   => 626,
                                  "symbol" => "start"},
                                 {"file"   => "/usr/lib/ruby/1.9.1/net/http.rb",
                                  "line"   => 637,
                                  "symbol" => "do_start"},
                                 {"file"   => "/usr/lib/ruby/1.9.1/net/http.rb",
                                  "line"   => 644,
                                  "symbol" => "connect"},
                                 {"file"   => "/usr/lib/ruby/1.9.1/timeout.rb",
                                  "line"   => 87,
                                  "symbol" => "timeout"},
                                 {"file"   => "/usr/lib/ruby/1.9.1/timeout.rb",
                                  "line"   => 44,
                                  "symbol" => "timeout"},
                                 {"file"   => "/usr/lib/ruby/1.9.1/net/http.rb",
                                  "line"   => 644,
                                  "symbol" => "block in connect"},
                                 {"file"   => "/usr/lib/ruby/1.9.1/net/http.rb",
                                  "line"   => 644,
                                  "symbol" => "open"},
                                 {"file"   => "/usr/lib/ruby/1.9.1/net/http.rb",
                                  "line"   => 644,
                                  "symbol" => "initialize"}]}]
    revision 'adf85a0c645e8b262ed7cdb347ff0b32a2f860dc'

    request_method 'POST'
    schema 'https'
    host 'squareup.com'
    port 443
    path '/broken_controller/broken_action'
    query '?foo[bar]=1&foo[baz]=2'
    headers(
      'Content-Length'            => '20570',
      'Content-Type'              => 'text/html; charset=utf-8',
      'Connection'                => 'close',
      'Status'                    => '200',
      'Etag'                      => "5897cf6b991135493aba558481f65f4e",
      'X-Frame-Options'           => 'DENY',
      'Set-Cookie'                => "visited=; path=/, _session=foobarbaz--bazbarfoo; path=/; secure; HttpOnly",
      'Cache-Control'             => 'private, max-age=0, must-revalidate',
      'X-Square'                  => 'S=app05.mtv.squareup.com',
      'Strict-Transport-Security' => 'max-age=1296000'
    )

    root '/var/www/apps/web/releases/20120221024555'
    params(
      'controller' => 'home',
      'action'     => 'index',
      'foo'        => {'bar' => '1', 'baz' => '2'}
    )
    session('user_id' => '12345')
    flash('alert' => "Couldn't find that user.")

    hostname 'app012.cloud.local'
    pid 20104
    env_vars(
      "TERM_PROGRAM"         => "Apple_Terminal",
      "GEM_HOME"             => "/Users/tim/.rvm/gems/ree-1.8.7-2011.12",
      "SHELL"                => "/bin/bash",
      "TERM"                 => "xterm-256color",
      "TMPDIR"               => "/var/folders/71/cmpmcwg972b2mfvy98hz71kw00018q/T/",
      "TERM_PROGRAM_VERSION" => "303",
      "TERM_SESSION_ID"      => "F73E4DF7-5824-4E20-A0FA-1BC3698A42DF",
      "USER"                 => "tim",
      "COMMAND_MODE"         => "unix2003",
      "SSH_AUTH_SOCK"        => "/tmp/launch-0W3t1G/Listeners",
      "PATH"                 => "/Users/tim/.rvm/gems/ree-1.8.7-2011.12/bin:/Users/tim/.rvm/gems/ree-1.8.7-2011.12@global/bin:/Users/tim/.rvm/rubies/ree-1.8.7-2011.12/bin:/Users/tim/.rvm/gems/ree-1.8.7-2011.12/bin:/Users/tim/.rvm/gems/ree-1.8.7-2011.12@global/bin:/Users/tim/.rvm/rubies/ree-1.8.7-2011.12/bin:/Users/tim/.rvm/bin:/Users/tim/Development/topsoil/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/usr/X11/bin:/usr/local/git/bin",
      "PWD"                  => "/Users/tim/Development/web",
      "EDITOR"               => "vim",
      "LANG"                 => "en_US.UTF-8",
      "HISTCONTROL"          => "ignoreboth",
      "HOME"                 => "/Users/tim",
      "SHLVL"                => "1",
      "LOGNAME"              => "tim",
      "GEM_PATH"             => "/Users/tim/.rvm/gems/ree-1.8.7-2011.12:/Users/tim/.rvm/gems/ree-1.8.7-2011.12@global",
      "DISPLAY"              => "/tmp/launch-GWtyIN/org.x:0",
      "RUBY_VERSION"         => "ree-1.8.7-2011.12",
      "_"                    => "/Users/tim/.rvm/rubies/ree-1.8.7-2011.12/bin/irb"
    )
  end

  factory :legacy_occurrence, parent: :rails_occurrence do
    [["Thread 0", true, [
        ['/usr/bin/gist', 313, '<main>'],
        ['/usr/bin/gist', 171, 'execute'],
        ['/usr/bin/gist', 197, 'write'],
        ['/usr/lib/ruby/1.9.1/net/http.rb', 626, 'start'],
        ['/usr/lib/ruby/1.9.1/net/http.rb', 637, 'do_start'],
        ['/usr/lib/ruby/1.9.1/net/http.rb', 644, 'connect'],
        ['/usr/lib/ruby/1.9.1/timeout.rb', 87, 'timeout'],
        ['/usr/lib/ruby/1.9.1/timeout.rb', 44, 'timeout'],
        ['/usr/lib/ruby/1.9.1/net/http.rb', 644, 'block in connect'],
        ['/usr/lib/ruby/1.9.1/net/http.rb', 644, 'open'],
        ['/usr/lib/ruby/1.9.1/net/http.rb', 644, 'initialize']
    ]]]
  end
end

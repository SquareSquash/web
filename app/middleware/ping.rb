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

# Rack middleware that responds to a /_status ping before Rack::SSL gets a
# chance to return a redirect to the HTTPS site.

class Ping
  # @private
  def initialize(app)
    @app = app
  end

  # @private
  def call(env)
    if env['ORIGINAL_FULLPATH'] == '/_status'
      [200, {}, ['{"status":"OK"}']]
    else
      @app.call env
    end
  end
end

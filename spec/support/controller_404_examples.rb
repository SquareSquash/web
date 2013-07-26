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

shared_examples_for "action that 404s at appropriate times" do |method, action, params='{}'|
  it "should only allow projects that exist" do
    send method, action, eval(params).merge(project_id: 'not-found')
    response.status.should eql(404)
  end

  it "should only allow environments that actually exist within the project" do
    send method, action, eval(params).merge(environment_id: 'not-found')
    response.status.should eql(404)
  end
end

shared_examples_for "singleton action that 404s at appropriate times" do |method, action, params='{}'|
  it "should only find bugs within the current environment" do
    send method, action, eval(params).merge(id: 'not-found')
    response.status.should eql(404)
  end
end

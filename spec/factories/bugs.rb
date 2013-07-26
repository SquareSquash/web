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
  factory :bug do
    association :environment

    class_name "ArgumentError"
    message_template "wrong number of parameters (1 for 0)"
    client 'rails'

    revision '8f29160c367cc3e73c112e34de0ee48c4c323ff7'
    file "app/controllers/broken_controller.rb"
    line 123
  end
end

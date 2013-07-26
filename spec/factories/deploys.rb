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
  factory :deploy do
    association :environment
    revision '2dc20c984283bede1f45863b8f3b4dd9b5b554cc'
    deployed_at { Time.now }
  end

  factory :release, class: 'Deploy' do
    association :environment
    revision '2dc20c984283bede1f45863b8f3b4dd9b5b554cc'
    version '1.2.3'
    sequence :build, &:to_s
    deployed_at { Time.now }
  end
end

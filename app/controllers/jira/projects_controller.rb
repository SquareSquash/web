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

# Controller that loads JIRA projects.

class Jira::ProjectsController < ApplicationController
  skip_before_filter :login_required
  respond_to :json

  # Returns a list of JIRA projects.
  #
  # * `GET /jira/projects`

  def index
    @projects = Service::JIRA.projects
    respond_with(@projects) do |format|
      format.json { render json: @projects.to_a.sort_by(&:name).map(&:attrs).to_json }
    end
  end
end

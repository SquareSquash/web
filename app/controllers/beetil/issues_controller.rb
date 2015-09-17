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

# Controller that loads Beetil issues.

class Beetil::IssuesController < ApplicationController
  skip_before_filter :login_required
  before_filter :find_issue
  respond_to :json

  # Returns information about a Beetil issue.
  #
  # * `GET /beetil/issues/:id`
  #
  # Path Parameters
  # ---------------
  #
  # |      |                                        |
  # |:-----|----------------------------------------|
  # | `id` | The Beetil number (e.g., "50000"). |

  def show
    respond_with(@issue) do |format|
      format.json { render json: @issue.to_json }
    end
  end

  private

  def find_issue
    @issue = Service::Beetil.find_incident(params[:id]) || raise(ActiveRecord::RecordNotFound)
  end
end

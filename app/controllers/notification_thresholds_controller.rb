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

class NotificationThresholdsController < ApplicationController
  before_filter :find_project
  before_filter :find_environment
  before_filter :find_bug
  before_filter :membership_required
  respond_to :json, except: :destroy

  def create
    @notification_threshold = current_user.notification_thresholds.where(bug_id: @bug.id).create_or_update(params[:notification_threshold], as: :user)
    respond_with @notification_threshold, location: project_environment_bug_url(@project, @environment, @bug)
  end

  def update
    @notification_threshold = current_user.notification_thresholds.where(bug_id: @bug.id).create_or_update(params[:notification_threshold], as: :user)
    respond_with @notification_threshold, location: project_environment_bug_url(@project, @environment, @bug)
  end

  def destroy
    current_user.notification_thresholds.where(bug_id: @bug.id).delete_all
    respond_to do |format|
      format.json { head :no_content }
      format.html { redirect_to project_environment_bug_url(@project, @environment, @bug, anchor: 'notifications') }
    end
  end
end

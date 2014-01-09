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

# Singleton resource controller that works with a User's {NotificationThreshold}
# for a Bug.

class NotificationThresholdsController < ApplicationController
  before_filter :find_project
  before_filter :find_environment
  before_filter :find_bug
  before_filter :membership_required
  respond_to :json, except: :destroy

  # Creates a new NotificationThreshold from the given attributes.
  #
  # Routes
  # ------
  #
  # * `POST /projects/:project_id/environments/:environment_id/bugs/:bug_id/notification_threshold`
  #
  # Path Parameters
  # ---------------
  #
  # |                   |                                                                                                        |
  # |:------------------|:-------------------------------------------------------------------------------------------------------|
  # | `:project_id`     | The slug of a {Project}.                                                                               |
  # | `:environment_id` | The name of an {Environment} within that Project.                                                      |
  # | `:bug_id`         | The number of a {Bug} within that Environment. The NotificationThreshold will be created for this Bug. |
  #
  # Body Parameters
  # ---------------
  #
  # |                          |                                                                  |
  # |:-------------------------|:-----------------------------------------------------------------|
  # | `notification_threshold` | A parameterized hash of NotificationThreshold fields and values. |

  def create
    @notification_threshold = current_user.notification_thresholds.where(bug_id: @bug.id).create_or_update(notification_threshold_params)
    respond_with @notification_threshold, location: project_environment_bug_url(@project, @environment, @bug)
  end

  # Updates a NotificationThreshold with the given attributes.
  #
  # Routes
  # ------
  #
  # * `PATCH /projects/:project_id/environments/:environment_id/bugs/:bug_id/notification_threshold`
  #
  # Path Parameters
  # ---------------
  #
  # |                   |                                                   |
  # |:------------------|:--------------------------------------------------|
  # | `:project_id`     | The slug of a {Project}.                          |
  # | `:environment_id` | The name of an {Environment} within that Project. |
  # | `:bug_id`         | The number of a {Bug} within that Environment.    |
  #
  # Body Parameters
  # ---------------
  #
  # |                          |                                                                  |
  # |:-------------------------|:-----------------------------------------------------------------|
  # | `notification_threshold` | A parameterized hash of NotificationThreshold fields and values. |

  def update
    @notification_threshold = current_user.notification_thresholds.where(bug_id: @bug.id).create_or_update(notification_threshold_params)
    respond_with @notification_threshold, location: project_environment_bug_url(@project, @environment, @bug)
  end

  # Deletes a NotificationThreshold.
  #
  # Routes
  # ------
  #
  # * `DELETE /projects/:project_id/environments/:environment_id/bugs/:bug_id/notification_threshold`
  #
  # Path Parameters
  # ---------------
  #
  # |                   |                                                   |
  # |:------------------|:--------------------------------------------------|
  # | `:project_id`     | The slug of a {Project}.                          |
  # | `:environment_id` | The name of an {Environment} within that Project. |
  # | `:bug_id`         | The number of a {Bug} within that Environment.    |

  def destroy
    current_user.notification_thresholds.where(bug_id: @bug.id).delete_all
    respond_to do |format|
      format.json { head :no_content }
      format.html { redirect_to project_environment_bug_url(@project, @environment, @bug, anchor: 'notifications') }
    end
  end

  private

  def notification_threshold_params
    params.require(:notification_threshold).permit(:threshold, :period)
  end
end

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

# Controller for working with a {Bug}'s {Comment Comments}. Only the Comment
# creator or administrators can edit or a remove a Comment.
#
# Common
# ======
#
# Path Parameters
# ---------------
#
# |                  |                          |
# |:-----------------|:-------------------------|
# | `project_id`     | The {Project}'s slug.    |
# | `environment_id` | The {Environment} name.  |
# | `bug_id`         | The Bug number (not ID). |

class CommentsController < ApplicationController
  before_filter :find_project
  before_filter :find_environment
  before_filter :find_bug
  before_filter :find_comment, except: [:index, :create]
  before_filter :must_be_creator_or_admin, except: [:index, :create]

  respond_to :json

  # Returns a infinitely scrollable list of Comments.
  #
  # Routes
  # ------
  #
  # * `GET /projects/:project_id/environments/:environment_id/bugs/:bug_id/comments.json`
  #
  # Query Parameters
  # ----------------
  #
  # |        |                                                                                                               |
  # |:-------|:--------------------------------------------------------------------------------------------------------------|
  # | `last` | The number of the last Comment of the previous page; used to determine the start of the next page (optional). |

  def index
    @comments = @bug.comments.order('created_at DESC').limit(50).includes(:user)

    last = params[:last].present? ? @bug.comments.find_by_number(params[:last]) : nil
    @comments = @comments.where(infinite_scroll_clause('created_at', 'DESC', last, 'comments.number')) if last

    respond_with @project, @environment, @bug, (request.format == :json ? decorate(@comments) : @comments)
  end

  # Posts a Comment on a bug as the current user.
  #
  # Routes
  # ------
  #
  # * `POST /projects/:project_id/environments/:environment_id/bugs/:bug_id/comments.json`
  #
  # Body Parameters
  # ---------------
  #
  # Body parameters can be JSON- or form URL-encoded.
  #
  # |           |                                       |
  # |:----------|:--------------------------------------|
  # | `comment` | Parameterized hash of Comment fields. |

  def create
    @comment      = @bug.comments.build(comment_params)
    @comment.user = current_user
    @comment.save

    respond_with @project, @environment, @bug, @comment
  end

  # Edits a Comment.
  #
  # Routes
  # ------
  #
  # * `PATCH /projects/:project_id/environments/:environment_id/bugs/:bug_id/comments/:id.json`
  #
  # Path Parameters
  # ---------------
  #
  # |      |                              |
  # |:-----|:-----------------------------|
  # | `id` | The Comment number (not ID). |
  #
  # Body Parameters
  # ---------------
  #
  # Body parameters can be JSON- or form URL-encoded.
  #
  # |           |                                       |
  # |:----------|:--------------------------------------|
  # | `comment` | Parameterized hash of Comment fields. |

  def update
    @comment.update_attributes comment_params

    respond_with @project, @environment, @bug, @comment
  end

  # Deletes a Comment.
  #
  # Routes
  # ------
  #
  # * `DELETE /projects/:project_id/environments/:environment_id/bugs/:bug_id/comments/:id.json`
  #
  # Path Parameters
  # ---------------
  #
  # |      |                              |
  # |:-----|:-----------------------------|
  # | `id` | The Comment number (not ID). |

  def destroy
    @comment.destroy
    head :no_content
  end

  private

  def find_comment
    @comment = @bug.comments.find_by_number!(params[:id])
  end

  def must_be_creator_or_admin
    if [:creator, :owner, :admin].include? current_user.role(@comment) then
      return true
    else
      respond_to do |format|
        format.json { head :forbidden }
      end
      return false
    end
  end

  def decorate(comments)
    comments.map do |comment|
      comment.as_json.merge(
          user: comment.user.as_json,
          body_html: markdown.(comment.body),
          user_url: user_url(comment.user),
          url: project_environment_bug_comment_url(@project, @environment, @bug, comment, format: 'json')
      )
    end
  end

  def comment_params
    params.require(:comment).permit(:body)
  end
end

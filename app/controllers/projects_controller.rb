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

# Controller for working with {Project Projects}.

class ProjectsController < ApplicationController
  brushes             = YAML.load_file(Rails.root.join('data', 'brushes.yml'))

  # A map of file extensions to the SyntaxHighlighter brush to use.
  BRUSH_FOR_EXTENSION = brushes['by_extension']
  # A map of file names to the SyntaxHighlighter brush to use.
  BRUSH_FOR_FILENAME  = brushes['by_filename']
  # The SyntaxHighligher brush to use for unknown file types.
  DEFAULT_BRUSH       = brushes['default']

  before_filter :find_project, except: [:index, :create]
  before_filter :admin_login_required, only: [:update, :rekey]
  before_filter :owner_login_required, only: :destroy

  respond_to :html, :json

  # HTML
  # ====
  #
  # Displays a home page with summary information of {Bug Bugs} across the
  # current user's Projects, a filterable list of project Memberships, and
  # information about the current User.
  #
  # Routes
  # ------
  #
  # * `GET /`
  #
  # JSON
  # ====
  #
  # Searches for Projects with a given prefix.
  #
  # Routes
  # ------
  #
  # * `GET /projects.json`
  #
  # Query Parameters
  # ----------------
  #
  # |         |                                                                                 |
  # |:--------|:--------------------------------------------------------------------------------|
  # | `query` | Only includes those projects whose name begins with `query` (case-insensitive). |

  def index
    respond_to do |format|
      format.html # index.html.rb
      format.json do
        @projects = Project.includes(:owner).order('id DESC').limit(25)
        @projects = @projects.prefix(params[:query]) if params[:query].present?
        render json: decorate(@projects).to_json
      end
    end
  end

  # If the Project has a default {Environment}, and the `show_environments`
  # parameter is not set, redirects to the Bug list for that Environment.
  #
  # Otherwise, displays information about the Project and a list of
  # Environments.
  #
  # Routes
  # ------
  #
  # * `GET /projects/:id`
  #
  # Path Parameters
  # ---------------
  #
  # |      |                     |
  # |:-----|:--------------------|
  # | `id` | The Project's slug. |

  def show
    if @project.default_environment && params[:show_environments].blank?
      return redirect_to project_environment_bugs_url(@project, @project.default_environment)
    end

    respond_with @project
  end

  # Creates a new Project owned by the current User.
  #
  # Routes
  # ------
  #
  # * `POST /projects.json`
  #
  # Body Parameters
  # ---------------
  #
  # The body can be JSON- or form URL-encoded.
  #
  # |           |                                       |
  # |:----------|:--------------------------------------|
  # | `project` | Parameterized hash of Project fields. |

  def create
    project_attrs = project_params_for_creation.merge(validate_repo_connectivity: true)
    @project      = current_user.owned_projects.create(project_attrs)
    respond_with @project do |format|
      format.json do
        if @project.valid?
          render json: decorate(@project).to_json, status: :created
        else
          render json: {project: @project.errors.as_json}.to_json, status: :unprocessable_entity
        end
      end
    end
  end

  # Displays a page where the user can see information about how to install
  # Squash into his/her project, and how to configure his/her project for Squash
  # support.
  #
  # Routes
  # ------
  #
  # * `GET /projects/:id/edit`
  #
  # Path Parameters
  # ---------------
  #
  # |      |                     |
  # |:-----|:--------------------|
  # | `id` | The Project's slug. |

  def edit
    respond_with @project
  end

  # Edits a Project. Only the Project owner or an admin can modify a project.
  #
  # Routes
  # ------
  #
  # * `PATCH /projects/:id.json`
  #
  # Path Parameters
  # ---------------
  #
  # |      |                     |
  # |:-----|:--------------------|
  # | `id` | The Project's slug. |
  #
  # Body Parameters
  # ---------------
  #
  # The body can be JSON- or form URL-encoded.
  #
  # |           |                                       |
  # |:----------|:--------------------------------------|
  # | `project` | Parameterized hash of Project fields. |

  def update
    @project.assign_attributes project_params_for_update.merge(validate_repo_connectivity: true)
    @project.uses_releases_override = true if @project.uses_releases_changed?
    @project.save

    respond_with @project
  end

  # Generates a new API key for the Project.. Only the Project owner can do
  # this.
  #
  # Routes
  # ------
  #
  # * `PATCH /projects/:id/rekey`
  #
  # Path Parameters
  # ---------------
  #
  # |      |                     |
  # |:-----|:--------------------|
  # | `id` | The Project's slug. |

  def rekey
    @project.create_api_key
    @project.save!
    redirect_to edit_project_url(@project), flash: {success: t('controllers.projects.rekey.success', name: @project.name, api_key: @project.api_key)}
  end

  # Deletes a Project, and all associated Environments, Bugs, Occurrences, etc.
  # Probably want to confirm before allowing the user to do this.
  #
  # Routes
  # ------
  #
  # * `DELETE /projects/:id.json`
  #
  # Path Parameters
  # ---------------
  #
  # |      |                     |
  # |:-----|:--------------------|
  # | `id` | The Project's slug. |

  def destroy
    @project.destroy
    redirect_to root_url, flash: {success: t('controllers.projects.destroy.deleted', name: @project.name)}
  end

  # Responds with a context snippet given a revision, file, and line. The
  # response includes the context snippet and some metadata about it in JSON
  # format.
  #
  # Routes
  # ------
  #
  # * `GET /project/:id/context.json`
  #
  # Path Parameters
  # ---------------
  #
  # |      |                     |
  # |:-----|:--------------------|
  # | `id` | The Project's slug. |
  #
  # Query Parameters
  # ----------------
  #
  # |            |                                                                              |
  # |:-----------|:-----------------------------------------------------------------------------|
  # | `revision` | The commit ID of the source code revision to use (required).                 |
  # | `file`     | The path to the file, relative to the project root (required).               |
  # | `line`     | The line number within the file (required).                                  |
  # | `context`  | The number of lines of context to use before and after the line (default 3). |
  #
  # Responses
  # ---------
  #
  # ### Successful response: 200 OK
  #
  # The response body will be a JSON-encoded hash with the following keys:
  #
  # |              |                                                                        |
  # |:-------------|:-----------------------------------------------------------------------|
  # | `code`       | The code context snippet.                                              |
  # | `brush`      | The name of a SyntaxHighlighter brush to use when displaying the code. |
  # | `first_line` | The line number of the first line in the snippet.                      |
  #
  # ### Error responses
  #
  # All error response bodies will be a JSON-encoded hash with one key, `error`,
  # containing the localized error description. The following errors are
  # possible:
  #
  # * Required parameter missing: 400 Bad Request
  # * Repository couldn't be loaded: 422 Unprocessable Entity
  # * Commit not found: 422 Unprocessable Entity
  # * File not found in repo: 422 Unprocessable Entity
  # * Line number out of bounds: 422 Unprocessable Entity

  def context
    if @project.repo.nil?
      return respond_to do |format|
        format.json { render json: {error: t('controllers.projects.context.repo_nil')}, status: :unprocessable_entity }
      end
    end

    if params[:revision].blank? || params[:file].blank? || params[:line].blank?
      return respond_to do |format|
        format.json { render json: {error: t('controllers.projects.context.missing_param')}, status: :bad_request }
      end
    end

    blob = @project.repo.object(params[:revision] + '^{tree}:' + params[:file]) rescue nil
    if blob.nil?
      @project.repo(&:fetch)
      blob = @project.repo.object(params[:revision] + '^{tree}:' + params[:file]) rescue nil
      if blob.nil?
        return respond_to do |format|
          format.json { render json: {error: t('controllers.projects.context.commit_not_found')}, status: :unprocessable_entity }
        end
      end
    end

    context = (params[:context].presence || 3).to_i
    context = 3 if context < 0
    line = params[:line].to_i

    lines = blob.contents.split("\n")

    if line < 1 || line > lines.size
      return respond_to do |format|
        format.json { render json: {error: t('controllers.projects.context.line_out_of_bounds')}, status: :unprocessable_entity }
      end
    end

    top_line    = [line-context-1, 0].max
    bottom_line = [line+context-1, lines.size - 1].min

    snippet = lines[top_line, bottom_line-top_line+1]
    # remove blank lines from the top of the code snippet; otherwise
    # SyntaxHighlighter will remove them but fail to renumber the line numbers
    # correctly
    while snippet.first.empty?
      snippet.shift
      top_line += 1
    end

    brush = brush_from_filename(File.basename(params[:file]))

    respond_to do |format|
      format.json { render json: {code: snippet.join("\n"), brush: brush, first_line: top_line + 1} }
    end
  end

  private

  def find_project
    @project = Project.find_from_slug!(params[:id])
    class << @project
      include ProjectAdditions
    end
  end

  def brush_from_filename(name)
    ext_brush = BRUSH_FOR_EXTENSION[BRUSH_FOR_EXTENSION.keys.detect { |ext| name.end_with? ext }]
    BRUSH_FOR_FILENAME[name] || ext_brush || DEFAULT_BRUSH
  end

  def decorate(projects)
    decorate_block = ->(project) {
      project.as_json.merge(
          owner:    project.owner.as_json.merge(url: user_url(project.owner)),
          role:     current_user.role(project),
          url:      project_url(project),
          join_url: join_project_my_membership_url(project))
    }

    if projects.kind_of?(Enumerable)  || projects.kind_of?(ActiveRecord::Relation)
      projects.map &decorate_block
    else
      decorate_block.(projects)
    end
  end

  def admin_permitted_parameters
    [:name, :repository_url, :default_environment, :default_environment_id,
     :filter_paths, :filter_paths_string, :whitelist_paths,
     :whitelist_paths_string, :commit_url_format, :critical_mailing_list,
     :all_mailing_list, :critical_threshold, :sender, :locale,
     :sends_emails_outside_team, :trusted_email_domain, :pagerduty_enabled,
     :pagerduty_service_key, :always_notify_pagerduty, :uses_releases,
     :disable_message_filtering]
  end

  def project_params_for_creation
    params.require(:project).permit(*admin_permitted_parameters)
  end

  def project_params_for_update
    case current_user.role(@project)
      when :owner
        params.require(:project).permit(*(admin_permitted_parameters + [:owner_id]))
      when :admin
        project_params_for_creation
    end
  end

  module ProjectAdditions
    def filter_paths_string() filter_paths.join("\n") end
    def whitelist_paths_string() whitelist_paths.join("\n") end

    def filter_paths_string=(str) self.filter_paths = (str || '').split("\n") end
    def whitelist_paths_string=(str) self.whitelist_paths = (str || '').split("\n") end

    def owner_username() owner.username end
    def owner_username=(name) self.owner = User.find_by_username(name) end
  end
end

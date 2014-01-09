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

# Controller for working with objects that are accessed from a {Project}'s
# repository (mainly commits). This controller is capable of managing the
# situation where the repository is very slow or inaccessible.

class CommitsController < ApplicationController
  brushes = YAML.load_file(Rails.root.join('data', 'brushes.yml'))

  # A map of file extensions to the SyntaxHighlighter brush to use.
  BRUSH_FOR_EXTENSION = brushes['by_extension']
  # A map of file names to the SyntaxHighlighter brush to use.
  BRUSH_FOR_FILENAME  = brushes['by_filename']
  # The SyntaxHighligher brush to use for unknown file types.
  DEFAULT_BRUSH       = brushes['default']

  before_filter :find_project
  respond_to :json

  # Responds with the 10 most recent commits.
  #
  # Routes
  # ------
  #
  # * `GET /projects/:project_id/commits`
  #
  # Path Parameters
  # ---------------
  #
  # |              |                     |
  # |:-------------|:--------------------|
  # | `project_id` | The Project's slug. |

  def index
    @commits = @project.repo.log(10)
    respond_with @commits
  end

  # Responds with a context snippet given a revision, file, and line. The
  # response includes the context snippet and some metadata about it in JSON
  # format.
  #
  # Routes
  # ------
  #
  # * `GET /projects/:project_id/commits/:id/context.json`
  #
  # Path Parameters
  # ---------------
  #
  # |              |                                                               |
  # |:-------------|:--------------------------------------------------------------|
  # | `project_id` | The Project's slug.                                           |
  # | `id`         | The identifier of the source code revision to use (required). |
  #
  # Query Parameters
  # ----------------
  #
  # |           |                                                                              |
  # |:----------|:-----------------------------------------------------------------------------|
  # | `file`    | The path to the file, relative to the project root (required).               |
  # | `line`    | The line number within the file (required).                                  |
  # | `context` | The number of lines of context to use before and after the line (default 3). |
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
        format.json { render json: {error: t('controllers.commits.context.repo_nil')}, status: :unprocessable_entity }
      end
    end

    if params[:file].blank? || params[:line].blank?
      return respond_to do |format|
        format.json { render json: {error: t('controllers.commits.context.missing_param')}, status: :bad_request }
      end
    end

    blob = @project.repo.object(params[:id] + '^{tree}:' + params[:file]) rescue nil
    if blob.nil?
      @project.repo(&:fetch)
      blob = @project.repo.object(params[:id] + '^{tree}:' + params[:file]) rescue nil
      if blob.nil?
        return respond_to do |format|
          format.json { render json: {error: t('controllers.commits.context.commit_not_found')}, status: :unprocessable_entity }
        end
      end
    end

    context = (params[:context].presence || 3).to_i
    context = 3 if context < 0
    line = params[:line].to_i

    lines = blob.contents.split("\n")

    if line < 1 || line > lines.size
      return respond_to do |format|
        format.json { render json: {error: t('controllers.commits.context.line_out_of_bounds')}, status: :unprocessable_entity }
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

  def brush_from_filename(name)
    ext_brush = BRUSH_FOR_EXTENSION[BRUSH_FOR_EXTENSION.keys.detect { |ext| name.end_with? ext }]
    BRUSH_FOR_FILENAME[name] || ext_brush || DEFAULT_BRUSH
  end
end

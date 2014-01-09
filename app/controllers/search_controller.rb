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

# Returns search suggestions and search results for the search field in the
# navigation bar. The following query syntaxes are allowed:
#
# * `@username`
# * `project`
# * `project environment`
# * `project environment bug#`
# * `project environment bug# occurrence#`
#
# Usernames, Project names, and Environment names can be unique prefixes and are
# case-insensitive.

class SearchController < ApplicationController

  # Maximum number of suggestions to return.
  MAX_SUGGESTIONS = 10

  skip_before_filter :login_required
  before_filter :require_query

  # Returns a search result for a query in the search field. If the query
  # consists of recognized names or prefixes, and resolves to a single page, the
  # response will be 200 OK, and the body will be the URL. Otherwise, the
  # response will be 200 OK with an empty body.
  #
  # Routes
  # ------
  #
  # * `GET /search`
  #
  # Query Parameters
  # ----------------
  #
  # |         |                   |
  # |:--------|:------------------|
  # | `query` | The search query. |

  def search
    words = params[:query].split(/\s+/).reject(&:blank?)
    url   = nil

    case words.size
      when 1
        if words.first.starts_with?('@')
          user = find_users(words.first[1..-1]).only
          url = user_url(user) if user
        else
          project = find_projects(words[0]).only.try!(:sluggable)
          url = project_url(project) if project
        end
      when 2
        project = find_projects(words[0]).only.try!(:sluggable)
        env = find_environments(project, words[1]).only if project
        url = project_environment_bugs_url(project, env) if env
      when 3
        project = find_projects(words[0]).only.try!(:sluggable)
        env = find_environments(project, words[1]).only if project
        bug = env.bugs.find_by_number(words[2].to_i) if env
        url = project_environment_bug_url(project, env, bug) if bug
      when 4
        project = find_projects(words[0]).only.try!(:sluggable)
        env = find_environments(project, words[1]).only if project
        bug = env.bugs.find_by_number(words[2].to_i) if env
        occurrence = bug.occurrences.find_by_number(words[3].to_i) if bug
        url = project_environment_bug_occurrence_url(project, env, bug, occurrence) if occurrence
    end

    url ? render(text: url) : head(:ok)
  end

  # Returns a JSON-formatted array of possible completions given a search query.
  # Completion is supported for usernames, Project names, and Environment names
  # only. If the query refers to a Bug or Occurrence, a single-element array is
  # returned with information on that object.
  #
  # Routes
  # ------
  #
  # * `GET /search/suggestions`
  #
  # Query Parameters
  # ----------------
  #
  # |         |                   |
  # |:--------|:------------------|
  # | `query` | The search query. |
  #
  # Response JSON
  # -------------
  #
  # The response JSON will be an array of hashes, each with the following keys:
  #
  # | Field name    | When included                            | Description                                               |
  # |:--------------|:-----------------------------------------|:----------------------------------------------------------|
  # | `type`        | always                                   | "user", "project", "environment", "bug", or "occurrence". |
  # | `url`         | always                                   | The URL to the suggestion object.                         |
  # | `user`        | User results only                        | Hash of information about the User.                       |
  # | `project`     | all except User results                  | Hash of information about the Project.                    |
  # | `environment` | Environment, Bug, and Occurrence results | Hash of information about the Environment.                |
  # | `bug`         | Bug and Occurrence results               | Hash of information about the Bug.                        |
  # | `occurrence`  | Occurrence results only                  | Hash of information about the Occurrence.                 |

  def suggestions
    words = params[:query].split(/\s+/).reject(&:blank?)

    suggestions = case words.size
                    when 1
                      if words.first.starts_with?('@')
                        users = find_users(words.first[1..-1]).limit(MAX_SUGGESTIONS)
                        users.map do |user|
                          {
                              user: user.as_json,
                              url:  user_url(user),
                              type: 'user'
                          }
                        end
                      else
                        projects = find_projects(words[0]).limit(MAX_SUGGESTIONS).map(&:sluggable).compact
                        projects.map do |project|
                          {
                              project: project.as_json,
                              url:     project_url(project),
                              type:    'project',
                          }
                        end
                      end
                    when 2
                      project = find_projects(words[0]).only.try!(:sluggable)
                      envs = find_environments(project, words[1]).limit(10) if project
                      envs.map do |env|
                        {
                            project:     project.as_json,
                            environment: env.as_json,
                            type:        'environment',
                            url:         project_environment_bugs_url(project, env)


                        }
                      end if project
                    when 3
                      project = find_projects(words[0]).only.try!(:sluggable)
                      env = find_environments(project, words[1]).only if project
                      bug = env.bugs.find_by_number(words[2].to_i) if env
                      [{
                           type:        'bug',
                           url:         project_environment_bug_url(project, env, bug),
                           project:     project.as_json,
                           environment: env.as_json,
                           bug:         bug.as_json
                       }] if bug
                    when 4
                      project = find_projects(words[0]).only.try!(:sluggable)
                      env = find_environments(project, words[1]).only if project
                      bug = env.bugs.find_by_number(words[2].to_i) if env
                      occurrence = bug.occurrences.find_by_number(words[3].to_i) if bug
                      [{
                           type:        'occurrence',
                           url:         project_environment_bug_occurrence_url(project, env, bug, occurrence),
                           project:     project.as_json,
                           environment: env.as_json,
                           bug:         bug.as_json,
                           occurrence:  occurrence.as_json
                       }] if occurrence
                  end

    respond_to do |format|
      format.json { render json: (suggestions || []).to_json }
    end
  end

  private

  def require_query
    if params[:query].present?
      return true
    else
      head :unprocessable_entity
      return false
    end
  end

  def find_projects(substring)
    Slug.active.for_class('Project').where('slug ILIKE ?', "#{substring}%").order('slug ASC').includes(:sluggable)
  end

  def find_environments(project, substring)
    project.environments.where('name ILIKE ?', "#{substring}%").order('name ASC')
  end

  def find_users(substring)
    User.where('username ILIKE ?', "#{substring}%").order('username ASC')
  end
end

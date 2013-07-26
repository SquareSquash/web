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

# A simple proxy class that wraps a {Project}'s Git::Repository and ensures
# calls to `#fetch` are done synchronously using {Project#repo}. In particular:
#
# * If a method _other_ than {#fetch} is called on this object, it is passed on
#   to the Project's repository object.
# * If {#fetch} is called, it is delegated to `Project#repo(&:fetch)`.

class RepoProxy
  # @return [Project] The associated project.
  attr_reader :project

  # @overload initialize(object, method, ...)
  #   Creates a new repository proxy.
  #   @param object An object associated in some way with a {Project}.
  #   @param [Symbol] method The method to call that will return the Project.
  #     Multiple method names can be passed to make a call chain.

  def initialize(object, *method_path)
    @method_path = method_path
    @project     = object
    method_path.each { |m| @project = @project.send(m) }
  end

  # Calls `repo(&:fetch)` on the associated Project.

  def fetch
    project.repo(&:fetch)
  end

  # Delegates all other methods to {#project}.

  def method_missing(meth, *args, &block)
    project.repo.send meth, *args, &block
  end

  # @private
  def respond_to?(method)
    project.repo.respond_to?(method) || super
  end

  # @private
  def class() project.repo.class end
end

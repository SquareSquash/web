class BeetilIncidentsController < ApplicationController
  before_filter :find_project
  before_filter :find_environment
  before_filter :find_bug
  before_filter :membership_required

  def create
    #TODO this does not work. getting a E09 "Invalid attributes passed to attributes setter"
    #incident = Service::Beetil.create_incident(@project.service_key, title, symptom)
    #@bug.update_attributes!(beetil_number: incident.reference_number)

    respond_to do |format|
      format.json { head :created }
      format.html { redirect_to project_environment_bug_url(@project, @environment, @bug, anchor: 'management') }
    end
  end
end

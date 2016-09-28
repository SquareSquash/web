class BeetilIncidentsController < ApplicationController
  before_filter :find_project
  before_filter :find_environment
  before_filter :find_bug
  before_filter :membership_required

  def create
    #TODO this does not work for V2. getting a E09 "Invalid attributes passed to attributes setter"
    #incident = Service::Beetil.create_incident(@project.beetil_service_key, title, symptom)
    #@bug.update_attributes!(beetil_number: incident.reference_number)

    incident = Service::Beetil.create_incident(@project.beetil_service_key, beetil_title, beetil_symptom)
    @bug.update_attributes!(beetil_number: incident.number)

    respond_to do |format|
      format.json { head :created }
      format.html { redirect_to project_environment_bug_url(@project, @environment, @bug, anchor: 'management') }
    end
  end

  protected
  def beetil_title
    t('models.bug.beetil_data.summary',
      class_name: @bug.class_name,
      file_name:  File.basename(@bug.file),
      line:       @bug.special_file? ? t('models.bug.beetil_data.not_applicable') : @bug.line,
      locale:     @bug.environment.project.locale)
  end

  def beetil_symptom
    occurrence = @bug.occurrences.last

    t('models.bug.beetil_data.description',
      class_name: @bug.class_name,
      file:       File.basename(@bug.file),
      line:       @bug.special_file? ? t('models.bug.beetil_data.not_applicable') : @bug.line,
      last_occurrence_message:    occurrence.message,
      revision:   @bug.revision,
      url:        project_environment_bug_url(@project, @environment, @bug),
      last_occurrence_url: project_environment_bug_occurrence_url(@project, @environment, @bug, occurrence),
      locale:     @bug.environment.project.locale)
  end
end

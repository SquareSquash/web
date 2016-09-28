class BeetilStatusWorker
  include BackgroundRunner::Job

  def self.perform
    new.perform
  end

  def perform
    Bug.where(fixed: false).cursor.each do |bug|
      next unless bug.beetil_number

      issue = Service::Beetil.find_incident(bug.beetil_number)
      next unless issue
      next unless issue.closed_at

      #TODO set and process Bug#modifier
      bug.update_attribute :fixed, true
    end
  end

end

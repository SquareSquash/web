module BackgroundRunner
  module Resque
    @@queue = :squash

    def self.run(job_name, *arguments)
      job_name = job_name.constantize unless job_name.kind_of?(Class)
      ::Resque.enqueue_to(@@queue, job_name, *arguments)
    end
  end
end

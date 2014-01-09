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

module BackgroundRunner

  # BackgroundRunner adapter for {::Multithread}. This module generates
  # Multithread jobs and assigns them priorities as specified in the
  # `concurrency.yml` Configoro file.

  module Multithread

    # Sends a job to {::Multithread.spinoff}. The job's name and priority are
    # calculated automatically.
    #
    # @param [String, Class] job_name The name of the class under `lib/workers`
    #   to run.

    def self.run(job_name, *arguments)
      job_name = job_name.constantize unless job_name.kind_of?(Class)
      ::Multithread.spinoff(queue_item_name(job_name, arguments), priority(job_name)) { job_name.perform *arguments }
    end

    private

    def self.queue_item_name(job_name, arguments)
      return nil if job_name.to_s == 'OccurrencesWorker'
      [job_name, arguments.map(&:inspect)].join(':')
    end

    def self.priority(job_name)
      Squash::Configuration.concurrency.multithread.priority[job_name.to_s]
    end
  end
end

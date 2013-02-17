# Spawn and stop the thread pool

if defined?(PhusionPassenger)
  PhusionPassenger.on_event(:starting_worker_process) do |forked|
    Multithread.start
  end

  PhusionPassenger.on_event(:stopping_worker_process) do
    Multithread.stop
  end
elsif defined?(Unicorn)
  Unicorn::HttpServer.class_eval do
    old = instance_method(:worker_loop)
    define_method(:worker_loop) do |worker|
      Multithread.start
      old.bind(self).call(worker)
    end
  end
else
  # Not in Passenger at all
  Multithread.start
  at_exit { Multithread.stop }
end

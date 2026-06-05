# frozen_string_literal: true

# A pool of Ractors for CPU-bound work (true parallelism, no GVL contention).
#
# Unlike ThreadPool, workers cannot *pull* from a shared queue: since Ruby 4.0
# a Ractor::Port can only be received from by the Ractor that created it. So the
# pool *pushes* jobs to workers round-robin (each Ractor has its own inbox via
# Ractor#send) and workers push their outcome back through a single output port
# owned by the main Ractor.
module Pools
  class RactorPool
    SENTINEL = :__ractor_pool_stop__

    attr_reader :size

    def initialize(size: 1, verbose: false)
      @size       = size
      @verbose    = verbose
      @out_port   = Ractor::Port.new
      @scheduled  = []
      @dispatched = 0
    end

    # Spawn the workers and make them wait for jobs. Any job scheduled before
    # #start was called is dispatched now.
    def start
      return self if @pool

      out_port = @out_port

      @pool = Array.new(@size) do |id|
        Ractor.new(out_port, id, name: "ractor ##{id}") do |port, worker_id|
          loop do
            job = Ractor.receive
            break if job == SENTINEL

            module_name, args = job

            begin
              result = Object.const_get(module_name).perform(*args)
              port.send({ ractor: worker_id, task: job, result: result })
            rescue => e # rubocop:disable Style/RescueStandardError
              port.send({ ractor: worker_id, task: job, error: "#{e.class}: #{e.message}" })
            end
          end
        end
      end

      puts "--- Ractor Pool started (#{@size} ractor#{"s" unless @size == 1}) ---" if @verbose

      flush_scheduled

      self
    end

    # `module_name` must name a constant that responds to `.perform(*args)`.
    # Constants are shared across Ractors, so the worker resolves it on its side.
    def schedule(module_name, *args)
      job = [module_name.to_s, args]

      if @pool
        dispatch(job)
      else
        @scheduled << job
      end

      self
    end

    # Close the pool and block until every dispatched job has reported back.
    def wait
      results
      self
    end

    # All outcomes, each a Hash with :ractor, :task and either :result or :error.
    # Idempotent: the pool is drained and closed on the first call.
    def results
      @results ||=
        begin
          start unless @pool

          @pool.each { |worker| worker.send(SENTINEL) }
          collected = Array.new(@dispatched) { @out_port.receive }
          @pool.each(&:value)
          @out_port.close

          puts "--- Ractor Pool stopped ---" if @verbose

          collected
        end
    end

    private

    def flush_scheduled
      pending = @scheduled
      @scheduled = []
      pending.each { |job| dispatch(job) }
    end

    def dispatch(job)
      @pool[@dispatched % @size].send(job)
      @dispatched += 1
    end
  end
end

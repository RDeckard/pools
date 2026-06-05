# frozen_string_literal: true

require_relative "ractor_pool"

# Build a module that, once included in a worker class, turns it into a Ractor
# job producer:
#
#   RWorker = Pools::RactorWorker.new(size: 4, verbose: true)
#
#   class AWorker
#     include RWorker
#
#     def initialize(number) = @number = number
#     def call               = (0..@number).sum
#   end
#
#   RWorker.start
#   8.times { AWorker.perform_async(10_000_000) }
#   RWorker.wait            # blocks until done
#   RWorker.results         # => collected outcomes
#
# - `.perform(*args)`       runs synchronously in the current Ractor.
# - `.perform_async(*args)` enqueues the work on the shared RactorPool.
module Pools
  class RactorWorker < Module
    attr_reader :pool

    def initialize(size:, verbose: false)
      @pool = RactorPool.new(size:, verbose:)

      super()
    end

    def start
      @pool.start

      self
    end

    def wait
      @pool.wait

      self
    end

    def results
      @pool.results
    end

    def included(base)
      pool = @pool

      # `perform` runs inside a worker Ractor, so it must be a real (shareable)
      # method, not a closure built from an un-shareable Proc.
      def base.perform(...)
        new(...).call
      end

      # `perform_async` only ever runs in the main Ractor (the producer side),
      # so it can safely close over the pool.
      base.define_singleton_method(:perform_async) do |*args|
        pool.schedule(name, *args)
      end
    end
  end
end

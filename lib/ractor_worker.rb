# frozen_string_literal: true

require_relative "ractor_pool"

class RactorWorker < Module
  def initialize(size:, verbose:)
    @size    = size
    @verbose = verbose

    @@__ractor_pool__ = RactorPool.new(size:, verbose:) # rubocop:disable Style/ClassVars

    @logger = Ractor.new { loop { puts Ractor.receive } }

    super()
  end

  def puts(msg)
    @logger << msg
  end

  def start
    @@__ractor_pool__.start

    self
  end

  def wait
    @@__ractor_pool__.wait

    @logger.close_incoming
  end

  def included(base)
    def base.perform(...)
      new(...).call
    end

    def base.perform_async(*args)
      @@__ractor_pool__.schedule(name, *args)
    end
  end
end

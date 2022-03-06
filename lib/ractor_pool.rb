# frozen_string_literal: true

class RactorPool
  attr_reader :size, :queue

  def initialize(size: 1, verbose: false)
    @size = size

    # Threadsafe queue
    @queue =
      Ractor.new do
        loop do
          Ractor.yield(Ractor.receive, move: true)
        end
      end.freeze
    Ractor.make_shareable(@queue)

    # Threadsafe output
    @output =
      Ractor.new(verbose) do |verbose|
        results = []

        loop do
          result = Ractor.receive

          puts result if verbose

          results << result
        end

        results
      end
    Ractor.make_shareable(@output)
  end

  def start
    @pool = Array.new(@size) do |ractor_id|
      Ractor.new(@queue, @output, name: "ractor ##{ractor_id}") do |queue, output|
        loop do
          module_name, args = queue.take

          break if module_name.nil?

          result = Object.const_get(module_name).perform(*args)

          output << {
                      ractor_name: Ractor.current.name,
                      task:        [module_name, args],
                      result:
                    }
        end
      end
    end

    self
  end

  def schedule(module_name, *args)
    @queue << [module_name, *args]
  end

  def wait
    start if @pool.nil?

    @queue.close_incoming
    @pool.each(&:take)

    self
  end

  def all_results
    @all_results ||=
      begin
        wait if @pool.nil?

        @output.close_incoming
        @output.take
      end
  end
end
